@echo off
setlocal
title Build Goblin Flip Play Bundle
cd /d "%~dp0"

set "FLUTTER_CMD=flutter"
set "BUNDLE_PATH=%CD%\build\app\outputs\bundle\release\app-release.aab"

where %FLUTTER_CMD% >nul 2>nul
if errorlevel 1 goto missing_flutter
if not exist "android\key.properties" goto missing_signing
findstr /L /C:"replace-me" "android\key.properties" >nul
if not errorlevel 1 goto placeholder_signing

findstr /L /C:"com.AIO.goblinFlip" "android\app\build.gradle.kts" >nul
if errorlevel 1 goto unexpected_id

if exist "%BUNDLE_PATH%" del /q "%BUNDLE_PATH%"
if exist "%BUNDLE_PATH%" goto stale_bundle

echo Preparing the Play Store bundle...
call "%FLUTTER_CMD%" pub get
if errorlevel 1 goto failed

echo.
echo Running static analysis...
call "%FLUTTER_CMD%" analyze
if errorlevel 1 goto failed

echo.
echo Running the complete test suite...
call "%FLUTTER_CMD%" test
if errorlevel 1 goto failed

echo.
echo Building the signed Android App Bundle...
call "%FLUTTER_CMD%" build appbundle --release
if errorlevel 1 goto failed

if not exist "%BUNDLE_PATH%" goto missing_bundle

echo.
echo Goblin Flip Play Bundle is ready:
echo %BUNDLE_PATH%
echo.
echo Upload this AAB to an internal testing track before production.
pause
exit /b 0

:missing_flutter
echo.
echo Flutter was not found on PATH.
echo Add the Flutter SDK bin directory to PATH, then reopen this script.
pause
exit /b 1

:missing_signing
echo.
echo Play signing is not configured.
echo Create an upload keystore, then copy android\key.properties.example to
echo android\key.properties and replace every placeholder.
pause
exit /b 1

:placeholder_signing
echo.
echo android\key.properties still contains replace-me.
echo Enter the real upload-key password in both password fields, save, and retry.
pause
exit /b 1

:unexpected_id
echo.
echo The Android application ID must remain com.AIO.goblinFlip.
echo Stop and review the identity files before building a release.
pause
exit /b 1

:stale_bundle
echo.
echo The previous bundle could not be removed:
echo %BUNDLE_PATH%
echo Close anything using that file, then retry.
pause
exit /b 1

:missing_bundle
echo.
echo Flutter reported success, but the bundle was not found at:
echo %BUNDLE_PATH%
pause
exit /b 1

:failed
echo.
echo The Play Bundle build stopped because a check failed.
echo No previous AAB will be left behind for accidental upload.
pause
exit /b 1
