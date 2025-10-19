@echo off
echo ==========================================
echo   Building Tiksar VPN - Release APK
echo ==========================================
echo.

REM Set correct Flutter storage URLs
set FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com
set PUB_HOSTED_URL=https://pub.dev

echo [1/3] Cleaning previous build...
call flutter clean

echo.
echo [2/3] Getting dependencies...
call flutter pub get

echo.
echo [3/3] Building APK (This may take 5-15 minutes)...
call flutter build apk --release

echo.
echo ==========================================
echo   Build Complete!
echo ==========================================
echo APK Location: build\app\outputs\flutter-apk\app-release.apk
echo.
pause
