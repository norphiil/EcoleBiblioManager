@echo off
REM Script pour installer automatiquement les DLLs pyzbar manquantes

cd /d "%~dp0"

echo.
echo Installation des DLLs pyzbar...
echo.

REM Exécuter le script PowerShell
powershell -ExecutionPolicy Bypass -File "%~dp0install_pyzbar_dlls.ps1"

if %errorlevel% neq 0 (
  echo.
  echo Erreur lors de l'installation.
  pause
  exit /b 1
)

echo.
echo Installation terminee!
pause
