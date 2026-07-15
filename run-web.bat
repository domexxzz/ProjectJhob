@echo off
title App (Web) - AI Finance Coach

echo Cleaning up port 5000 if in use...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :5000 ^| findstr LISTENING') do (
    echo Killing process with PID %%a occupying port 5000...
    taskkill /f /pid %%a
)

cd /d "%~dp0mobile"

set "FLUTTER=C:\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=flutter"

echo === Getting Flutter packages ===
call "%FLUTTER%" pub get

echo === Launching app in Chrome (web) on http://localhost:5000 - API http://localhost:4000 ===
echo     First build takes ~40s; Chrome opens by itself. Please wait.
REM --web-port/--web-hostname must be fixed to localhost:5000 so the origin
REM matches the "Authorized JavaScript origins" in Google Cloud (Google Sign-In).
call "%FLUTTER%" run -d chrome --web-hostname=localhost --web-port=5000 --dart-define=API_BASE_URL=http://localhost:4000
