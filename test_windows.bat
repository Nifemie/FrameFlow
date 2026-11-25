@echo off
setlocal EnableDelayedExpansion
title FrameFlow Studio - Windows Diagnostics ^& Test Runner

:: Ensure script is running inside FrameFlow directory
cd /d "%~dp0"
if not exist "pubspec.yaml" (
    if exist "FrameFlow\pubspec.yaml" (
        cd /d "%~dp0FrameFlow"
    ) else (
        echo [ERROR] pubspec.yaml not found. Please run this batch script from the FrameFlow directory.
        pause
        exit /b 1
    )
)

cls
echo ===============================================================================
echo                 FrameFlow Studio - Windows Test ^& Launch Tool
echo ===============================================================================
echo.

:: 1. Check Flutter SDK
echo [1/4] Checking Flutter SDK...
where flutter.bat >nul 2>nul
if %ERRORLEVEL% neq 0 (
    where flutter >nul 2>nul
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Flutter is not found in your system PATH!
        echo Please install Flutter or add its bin directory to PATH.
        echo https://docs.flutter.dev/get-started/install/windows
        echo.
        pause
        exit /b 1
    )
)
for /f "tokens=*" %%v in ('flutter --version 2^>nul') do (
    echo     %%v
    goto :flutter_found
)
:flutter_found
echo     [OK] Flutter SDK is available.
echo.

:: 2. Check FFmpeg and FFprobe
echo [2/4] Checking FFmpeg and FFprobe binaries...
set FFMPEG_FOUND=0
set FFPROBE_FOUND=0

where ffmpeg >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo     [OK] FFmpeg found in system PATH.
    set FFMPEG_FOUND=1
) else if exist "assets\bin\ffmpeg.exe" (
    echo     [OK] FFmpeg found in assets\bin\ffmpeg.exe.
    set FFMPEG_FOUND=1
) else if exist "C:\Program Files (x86)\FrameFlow Studio\ffmpeg.exe" (
    echo     [OK] FFmpeg found in FrameFlow Studio installation.
    set FFMPEG_FOUND=1
)

where ffprobe >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo     [OK] FFprobe found in system PATH.
    set FFPROBE_FOUND=1
) else if exist "assets\bin\ffprobe.exe" (
    echo     [OK] FFprobe found in assets\bin\ffprobe.exe.
    set FFPROBE_FOUND=1
) else if exist "C:\Program Files (x86)\FrameFlow Studio\ffprobe.exe" (
    echo     [OK] FFprobe found in FrameFlow Studio installation.
    set FFPROBE_FOUND=1
)

if %FFMPEG_FOUND% equ 0 (
    echo     [WARN] ffmpeg.exe was not detected in assets\bin or PATH.
    echo     Video export will require ffmpeg.exe in assets\bin or system PATH.
)
if %FFPROBE_FOUND% equ 0 (
    echo     [WARN] ffprobe.exe was not detected in assets\bin or PATH.
    echo     Audio probe will use just_audio fallback.
)
echo.

:: 3. Run Automated Unit Tests
echo [3/4] Running All Automated Unit ^& E2E Tests...
echo -------------------------------------------------------------------------------
call flutter test
if %ERRORLEVEL% neq 0 (
    echo.
    echo [FAIL] One or more unit tests failed!
    echo -------------------------------------------------------------------------------
    pause
    goto :menu
)
echo -------------------------------------------------------------------------------
echo     [OK] All unit tests passed successfully!
echo.

:: 4. Run Flutter Analyzer
echo [4/4] Running Flutter Code Analysis...
echo -------------------------------------------------------------------------------
call flutter analyze
if %ERRORLEVEL% neq 0 (
    echo.
    echo [WARN] Flutter analyze reported some issues.
) else (
    echo     [OK] Code analysis clean. No errors found!
)
echo -------------------------------------------------------------------------------
echo.

:menu
echo ===============================================================================
echo                                 Action Menu
echo ===============================================================================
echo  [1] Re-run Unit Tests ^& Code Analysis
echo  [2] Launch FrameFlow App in Windows Desktop Mode (flutter run -d windows)
echo  [3] Build Release Windows Executable (flutter build windows --release)
echo  [4] Clean ^& Refresh Dependencies (flutter clean ^&^& flutter pub get)
echo  [5] Exit
echo ===============================================================================
set /p USER_CHOICE="Select an option (1-5): "

if "%USER_CHOICE%"=="1" (
    cls
    goto :flutter_found
)
if "%USER_CHOICE%"=="2" (
    echo.
    echo [*] Starting FrameFlow Studio on Windows Desktop...
    call flutter run -d windows
    pause
    goto :menu
)
if "%USER_CHOICE%"=="3" (
    echo.
    echo [*] Building Release Binary for Windows...
    call flutter build windows --release
    if %ERRORLEVEL% equ 0 (
        echo.
        echo [OK] Release build complete! Executable is at:
        echo      build\windows\x64\runner\Release\frameflow.exe
    ) else (
        echo.
        echo [ERROR] Build failed. Check compiler output above.
    )
    pause
    goto :menu
)
if "%USER_CHOICE%"=="4" (
    echo.
    echo [*] Cleaning and fetching packages...
    call flutter clean
    call flutter pub get
    pause
    goto :menu
)
if "%USER_CHOICE%"=="5" (
    exit /b 0
)

echo [!] Invalid selection. Please enter 1, 2, 3, 4, or 5.
pause
cls
goto :menu
