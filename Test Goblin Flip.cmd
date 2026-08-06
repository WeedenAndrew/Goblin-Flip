@echo off
title Test Goblin Flip
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 goto missing_flutter

call flutter test
set "TEST_EXIT=%errorlevel%"
echo.
pause
exit /b %TEST_EXIT%

:missing_flutter
echo.
echo Flutter was not found on PATH.
echo Add the Flutter SDK bin directory to PATH, then reopen this script.
pause
exit /b 1
