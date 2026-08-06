@echo off
setlocal
title Build Goblin Flip Android APK
cd /d "%~dp0"

set "FLUTTER_CMD=flutter"
set "APK_PATH=%CD%\build\app\outputs\flutter-apk\app-debug.apk"

where %FLUTTER_CMD% >nul 2>nul
if errorlevel 1 goto missing_flutter
if exist "%APK_PATH%" del /q "%APK_PATH%"
if exist "%APK_PATH%" goto stale_apk

echo Preparing Goblin Flip...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 goto failed

echo.
echo Running tests before packaging...
call "%FLUTTER_CMD%" test
if errorlevel 1 goto failed

echo.
echo Building the Android debug APK...
call "%FLUTTER_CMD%" build apk --debug
if errorlevel 1 goto failed

if not exist "%APK_PATH%" goto missing_apk

echo.
echo Goblin Flip is ready:
echo %APK_PATH%
echo.
echo This is a local debug build, not a Play Store release.
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
echo Flutter reported success, but the APK was not found at:
echo %APK_PATH%
pause
exit /b 1

:stale_apk
echo.
echo The previous APK could not be removed:
echo %APK_PATH%
echo Close anything using that file, then run this build again.
pause
exit /b 1

:failed
echo.
echo The Android build stopped because a command failed.
echo No previous APK will be left behind for the installer to reuse.
echo Copy the error output when reporting the build failure.
pause
exit /b 1
