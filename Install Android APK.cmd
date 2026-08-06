@echo off
setlocal
title Install Goblin Flip on Android
cd /d "%~dp0"

set "FLUTTER_CMD=flutter"
set "APK_PATH=%CD%\build\app\outputs\flutter-apk\app-debug.apk"

where %FLUTTER_CMD% >nul 2>nul
if errorlevel 1 goto missing_flutter
if not exist "%APK_PATH%" goto missing_apk

echo Connected Flutter devices:
echo.
call "%FLUTTER_CMD%" devices
if errorlevel 1 goto failed

echo.
echo Enter the Android device ID shown between the bullet separators.
echo Examples: emulator-5554 or a USB device serial.
echo Leave it blank to cancel.
set /p "DEVICE_ID=Android device ID: "

if not defined DEVICE_ID goto cancelled

echo.
echo Installing Goblin Flip on %DEVICE_ID%...
call "%FLUTTER_CMD%" install --debug -d "%DEVICE_ID%"
if errorlevel 1 goto failed

echo.
echo Goblin Flip is installed. Open it from the device's app list.
pause
exit /b 0

:missing_flutter
echo.
echo Flutter was not found on PATH.
echo Add the Flutter SDK bin directory to PATH, then reopen this script.
pause
exit /b 1

:missing_apk
echo.
echo The Android APK has not been built yet.
echo Run Build Android APK.cmd first.
pause
exit /b 1

:cancelled
echo.
echo Installation cancelled.
pause
exit /b 0

:failed
echo.
echo Installation failed.
echo Confirm that an Android emulator is running, or that USB debugging is
echo enabled and authorized on the connected phone.
echo Copy the error output when reporting the installation failure.
pause
exit /b 1
