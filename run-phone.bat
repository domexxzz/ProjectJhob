@echo off
title App (Real Phone) - AI Finance Coach
cd /d "%~dp0mobile"

set "FLUTTER="
for /f "delims=" %%i in ('where flutter 2^>nul') do set "FLUTTER=%%i"
if "%FLUTTER%"=="" if exist "C:\Users\ta100\Downloads\flutter\bin\flutter.bat" set "FLUTTER=C:\Users\ta100\Downloads\flutter\bin\flutter.bat"
if "%FLUTTER%"=="" if exist "C:\flutter\bin\flutter.bat" set "FLUTTER=C:\flutter\bin\flutter.bat"
if "%FLUTTER%"=="" if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if "%FLUTTER%"=="" set "FLUTTER=flutter"

REM Verify Flutter is available
call "%FLUTTER%" --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter command was not found. 
    echo Please make sure Flutter is installed and added to PATH, or placed at C:\flutter
    pause
    exit /b 1
)

set "LANIP="
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } | Sort-Object InterfaceMetric | Select-Object -First 1).IPAddress"') do set "LANIP=%%i"

if "%LANIP%"=="" (
  echo [!] Could not auto-detect a LAN IP. Run ipconfig and set it manually.
  pause
  exit /b 1
)

echo === Getting Flutter packages ===
call "%FLUTTER%" pub get

echo === Launching on connected phone - API http://%LANIP%:4000 ===
echo     Phone must be on the SAME Wi-Fi and Windows Firewall must allow port 4000.
call "%FLUTTER%" run --dart-define=API_BASE_URL=http://%LANIP%:4000
