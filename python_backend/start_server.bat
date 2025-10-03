@echo off
REM Script pour démarrer le serveur FastAPI
cd /d "%~dp0"

echo 🚀 Demarrage du serveur EBM Barcode Detection API...

REM Vérifier si l'environnement virtuel existe
if not exist "venv\Scripts\activate.bat" (
    echo ❌ Environnement virtuel non trouve
    echo Veuillez d'abord executer install_dependencies.bat
    pause
    exit /b 1
)

REM Activer l'environnement virtuel
call venv\Scripts\activate.bat

REM Démarrer le serveur
echo 🌐 Serveur disponible sur: http://127.0.0.1:8000
echo 📡 Documentation API: http://127.0.0.1:8000/docs
python main.py