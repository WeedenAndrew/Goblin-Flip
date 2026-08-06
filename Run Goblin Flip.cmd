@echo off
title Goblin Flip
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 goto missing_flutter

echo Preparing Goblin Flip...
call flutter pub get
if errorlevel 1 goto failed

echo.
echo Opening Goblin Flip in Chrome...
echo Keep this window open while the game is running.
call flutter run -d chrome --web-port 7357 --web-browser-flag="--autoplay-policy=no-user-gesture-required"
if errorlevel 1 goto failed
goto end

:missing_flutter
echo.
echo Flutter was not found on PATH.
echo Add the Flutter SDK bin directory to PATH, then reopen this script.
pause
goto end

:failed
echo.
echo Flutter could not run the project.
echo Copy the error output when reporting the launch failure.
pause

:end
