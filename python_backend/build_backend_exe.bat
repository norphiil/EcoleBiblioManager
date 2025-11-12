@echo off
setlocal

REM Build a standalone Windows executable for the Python backend using PyInstaller
REM Requires Python and pip installed on the build machine only (not on end-user machines)

cd /d "%~dp0"

where python >nul 2>nul
if %errorlevel% neq 0 (
  echo Python is required on the build machine to create the executable.
  echo Download from https://www.python.org/downloads/
  pause
  exit /b 1
)

REM Create and activate build venv
if not exist .venv (
  python -m venv .venv
)
call .venv\Scripts\activate.bat

python -m pip install --upgrade pip
python -m pip install -r requirements.txt pyinstaller==6.3.0

echo.
echo ============================================
echo Verification et installation des DLLs pyzbar
echo ============================================
echo.

REM Verification des DLLs
python check_pyzbar_dlls.py
if %errorlevel% equ 0 (
  echo.
  echo ✓ Toutes les DLLs pyzbar sont presentes!
  echo.
) else (
  echo.
  echo ⚠ DLLs pyzbar manquantes, installation automatique...
  echo.
  
  REM Essayer d'installer automatiquement via PowerShell
  powershell -ExecutionPolicy Bypass -File "%~dp0install_pyzbar_dlls.ps1" -NoWait
  
  if %errorlevel% neq 0 (
    echo.
    echo ERREUR: Installation automatique des DLLs a echoue.
    echo.
    echo Solutions:
    echo   1. Executez manuellement: install_pyzbar_dlls.bat
    echo   2. Ou consultez: TROUBLESHOOTING_PYZBAR.md
    echo.
    pause
    exit /b 1
  )
  
  REM Re-verifier apres installation
  echo.
  echo Verification post-installation...
  python check_pyzbar_dlls.py
  if %errorlevel% neq 0 (
    echo.
    echo ERREUR: Les DLLs sont toujours manquantes apres installation.
    echo Consultez TROUBLESHOOTING_PYZBAR.md pour aide.
    pause
    exit /b 1
  )
  
  echo.
  echo ✓ DLLs installees avec succes!
  echo.
)

REM Clean previous builds
if exist build rmdir /s /q build
if exist dist rmdir /s /q dist

REM Check if custom spec file exists
if not exist ebm_backend.spec (
  echo ERROR: ebm_backend.spec not found!
  echo Please ensure ebm_backend.spec exists in the python_backend directory.
  pause
  exit /b 1
)

echo Using custom ebm_backend.spec configuration...
echo.

REM Build using the custom spec file
pyinstaller ebm_backend.spec

if %errorlevel% neq 0 (
  echo.
  echo ❌ Build failed.
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================
echo Build succeeded! ✓
echo ============================================
echo.
echo Executable cree: %cd%\dist\ebm_backend.exe
echo.
echo L'executable contient:
echo   ✓ Python + toutes les dependances
echo   ✓ FastAPI + uvicorn
echo   ✓ OpenCV + pyzbar
echo   ✓ DLLs natives (libiconv, libzbar)
echo.
echo Vous pouvez maintenant distribuer ebm_backend.exe
echo sans que Python soit installe sur les machines cibles.
echo.
pause

endlocal
