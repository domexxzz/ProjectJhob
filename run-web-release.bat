@echo off
title App (Web Release) - AI Finance Coach

echo Cleaning up port 5000 if in use...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :5000 ^| findstr LISTENING') do (
    echo Killing process with PID %%a occupying port 5000...
    taskkill /f /pid %%a
)

cd /d "%~dp0mobile"

set "FLUTTER="
for /f "delims=" %%i in ('where flutter 2^>nul') do set "FLUTTER=%%i"
if not exist "%FLUTTER%" if exist "C:\Users\ta100\Downloads\flutter\bin\flutter.bat" set "FLUTTER=C:\Users\ta100\Downloads\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" if exist "C:\flutter\bin\flutter.bat" set "FLUTTER=C:\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=flutter"

REM Verify Flutter is available
call "%FLUTTER%" --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter command was not found. 
    echo Please make sure Flutter is installed and added to PATH, or placed at C:\flutter
    pause
    exit /b 1
)

echo === Getting Flutter packages ===
call "%FLUTTER%" pub get

echo === Launching app in Chrome (web release) on http://localhost:5000 - API http://localhost:4000 ===
echo     First build takes ~40s; Chrome opens by itself. Please wait.
call "%FLUTTER%" run -d chrome --release --web-hostname=localhost --web-port=5000 --dart-define=API_BASE_URL=http://localhost:4000
