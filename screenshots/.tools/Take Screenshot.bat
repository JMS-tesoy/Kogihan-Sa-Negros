@echo off
cd /d "%~dp0..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "screenshots\.tools\flutter_screenshot.ps1"
echo.
pause
