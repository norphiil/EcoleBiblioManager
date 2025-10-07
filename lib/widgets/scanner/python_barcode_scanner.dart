import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../services/python_backend_service.dart';

/// CustomPainter pour dessiner le cadre de scan professionnel
class ScanFramePainter extends CustomPainter {
  final double cornerLength;
  final double cornerWidth;
  final Color frameColor;

  ScanFramePainter({
    required this.cornerLength,
    required this.cornerWidth,
    required this.frameColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Coin supérieur gauche
    path.moveTo(0, cornerLength);
    path.lineTo(0, 0);
    path.lineTo(cornerLength, 0);

    // Coin supérieur droit
    path.moveTo(size.width - cornerLength, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cornerLength);

    // Coin inférieur droit
    path.moveTo(size.width, size.height - cornerLength);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width - cornerLength, size.height);

    // Coin inférieur gauche
    path.moveTo(cornerLength, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, size.height - cornerLength);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Scanner de codes-barres avec IA Python - Interface moderne et optimisée
class PythonBarcodeScanner extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final VoidCallback? onError;
  final Duration captureInterval;

  const PythonBarcodeScanner({
    Key? key,
    required this.onBarcodeDetected,
    this.onError,
    this.captureInterval = const Duration(seconds: 1),
  }) : super(key: key);

  @override
  State<PythonBarcodeScanner> createState() => _PythonBarcodeScannerState();
}

class _PythonBarcodeScannerState extends State<PythonBarcodeScanner> 
    with TickerProviderStateMixin {
  CameraController? _controller;
  final PythonBackendService _backendService = PythonBackendService();
  
  Timer? _captureTimer;
  bool _isScanning = false;
  bool _isReady = false;
  bool _isSwitchingCamera = false; // État de changement de caméra
  String? _lastDetectedBarcode;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  double _cameraRotation = 0.0;
  bool _showCameraDropdown = false;
  
  // Champ de saisie manuelle ISBN
  final TextEditingController _manualIsbnController = TextEditingController();
  final FocusNode _manualIsbnFocusNode = FocusNode();
  
  // Animations pour l'UI
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  String _statusMessage = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    
    // Initialiser les animations pour une UI moderne
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Écouter les changements de focus pour afficher/masquer l'indicateur de pause
    _manualIsbnFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    
    _initializeScanner();
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();
    _controller?.dispose();
    _backendService.dispose();
    _manualIsbnController.dispose();
    _manualIsbnFocusNode.dispose();
    super.dispose();
  }

