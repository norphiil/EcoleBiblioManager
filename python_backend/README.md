# Backend Python - EBM Barcode Scanner

## 🚀 Installation Automatique

Lors du premier lancement de l'application Flutter, l'installation se fait automatiquement :

1. **Vérification de Python** - Détection de Python sur le système
2. **Création environnement virtuel** - Isolation des dépendances
3. **Installation pip** - Mise à jour du gestionnaire de packages
4. **Installation dépendances** - FastAPI, OpenCV, pyzbar, etc.
5. **Démarrage serveur** - Lancement du serveur de détection

## 📋 Dépendances Installées

- **FastAPI** (0.104.1) - Serveur web moderne et rapide
- **uvicorn** (0.24.0) - Serveur ASGI pour FastAPI  
- **opencv-python** (4.8.1.78) - Traitement d'images
- **pyzbar** (0.1.9) - Décodage de codes-barres
- **Pillow** (10.1.0) - Manipulation d'images
- **numpy** (1.24.3) - Calculs numériques
- **python-multipart** (0.0.6) - Support upload fichiers

## 🔧 Configuration Automatique

L'application Flutter gère automatiquement :

- ✅ Détection de l'environnement Python existant
- ✅ Création de l'environnement virtuel si nécessaire
- ✅ Installation des dépendances manquantes
- ✅ Démarrage/arrêt du serveur backend
- ✅ Vérification de l'état du serveur
- ✅ Communication HTTP avec retry automatique

## 📡 API Endpoints

### `/` - Informations générales
```json
{
  "message": "EBM Barcode Detection API",
  "version": "1.0.0",
  "status": "running"
}
```

### `/health` - État du serveur
```json
{
  "status": "healthy",
  "timestamp": 1696284000.123,
  "detector": "ready"
}
```

### `/detect` - Détection codes-barres (fichier)
**POST** avec fichier image
```json
{
  "success": true,
  "barcodes_count": 1,
  "barcodes": [
    {
      "data": "9782123456789",
      "type": "EAN13",
      "confidence": 1.0,
      "bbox": {"x": 100, "y": 50, "width": 200, "height": 100}
    }
  ]
}
```

### `/detect_base64` - Détection codes-barres (base64)
**POST** avec image en base64
```json
{
  "image": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

## 🎯 Formats Supportés

- **EAN8** / **EAN13** - Codes produits européens
- **UPC-A** / **UPC-E** - Codes produits américains  
- **Code39** / **Code128** - Codes alphanumériques
- **QR Code** - Codes bidimensionnels
- **DataMatrix** - Codes matrices

## ⚡ Optimisations

Le backend utilise plusieurs techniques pour améliorer la détection :

1. **Prétraitement multi-niveaux** :
   - Image originale
   - Conversion niveaux de gris
   - Amélioration contraste (CLAHE)
   - Seuillage adaptatif
   - Filtre médian (réduction bruit)
   - Augmentation netteté

2. **Tentatives multiples** :
   - Rotation (90°, 180°, 270°) si échec
   - Différents paramètres de détection
   - Fallback sur méthodes alternatives

3. **Performance** :
   - Serveur asynchrone (FastAPI + uvicorn)
   - Traitement parallèle possible
   - Cache des modèles en mémoire

## 🛠️ Développement

### Lancement manuel du serveur
```bash
cd python_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

### Tester l'API
```bash
# Vérifier l'état
curl http://127.0.0.1:8000/health

# Documentation interactive
http://127.0.0.1:8000/docs
```

## 🐛 Dépannage

**Problème** : "ModuleNotFoundError: No module named 'fastapi'"
**Solution** : L'installation automatique se chargera d'installer les dépendances

**Problème** : "Python not found"
**Solution** : Installer Python 3.8+ depuis https://www.python.org/

**Problème** : Timeout lors du démarrage
**Solution** : Première installation peut prendre 1-2 minutes selon la connexion

## 📱 Intégration Flutter

Le scanner Flutter communique avec ce backend via :

```dart
// Service automatique
final PythonBackendService backend = PythonBackendService();
await backend.startServer(); // Installation auto si nécessaire

// Détection d'image
final result = await backend.detectBarcodes(base64Image);
```

L'utilisateur n'a rien à configurer manuellement ! 🎉