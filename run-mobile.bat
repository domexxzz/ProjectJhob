@echo off
title App (Android Emulator) - AI Finance Coach
cd /d "%~dp0mobile"

set "FLUTTER=C:\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" set "FLUTTER=flutter"

echo === Getting Flutter packages ===
call "%FLUTTER%" pub get

echo === Launching on Android emulator - API http://10.0.2.2:4000 ===
echo     (10.0.2.2 = how an Android emulator reaches this PC localhost)
echo     For a REAL phone on the same Wi-Fi, use run-phone.bat instead.
call "%FLUTTER%" run --dart-define=API_BASE_URL=http://10.0.2.2:4000
