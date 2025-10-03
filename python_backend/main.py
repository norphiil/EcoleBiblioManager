#!/usr/bin/env python3
"""
Backend FastAPI pour la détection de codes-barres
Serveur local pour l'application Flutter EBM
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import cv2
import numpy as np
from pyzbar import pyzbar
from PIL import Image
import io
import base64
import logging
import time
from typing import List, Dict, Any, Optional
import json

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("barcode_backend")

# Pour activer les logs DEBUG, décommentez la ligne suivante:
# logger.setLevel(logging.DEBUG)

logger.info("🚀 Configuration des logs terminée")

# Initialisation FastAPI
app = FastAPI(
    title="EBM Barcode Detection API",
    description="Backend de détection de codes-barres pour l'application Flutter EBM",
    version="1.0.0"
)

# Configuration CORS pour permettre les requêtes depuis Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class BarcodeDetector:
    """Détecteur de codes-barres robuste et rapide"""
    
    def __init__(self):
        self.supported_formats = [
            pyzbar.ZBarSymbol.EAN8,
            pyzbar.ZBarSymbol.EAN13,
            pyzbar.ZBarSymbol.UPCA,
            pyzbar.ZBarSymbol.UPCE,
            pyzbar.ZBarSymbol.CODE39,
            pyzbar.ZBarSymbol.CODE128,
            pyzbar.ZBarSymbol.QRCODE
            # DATAMATRIX n'est pas disponible dans cette version de pyzbar
        ]
        logger.info("🤖 BarcodeDetector initialisé")

    def preprocess_image(self, image: np.ndarray) -> List[np.ndarray]:
        """
        Prétraitement de l'image pour améliorer la détection
        Retourne plusieurs versions de l'image optimisées
        """
        processed_images = []
        
        # Image originale
        processed_images.append(image)
        
        # Conversion en niveaux de gris si nécessaire
        if len(image.shape) == 3:
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        else:
            gray = image
            
        processed_images.append(gray)
        
        # Amélioration du contraste (CLAHE)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)
        processed_images.append(enhanced)
        
        # Seuillage adaptatif
        thresh = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
        )
        processed_images.append(thresh)
        
        # Filtre médian pour réduire le bruit
        denoised = cv2.medianBlur(gray, 3)
        processed_images.append(denoised)
        
        # Augmentation de la netteté
        kernel = np.array([[-1,-1,-1],
                          [-1, 9,-1],
                          [-1,-1,-1]])
        sharpened = cv2.filter2D(gray, -1, kernel)
        processed_images.append(sharpened)
        
        return processed_images

    def detect_barcodes(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Détecte les codes-barres dans une image
        """
        start_time = time.time()
        detected_barcodes = []
        
        try:
            # Prétraitement de l'image
            processed_images = self.preprocess_image(image)
            
            # Tentative de détection sur chaque version prétraitée
            for i, processed_img in enumerate(processed_images):
                barcodes = pyzbar.decode(processed_img, symbols=self.supported_formats)
                
                if barcodes:
                    logger.info(f"✅ Codes-barres détectés avec la méthode {i} - {len(barcodes)} codes trouvés")
                    break
            else:
                logger.info("❌ Aucun code-barres détecté après toutes les tentatives")
                barcodes = []
            
            for i, barcode in enumerate(barcodes):
                # Décodage des données
                barcode_data = barcode.data.decode('utf-8')
                barcode_type = barcode.type
                
                # Coordonnées du rectangle
                points = barcode.polygon
                if len(points) == 4:
                    # Rectangle normal
                    x = min([p.x for p in points])
                    y = min([p.y for p in points])
                    w = max([p.x for p in points]) - x
                    h = max([p.y for p in points]) - y
                else:
                    # Fallback avec rect
                    x, y, w, h = barcode.rect
                
                detected_barcode = {
                    "data": barcode_data,
                    "type": barcode_type,
                    "confidence": 1.0,  # pyzbar ne fournit pas de score de confiance
                    "bbox": {
                        "x": int(x),
                        "y": int(y),
                        "width": int(w),
                        "height": int(h)
                    },
                    "polygon": [{"x": p.x, "y": p.y} for p in points]
                }
                detected_barcodes.append(detected_barcode)
            
            processing_time = time.time() - start_time
            logger.info(f"⚡ Détection terminée en {processing_time:.3f}s - {len(detected_barcodes)} codes trouvés")
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de la détection: {str(e)}")
            raise
        
        return detected_barcodes

    def _rotate_image(self, image: np.ndarray, angle: int) -> np.ndarray:
        """Rotation d'une image"""
        (h, w) = image.shape[:2]
        center = (w // 2, h // 2)
        matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
        rotated = cv2.warpAffine(image, matrix, (w, h))
        return rotated

# Instance globale du détecteur
detector = BarcodeDetector()

# Compteur de requêtes pour le suivi
request_counter = 0

@app.get("/")
async def root():
    """Point d'entrée de l'API"""
    return {
        "message": "EBM Barcode Detection API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "detect": "/detect - POST - Détection de codes-barres",
            "health": "/health - GET - Vérification de l'état"
        }
    }

