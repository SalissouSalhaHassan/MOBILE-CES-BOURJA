@echo off
title Edut Pro - CES BOURJA APK Builder

echo ===================================================
echo   COMPILATION NOUVEAU APK (Edut Pro - CES BOURJA)
echo ===================================================
echo.

cd /d "%~dp0"

set FLUTTER_EXE=flutter
if exist "C:\src\flutter\bin\flutter.bat" (
    set FLUTTER_EXE=C:\src\flutter\bin\flutter.bat
)

echo [1/4] Nettoyage du cache Flutter (Clean)...
call %FLUTTER_EXE% clean

echo.
echo [2/4] Installation des packages...
call %FLUTTER_EXE% pub get
if errorlevel 1 (
    echo Erreur lors de flutter pub get.
    pause
    exit /b 1
)

echo.
echo [3/4] Verification Gradle...
cd android
call gradlew.bat --stop >nul 2>&1
cd ..

echo.
echo [4/4] Compilation du fichier APK Release pour CES BOURJA...
call %FLUTTER_EXE% build apk --release --no-tree-shake-icons --dart-define=EDUT_WEB_API_BASE_URL=https://edut-web-ces-bourja.vercel.app --dart-define=SUPABASE_URL=https://hxweqrfgqlrzjcjjemme.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_wyxNZnhEVc0r-m1XZZrxNQ_OoV-H5vD
if errorlevel 1 (
    echo.
    echo ===================================================
    echo   ECHEC DE LA COMPILATION !
    echo   Veuillez verifier les messages d'erreur ci-dessus.
    echo ===================================================
    pause
    exit /b 1
)

echo.
echo ===================================================
echo   COMPILATION TERMINEE AVEC SUCCES !
echo   Fichier APK genere a :
echo   %~dp0build\app\outputs\flutter-apk\app-release.apk
echo ===================================================
echo.
pause
