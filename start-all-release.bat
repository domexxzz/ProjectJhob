@echo off
REM One-click: start the backend and the web app (release mode) in separate windows.
echo Launching Backend + Web app (Release Mode)...
cd /d "%~dp0."
start "Backend - AI Finance Coach" cmd /k "start-backend.bat"
echo Waiting for backend to boot...
ping 127.0.0.1 -n 6 >nul
start "App (Web Release) - AI Finance Coach" cmd /k "run-web-release.bat"
echo.
echo Two windows opened:
echo   1) Backend  : http://localhost:4000
echo   2) Web app  : Chrome will open automatically (Release Mode)