@app.get("/health")
async def health_check():
    """Vérification de l'état du serveur"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "detector": "ready"
    }

@app.post("/detect")
async def detect_barcodes_endpoint(file: UploadFile = File(...)):
    """
    Endpoint pour la détection de codes-barres
    Reçoit une image et retourne les codes-barres détectés
    """
    try:
        logger.info("🚀 Nouvelle requête /detect")
        # Validation du type de fichier
        if not file.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="Le fichier doit être une image")
        
        # Lecture de l'image
        image_data = await file.read()
        
        # Conversion en image OpenCV
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Impossible de décoder l'image")
        
        # Détection des codes-barres
        barcodes = detector.detect_barcodes(image)
        
        response = {
            "success": True,
            "timestamp": time.time(),
            "image_info": {
                "width": image.shape[1],
                "height": image.shape[0],
                "channels": image.shape[2] if len(image.shape) > 2 else 1
            },
            "barcodes_count": len(barcodes),
            "barcodes": barcodes
        }
        
        logger.info(f"📊 Réponse: {len(barcodes)} codes-barres détectés")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erreur dans l'endpoint detect: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")

@app.post("/detect_base64")
async def detect_barcodes_base64(data: Dict[str, str]):
    """
    Endpoint pour la détection avec image en base64
    Alternative plus pratique pour Flutter
    """
    global request_counter
    request_counter += 1
    request_start = time.time()
    
    try:
        if "image" not in data:
            logger.error("❌ Champ 'image' manquant dans la requête")
            raise HTTPException(status_code=400, detail="Champ 'image' requis")
        
        # Décodage base64
        image_data = base64.b64decode(data["image"])
        
        # Conversion en image OpenCV
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(status_code=400, detail="Impossible de décoder l'image base64")
        
        # Détection des codes-barres
        barcodes = detector.detect_barcodes(image)
        
        request_time = time.time() - request_start
        
        response = {
            "success": True,
            "timestamp": time.time(),
            "processing_time": request_time,
            "image_info": {
                "width": image.shape[1],
                "height": image.shape[0],
                "channels": image.shape[2] if len(image.shape) > 2 else 1
            },
            "barcodes_count": len(barcodes),
            "barcodes": barcodes
        }
        
        logger.info(f"✅ Requête traitée en {request_time:.3f}s - {len(barcodes)} codes retournés")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erreur dans l'endpoint detect_base64: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Erreur interne: {str(e)}")

if __name__ == "__main__":
    logger.info("🚀 Démarrage du serveur EBM Barcode Detection API")
    logger.info("📊 Niveau de log actuel: INFO (utilisez DEBUG pour plus de détails)")
    logger.info("🔗 Serveur disponible sur: http://127.0.0.1:8000")
    
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8000,
        log_level="info"
    )