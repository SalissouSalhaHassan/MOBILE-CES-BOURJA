Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  COMPILATION NOUVEAU APK (Edut Pro Mobile)" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan

Set-Location -Path "C:\Users\User\Desktop\Edut\mobile"

$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH

$flutterCmd = "flutter"
if (Test-Path "C:\src\flutter\bin\flutter.bat") {
    $flutterCmd = "C:\src\flutter\bin\flutter.bat"
}

Write-Host "`n[1/3] Installation des packages..." -ForegroundColor Green
& $flutterCmd pub get

Write-Host "`n[2/3] Arrêt des processus Gradle résiduels..." -ForegroundColor Green
Set-Location -Path "C:\Users\User\Desktop\Edut\mobile\android"
& .\gradlew.bat --stop | Out-Null
Set-Location -Path "C:\Users\User\Desktop\Edut\mobile"

Write-Host "`n[3/3] Bâtissage du fichier app-release.apk..." -ForegroundColor Green
& $flutterCmd build apk --release --no-tree-shake-icons

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n===================================================" -ForegroundColor Cyan
    Write-Host "  COMPILATION TERMINÉE AVEC SUCCÈS !" -ForegroundColor Green
    Write-Host "  Fichier APK disponible ici :" -ForegroundColor Yellow
    Write-Host "  C:\Users\User\Desktop\Edut\mobile\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
    Write-Host "===================================================" -ForegroundColor Cyan
} else {
    Write-Host "`n===================================================" -ForegroundColor Red
    Write-Host "  [!] ÉCHEC DE LA COMPILATION (Code d'erreur: $LASTEXITCODE)" -ForegroundColor Red
    Write-Host "===================================================" -ForegroundColor Red
}