  /// Initialise le scanner et le backend Python
  Future<void> _initializeScanner() async {
    try {
      setState(() {
        _statusMessage = 'Démarrage de l\'IA de détection...';
      });

      final backendStarted = await _backendService.startServer(
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
            });
          }
        },
      );
      
      if (!backendStarted) {
        setState(() {
          _statusMessage = 'Erreur: IA indisponible';
        });
        widget.onError?.call();
        return;
      }

      setState(() {
        _statusMessage = 'Configuration de la caméra...';
      });

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('Aucune caméra disponible');
      }

      // Note: Les erreurs de threading camera_windows dans la console sont normales
      // et n'affectent pas le fonctionnement du scanner
      debugPrint('ℹ️ Note: Les messages d\'erreur de threading camera_windows sont un bug connu du plugin et peuvent être ignorés');
      
      await _initializeCamera();
      _startPeriodicCapture();

      setState(() {
        _isReady = true;
        _statusMessage = 'Scanner prêt ✓';
      });

    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur: $e';
      });
      widget.onError?.call();
    }
  }

  /// Initialise la caméra avec gestion des erreurs de threading Windows
  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        _cameras[_selectedCameraIndex],
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false, // Désactiver l'audio pour éviter des problèmes de ressources
      );
      
      // Initialiser avec gestion d'erreur pour le bug camera_windows
      await _controller!.initialize();
      
      // Vérifier que l'initialisation a réussi
      if (!_controller!.value.isInitialized) {
        throw CameraException('camera_init_failed', 'La caméra n\'a pas pu être initialisée');
      }
    } on CameraException catch (e) {
      // Gérer spécifiquement les erreurs de caméra
      debugPrint('⚠️ Erreur caméra (ignorée si threading): ${e.code} - ${e.description}');
      
      // Si c'est juste un problème de threading mais que la caméra fonctionne, continuer
      if (_controller?.value.isInitialized == true) {
        debugPrint('✓ Caméra initialisée malgré l\'erreur de threading');
        return;
      }
      
      // Sinon, propager l'erreur
      rethrow;
    } catch (e) {
      debugPrint('❌ Erreur initialisation caméra: $e');
      rethrow;
    }
  }

  /// Démarre la capture périodique avec l'intervalle configuré
  void _startPeriodicCapture() {
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(widget.captureInterval, (timer) {
      if (!_isScanning && _isReady && _controller?.value.isInitialized == true) {
        _captureAndAnalyze();
      }
    });
  }

  /// Capture et analyse une image
  Future<void> _captureAndAnalyze() async {
    if (_isScanning || !_isReady || _controller?.value.isInitialized != true) return;
    
    // Ne pas scanner si l'utilisateur tape dans le champ manuel
    if (_manualIsbnFocusNode.hasFocus) return;

    try {
      // Éviter setState si le focus est sur le champ manuel
      if (!_manualIsbnFocusNode.hasFocus && mounted) {
        setState(() => _isScanning = true);
      } else {
        _isScanning = true;
      }

      final XFile imageFile = await _controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Nettoyer immédiatement le fichier temporaire
      try {
        await File(imageFile.path).delete();
      } catch (e) {
        debugPrint('Nettoyage fichier: $e');
      }
      
      final String base64Image = base64Encode(imageBytes);
      final result = await _backendService.detectBarcodes(base64Image);
      
      if (result != null && result['success'] == true) {
        final barcodes = result['barcodes'] as List?;
        if (barcodes?.isNotEmpty == true) {
          _processDetectionResults(barcodes!);
        }
      }
    } on CameraException catch (e) {
      // Ignorer les erreurs de threading du plugin camera_windows
      if (e.description?.contains('thread') == true || 
          e.description?.contains('ressources matérielles') == true) {
        debugPrint('⚠️ Erreur de threading camera_windows ignorée: ${e.description}');
      } else {
        debugPrint('❌ Erreur caméra: ${e.code} - ${e.description}');
      }
    } catch (e) {
      debugPrint('❌ Erreur capture: $e');
    } finally {
      // Éviter setState si le focus est sur le champ manuel
      if (!_manualIsbnFocusNode.hasFocus && mounted) {
        setState(() => _isScanning = false);
      } else if (mounted) {
        _isScanning = false;
      }
    }
  }

  /// Traite les résultats de détection avec priorisation des codes valides
  void _processDetectionResults(List<dynamic> barcodes) {
    if (barcodes.isEmpty) return;
    if (!mounted) return; // Ne pas traiter si le widget n'est plus monté
    
    // Extraire tous les codes détectés
    final detectedCodes = <String>[];
    for (final barcode in barcodes) {
      final data = barcode['data'] as String?;
      if (data?.isNotEmpty == true) {
        detectedCodes.add(data!);
      }
    }
    
    if (detectedCodes.isEmpty) return;
    
    // Si un seul code, traiter normalement
    if (detectedCodes.length == 1) {
      final code = detectedCodes.first;
      if (_lastDetectedBarcode != code) {
        _lastDetectedBarcode = code;
        // Arrêter le scanner immédiatement après détection
        _stopScanning();
        widget.onBarcodeDetected(code);
      }
      return;
    }
    
    // Si plusieurs codes, traiter intelligemment
    debugPrint('[Scanner] ${detectedCodes.length} codes détectés: ${detectedCodes.join(", ")}');
    
    // Prioriser le code qui semble le plus valide (ISBN format)
    final validIsbn = _findMostValidIsbn(detectedCodes);
    if (validIsbn != null && _lastDetectedBarcode != validIsbn) {
      _lastDetectedBarcode = validIsbn;
      debugPrint('[Scanner] Code sélectionné: $validIsbn');
      // Arrêter le scanner immédiatement après détection
      _stopScanning();
      widget.onBarcodeDetected(validIsbn);
    }
  }
  
  /// Arrête temporairement le scanner
  void _stopScanning() {
    _captureTimer?.cancel();
    setState(() {
      _isReady = false;
    });
  }
  
  /// Trouve l'ISBN le plus valide parmi une liste de codes
  String? _findMostValidIsbn(List<String> codes) {
    // Nettoyer et scorer chaque code
    final scoredCodes = <MapEntry<String, int>>[];
    
    for (final code in codes) {
      final cleanCode = _cleanIsbn(code);
      int score = 0;
      
      // Vérifier la longueur (ISBN-10 ou ISBN-13)
      if (cleanCode.length == 10 || cleanCode.length == 13) {
        score += 10;
      }
      
      // Vérifier le préfixe ISBN-13 (978 ou 979)
      if (cleanCode.startsWith('978') || cleanCode.startsWith('979')) {
        score += 5;
      }
      
      // Vérifier que c'est principalement numérique
      final numericChars = cleanCode.replaceAll('X', '').length;
      final totalChars = cleanCode.length;
      if (numericChars >= totalChars - 1) {
        score += 3;
      }
      
      // Bonus pour les codes plus longs (plus susceptibles d'être des ISBN)
      if (cleanCode.length >= 10) {
        score += cleanCode.length;
      }
      
      scoredCodes.add(MapEntry(code, score));
    }
    
    // Trier par score décroissant et retourner le meilleur
    scoredCodes.sort((a, b) => b.value.compareTo(a.value));
    return scoredCodes.isNotEmpty ? scoredCodes.first.key : null;
  }
  
  /// Nettoie un ISBN (retire les tirets, espaces et caractères spéciaux, garde seulement les chiffres)
  String _cleanIsbn(String isbn) {
    return isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
  }
  
  /// Traiter la saisie manuelle d'ISBN
  void _handleManualIsbn() {
    final rawIsbn = _manualIsbnController.text.trim();
    if (rawIsbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un ISBN'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Nettoyer l'ISBN : supprimer tous les caractères sauf les chiffres
    final cleanedIsbn = rawIsbn.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanedIsbn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ISBN invalide : aucun chiffre trouvé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Vérifier la longueur (ISBN-10 ou ISBN-13)
    if (cleanedIsbn.length != 10 && cleanedIsbn.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ISBN invalide : ${cleanedIsbn.length} chiffres (doit être 10 ou 13)'),
          backgroundColor: Colors.orange,
        ),
      );
      // On continue quand même avec le code nettoyé
    }
    
    // Appeler le callback avec l'ISBN nettoyé
    widget.onBarcodeDetected(cleanedIsbn);
    _manualIsbnController.clear();
  }

  /// Change de caméra par index
  Future<void> _switchToCamera(int index) async {
    if (index == _selectedCameraIndex || index >= _cameras.length) return;
    
    try {
      setState(() {
        _isSwitchingCamera = true; // Activer l'état de chargement
        _isReady = false; // Marquer comme non prêt
        _statusMessage = 'Changement de caméra...';
        _showCameraDropdown = false;
      });
      
      _captureTimer?.cancel();
      await _controller?.dispose();
      
      _selectedCameraIndex = index;
      await _initializeCamera();
      
      // Attendre que la caméra soit vraiment stable
      await Future.delayed(const Duration(milliseconds: 500));
      
      _startPeriodicCapture();
      
      setState(() {
        _isSwitchingCamera = false; // Désactiver l'état de chargement
        _isReady = true; // Marquer comme prêt
        _statusMessage = 'Caméra changée ✓';
      });
    } catch (e) {
      setState(() {
        _isSwitchingCamera = false;
        _isReady = false;
        _statusMessage = 'Erreur changement caméra: $e';
      });
    }
  }

  /// Fait une rotation de la caméra
  void _rotateCamera() {
    setState(() {
      _cameraRotation = (_cameraRotation + 90) % 360;
    });
  }

  /// Toggle du menu déroulant caméra
  void _toggleCameraDropdown() {
    setState(() {
      _showCameraDropdown = !_showCameraDropdown;
    });
  }

  /// Menu déroulant pour sélection de caméra
  Widget _buildCameraDropdown() {
    return GestureDetector(
      onTap: _toggleCameraDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: _showCameraDropdown
              ? Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              color: Colors.white.withValues(alpha: 0.9),
              size: 16,
            ),
            const SizedBox(width: 4),
            Icon(
              _showCameraDropdown ? Icons.expand_less : Icons.expand_more,
              color: Colors.white.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Menu déroulant complet des caméras
  Widget _buildCameraDropdownMenu() {
    return Positioned(
      top: 88,
      right: 20,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Sélectionner caméra',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ..._cameras.asMap().entries.map((entry) {
              final index = entry.key;
              final camera = entry.value;
              final isSelected = index == _selectedCameraIndex;
              
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _switchToCamera(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withValues(alpha: 0.2) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getCameraIcon(camera),
                          color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getCameraName(camera, index),
                            style: TextStyle(
                              color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  /// Obtenir l'icône de la caméra
  IconData _getCameraIcon(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.external:
        return Icons.videocam;
    }
  }

  /// Obtenir le nom réel de la caméra
  String _getCameraName(CameraDescription camera, int index) {
    if (camera.name.isNotEmpty) {
      // Nettoyer le nom de la caméra pour l'affichage
      String cleanName = camera.name;
      
      // Supprimer les préfixes techniques courants
      final prefixesToRemove = [
        'Microsoft Camera Codec Pack',
        'USB Video Device',
        'USB Camera',
      ];
      
      for (final prefix in prefixesToRemove) {
        cleanName = cleanName.replaceAll(prefix, '').trim();
      }
      
      // Supprimer les identifiants entre < >
      if (cleanName.contains('<')) {
        cleanName = cleanName.split('<')[0].trim();
      }
      
      // Nettoyer les caractères spéciaux
      cleanName = cleanName
          .replaceAll(RegExp(r'[\[\]{}()]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // Si le nom est trop long, le raccourcir
      if (cleanName.length > 25) {
        final words = cleanName.split(' ');
        if (words.length > 2) {
          cleanName = '${words[0]} ${words[1]}';
        } else {
          cleanName = '${cleanName.substring(0, 22)}...';
        }
      }
      
      // Retourner le nom nettoyé ou un fallback
      return cleanName.isNotEmpty ? cleanName : _getFallbackName(camera, index);
    }
    
    return _getFallbackName(camera, index);
  }
  
  /// Nom de fallback si le nom réel n'est pas disponible
  String _getFallbackName(CameraDescription camera, int index) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return 'Caméra avant';
      case CameraLensDirection.back:
        return 'Caméra arrière';
      case CameraLensDirection.external:
        return 'Caméra ${index + 1}';
    }
  }



  @override
  Widget build(BuildContext context) {
    // Afficher l'écran de chargement si non prêt OU en train de changer de caméra
    if (!_isReady || _isSwitchingCamera) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Vue caméra avec effet miroir et rotation - sans déformation
          if (_controller?.value.isInitialized == true)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(-1.0, 1.0) // Effet miroir
                    ..rotateZ(_cameraRotation * 3.14159 / 180),
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          
          // Overlay moderne avec cadre de scan animé
          _buildModernScanOverlay(),
          
          // Barre d'outils moderne
          _buildModernToolbar(),
          
          // Menu déroulant caméra
          if (_showCameraDropdown) _buildCameraDropdownMenu(),
          
          // Indicateur de scan en cours
          if (_isScanning) _buildScanningIndicator(),
          
          // Indicateur que le scanner est en pause (focus sur champ manuel)
          if (_manualIsbnFocusNode.hasFocus) _buildScannerPausedIndicator(),
          
          // Champ de saisie manuelle d'ISBN en bas
          _buildManualIsbnInput(),
        ],
      ),
    );
  }

  /// Écran de chargement moderne
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 60,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: Colors.grey.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Overlay sobre et professionnel avec cadre de scan
  Widget _buildModernScanOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculer les dimensions proportionnelles
        // Pour les codes-barres de livres
        final double scanWidth = constraints.maxWidth * 0.60;
        final double scanHeight = constraints.maxHeight * 0.30;
        
        // Calculer la taille des coins proportionnellement
        final double cornerLength = scanWidth * 0.12; // 12% de la largeur
        final double cornerWidth = 4.0;
        
        return Center(
          child: Container(
            width: scanWidth,
            height: scanHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Cadre principal avec coins stylisés
                CustomPaint(
                  size: Size(scanWidth, scanHeight),
                  painter: ScanFramePainter(
                    cornerLength: cornerLength,
                    cornerWidth: cornerWidth,
                    frameColor: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                
                // Ligne de scan animée sobre
                AnimatedBuilder(
                  animation: _scanAnimation,
                  builder: (context, child) {
                    final double scanLineTop = 16 + ((scanHeight - 32) * _scanAnimation.value);
                    return Positioned(
                      top: scanLineTop,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.blue.withValues(alpha: 0.8),
                              Colors.blue,
                              Colors.blue.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  },
                ),
                
                // Instructions discrètes
                Positioned(
                  bottom: -50,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Centrez le code-barres',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Barre d'outils sobre avec menu déroulant
  Widget _buildModernToolbar() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Statut IA discret
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _isReady ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isReady ? 'Prêt' : 'Init',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Contrôles caméra
          Row(
            children: [
              // Menu déroulant caméra
              if (_cameras.length > 1)
                _buildCameraDropdown(),
              const SizedBox(width: 8),
              // Rotation
              _buildToolButton(
                Icons.rotate_right,
                onTap: _rotateCamera,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bouton d'outil stylisé
  Widget _buildToolButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: 18,
        ),
      ),
    );
  }

  /// Indicateur de scan sobre et discret
  Widget _buildScanningIndicator() {
    return Positioned(
      bottom: 180,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  color: Colors.blue.withValues(alpha: 0.8),
                  strokeWidth: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Analyse...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Indicateur que le scanner est en pause (focus sur champ manuel)
  Widget _buildScannerPausedIndicator() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {
          // Retirer le focus du champ manuel pour réactiver le scanner
          _manualIsbnFocusNode.unfocus();
        },
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600.withValues(alpha: 0.95),
                Colors.orange.shade700.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pause_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scanner en pause',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cliquez ici pour réactiver le scanner automatique',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.touch_app,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Champ de saisie manuelle d'ISBN en bas du scanner
  Widget _buildManualIsbnInput() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre avec icône
                Row(
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saisie manuelle',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Champ de texte et bouton
                Row(
                  children: [
                    // Champ de texte stylisé
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A), // Fond gris foncé pour contraste
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: _manualIsbnController,
                          focusNode: _manualIsbnFocusNode,
                          keyboardType: TextInputType.text, // Changé de number à text pour accepter tirets et espaces
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Entrez l\'ISBN (ex: 9782123456789)',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                            prefixIcon: Icon(
                              Icons.numbers,
                              color: Colors.blue.withValues(alpha: 0.6),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            filled: false,
                          ),
                          onSubmitted: (_) => _handleManualIsbn(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Bouton Rechercher stylisé
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleManualIsbn,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Rechercher',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Note d'aide
                const SizedBox(height: 10),
                Text(
                  'Seuls les chiffres seront conservés (espaces et caractères spéciaux supprimés)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}