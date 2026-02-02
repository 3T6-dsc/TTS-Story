@echo off
setlocal EnableExtensions EnableDelayedExpansion
echo ========================================
echo Starting TTS-Story
echo ========================================
echo.

REM Check if venv exists
if not exist "venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found
    echo Please run setup.bat first
    pause
    exit /b 1
)

REM Ensure FFmpeg is on PATH if bundled
set "FFMPEG_EXE=%~dp0tools\ffmpeg\ffmpeg.exe"
if exist "%FFMPEG_EXE%" (
    set "PATH=%~dp0tools\ffmpeg;%PATH%"
    echo FFmpeg ready: %FFMPEG_EXE%
) else (
    echo WARNING: FFmpeg not found (expected %FFMPEG_EXE%)
    echo          Audio merging may fail without FFmpeg.
)

REM Detect NVIDIA GPU (for CPU-only torch fallback)
set "HAS_NVIDIA=0"
set "GPU_NAME="
for /f "delims=" %%G in ('powershell -NoLogo -NoProfile -Command "$g=(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1).Name; if ($g) { $g }"') do set "GPU_NAME=%%G"
if defined GPU_NAME (
    set "HAS_NVIDIA=1"
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Ensure CPU-only torch on systems without NVIDIA GPUs
if "%HAS_NVIDIA%"=="0" (
    set "TORCH_VERSION="
    for /f "delims=" %%V in ('python -c "import torch, sys; sys.stdout.write(torch.__version__)" 2^>nul') do set "TORCH_VERSION=%%V"
    if not defined TORCH_VERSION (
        echo WARNING: PyTorch failed to import. Reinstalling CPU-only torch...
        pip uninstall -y torch torchvision torchaudio >nul 2>&1
        pip install --upgrade --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    ) else (
        echo Detected PyTorch: !TORCH_VERSION!
        echo !TORCH_VERSION! | findstr /i "+cu" >nul 2>&1
        if not errorlevel 1 (
            echo CUDA build detected on CPU-only system. Reinstalling CPU-only torch...
            pip uninstall -y torch torchvision torchaudio >nul 2>&1
            pip install --upgrade --force-reinstall torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        )
    )
)

REM Ensure Rubber Band CLI is on PATH if bundled
set "RB_EXE=%~dp0tools\rubberband\rubberband.exe"
if exist "%RB_EXE%" (
    set "PATH=%~dp0tools\rubberband;%PATH%"
    echo Rubber Band CLI ready: %RB_EXE%
) else (
    echo WARNING: Rubber Band CLI not found (expected %RB_EXE%)
    echo          Pitch/tempo FX will fall back to lower-quality processing.
)

REM Ensure SoX is on PATH if bundled
set "SOX_EXE=%~dp0tools\sox\sox.exe"
if exist "%SOX_EXE%" (
    set "PATH=%~dp0tools\sox;%PATH%"
    echo SoX ready: %SOX_EXE%
) else (
    echo WARNING: SoX not found (expected %SOX_EXE%)
    echo          Audio cleanup may be lower quality and clicks may occur.
)

REM Skip CUDA check at startup (can hang on some systems)
REM CUDA availability will be detected when the app starts

echo.
echo Starting Flask server...
echo Open your browser to: http://localhost:5000
echo Press Ctrl+C to stop the server
echo.

REM Start the application
python app.py

pause
