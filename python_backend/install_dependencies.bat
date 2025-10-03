@echo off
REM Script pour installer les dépendances Python pour le backend EBM
echo 🐍 Installation des dependances Python pour EBM Backend...

REM Vérifier si Python est installé
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Erreur: Python n'est pas installe ou pas dans le PATH
    echo Veuillez installer Python depuis https://www.python.org/
    pause
    exit /b 1
)

REM Créer un environnement virtuel si il n'existe pas
if not exist "venv" (
    echo 📦 Creation de l'environnement virtuel...
    python -m venv venv
)

REM Activer l'environnement virtuel
echo 🔧 Activation de l'environnement virtuel...
call venv\Scripts\activate.bat

REM Installer les dépendances
echo 📥 Installation des packages Python...
pip install --upgrade pip
pip install -r requirements.txt

echo ✅ Installation terminee!
echo 🚀 Pour demarrer le serveur, lancez: start_server.bat
pause