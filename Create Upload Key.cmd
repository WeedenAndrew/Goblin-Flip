@echo off
setlocal
title Create Goblin Flip Upload Key
cd /d "%~dp0"

set "KEYTOOL="
set "KEY_DIR=%USERPROFILE%\Documents\GoblinFlipRelease"
set "KEYSTORE=%KEY_DIR%\goblin-flip-upload-keystore.jks"

for /f "delims=" %%I in ('where keytool.exe 2^>nul') do if not defined KEYTOOL set "KEYTOOL=%%I"
if not defined KEYTOOL if exist "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" set "KEYTOOL=C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if not defined KEYTOOL goto missing_keytool
if exist "%KEYSTORE%" goto existing_key

if not exist "%KEY_DIR%" mkdir "%KEY_DIR%"
if not exist "%KEY_DIR%" goto failed

echo Creating the private upload key outside the project:
echo %KEYSTORE%
echo.
echo Store the password securely. It cannot be recovered if it is lost.
echo You may use the same password when keytool asks for the key password.
echo.
"%KEYTOOL%" -genkeypair -v -keystore "%KEYSTORE%" -keyalg RSA -keysize 2048 -validity 10000 -alias goblin-flip-upload
if errorlevel 1 goto failed

copy /Y "android\key.properties.example" "android\key.properties" >nul
echo.
echo Upload key created. android\key.properties is open for you to finish.
echo Set storePassword and keyPassword to the password you just chose.
echo Set keyAlias=goblin-flip-upload
echo Set storeFile=%KEYSTORE:\=\\%
echo.
start "" notepad.exe "android\key.properties"
pause
exit /b 0

:existing_key
echo.
echo A key already exists at:
echo %KEYSTORE%
echo It was not overwritten.
pause
exit /b 1

:missing_keytool
echo.
echo Java keytool was not found. Repair Android Studio or install a JDK.
pause
exit /b 1

:failed
echo.
echo The upload key was not created.
pause
exit /b 1
