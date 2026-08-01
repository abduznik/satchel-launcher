@echo off
echo === Satchel Build Package ===
echo.

set BUILD_DIR=F:\Coding\ProjectIndie\build
set RELEASE_DIR=%BUILD_DIR%\windows\x64\runner\Release
set OUTPUT=%BUILD_DIR%\satchel-release.zip

echo Cleaning old build...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"

echo Building...
flutter build windows --release
if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Copying app.so into data\...
if not exist "%RELEASE_DIR%\data" mkdir "%RELEASE_DIR%\data"
copy /y "%BUILD_DIR%\windows\app.so" "%RELEASE_DIR%\data\app.so"

echo Copying flutter_assets into data\...
xcopy /s /e /y /q "%BUILD_DIR%\flutter_assets" "%RELEASE_DIR%\data\flutter_assets\"

echo.
echo Creating satchel-release.zip...
if exist "%OUTPUT%" del /q "%OUTPUT%"
powershell -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath '%OUTPUT%'"

echo.
echo Done! Output: %OUTPUT%
echo.
pause
