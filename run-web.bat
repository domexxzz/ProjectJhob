@echo off
title App (Web) - AI Finance Coach
cd /d "%~dp0mobile"

set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=flutter"

echo === Getting Flutter packages ===
call "%FLUTTER%" pub get

echo === Launching app in Chrome (web) - API http://localhost:4000 ===
echo     First build takes ~40s; Chrome opens by itself. Please wait.
call "%FLUTTER%" run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
