@echo off
title Git Push - Edut Mobile
cd /d "%~dp0"

echo.
echo ================================================
echo   Git Push - Edut Mobile
echo ================================================
echo.

set "GIT_CMD=git"
where git >nul 2>nul
if errorlevel 1 (
    if exist "C:\Program Files\Git\cmd\git.exe" set "GIT_CMD=C:\Program Files\Git\cmd\git.exe"
)

echo  Adding all changes...
"%GIT_CMD%" add -A

"%GIT_CMD%" diff-index --quiet HEAD -- 2>nul
if not errorlevel 1 (
    echo  No new changes to commit. Pushing branch...
    "%GIT_CMD%" push origin main
    echo.
    pause
    exit /b 0
)

echo.
echo  Committing updates...
"%GIT_CMD%" commit -m "feat(offline): complete True Offline-First with Delta Sync, Offline Auth, Media Queue, and Cascades"

echo.
echo  Pushing to GitHub...
"%GIT_CMD%" push origin main
if errorlevel 1 ( echo  FAILED at git push && pause && exit /b 1 )

echo.
echo ================================================
echo   SUCCESS! Pushed to GitHub - main
echo ================================================
echo.
pause
