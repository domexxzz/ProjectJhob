@echo off
REM One-click: start the backend and the web app in separate windows.
echo Launching Backend + Web app...
start "Backend - AI Finance Coach" cmd /k "%~dp0start-backend.bat"
echo Waiting for backend to boot...
timeout /t 5 >nul
start "App (Web) - AI Finance Coach" cmd /k "%~dp0run-web.bat"
echo.
echo Two windows opened:
echo   1) Backend  -> http://localhost:4000
echo   2) Web app  -> Chrome will open automatically
