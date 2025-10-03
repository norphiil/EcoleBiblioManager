import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Service pour gérer le backend Python
/// Lance automatiquement le serveur FastAPI et gère la communication
class PythonBackendService {
  static const String _baseUrl = 'http://127.0.0.1:8000';
  static const Duration _startupTimeout = Duration(seconds: 60); // Plus de temps pour l'installation
  static const Duration _requestTimeout = Duration(seconds: 10);
  
  Process? _serverProcess;
  bool _isRunning = false;
  bool _isStarting = false;
  
  // Callback pour les mises à jour de progression
  Function(String)? _progressCallback;

  /// Singleton
  static final PythonBackendService _instance = PythonBackendService._internal();
  factory PythonBackendService() => _instance;
  PythonBackendService._internal();

  /// État du serveur
  bool get isRunning => _isRunning;
  bool get isStarting => _isStarting;

  /// Démarre le serveur Python s'il n'est pas déjà en cours d'exécution
  Future<bool> startServer({Function(String)? onProgress}) async {
    if (_isRunning || _isStarting) {
      debugPrint('[PythonBackend] 🔄 Serveur déjà en cours...');
      return _isRunning;
    }
    
    _progressCallback = onProgress;

    _isStarting = true;
    debugPrint('[PythonBackend] 🚀 Démarrage du serveur Python...');

    try {
      // Vérifier d'abord si le serveur n'est pas déjà lancé
      if (await _checkServerHealth()) {
        debugPrint('[PythonBackend] ✅ Serveur déjà actif');
        _isRunning = true;
        _isStarting = false;
        return true;
      }

      // Obtenir le chemin du backend
      final backendPath = await _getBackendPath();
      if (backendPath == null) {
        throw Exception('Impossible de trouver le dossier python_backend');
      }

      // Vérifier si l'environnement virtuel et les dépendances sont installés
      final needsInstallation = await _checkInstallationNeeded(backendPath);
      if (needsInstallation) {
        debugPrint('[PythonBackend] 📦 Installation des dépendances requise...');
        await _installDependencies(backendPath);
      } else {
        debugPrint('[PythonBackend] ✅ Environnement Python déjà configuré');
      }

      // Démarrer le serveur
      await _launchServer(backendPath);

      // Attendre que le serveur soit prêt
      final isReady = await _waitForServerReady();
      
      _isRunning = isReady;
      _isStarting = false;
      
      if (isReady) {
        debugPrint('[PythonBackend] ✅ Serveur démarré avec succès');
      } else {
        debugPrint('[PythonBackend] ❌ Timeout lors du démarrage');
      }
      
      return isReady;

    } catch (e) {
      debugPrint('[PythonBackend] ❌ Erreur lors du démarrage: $e');
      _isRunning = false;
      _isStarting = false;
      return false;
    }
  }

  /// Arrête le serveur Python
  Future<void> stopServer() async {
    debugPrint('[PythonBackend] 🛑 Arrêt du serveur...');
    
    if (_serverProcess != null) {
      _serverProcess!.kill();
      await _serverProcess!.exitCode;
      _serverProcess = null;
    }
    
    _isRunning = false;
    _isStarting = false;
    debugPrint('[PythonBackend] ✅ Serveur arrêté');
  }

  /// Détecte les codes-barres dans une image
  Future<Map<String, dynamic>?> detectBarcodes(String base64Image) async {
    if (!_isRunning) {
      debugPrint('[PythonBackend] ❌ Serveur non démarré');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/detect_base64'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'image': base64Image}),
      ).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final barcodesCount = result['barcodes_count'] ?? 0;
        debugPrint('[PythonBackend] ✅ Détection réussie - $barcodesCount codes détectés');
        return result;
      } else {
        debugPrint('[PythonBackend] ❌ Erreur HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PythonBackend] ❌ Erreur lors de la détection: $e');
      return null;
    }
  }

  /// Vérifie l'état du serveur
  Future<bool> _checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Trouve le chemin du dossier python_backend
  Future<String?> _getBackendPath() async {
    // Essayer plusieurs chemins possibles
    final possiblePaths = [
      'python_backend',
      '../python_backend',
      '../../python_backend',
      path.join(Directory.current.path, 'python_backend'),
      path.join(Directory.current.parent.path, 'python_backend'),
    ];

    for (final possiblePath in possiblePaths) {
      final dir = Directory(possiblePath);
      if (await dir.exists()) {
        final mainFile = File(path.join(possiblePath, 'main.py'));
        if (await mainFile.exists()) {
          return path.absolute(possiblePath);
        }
      }
    }

    return null;
  }

  /// Vérifie si l'installation des dépendances est nécessaire
  Future<bool> _checkInstallationNeeded(String backendPath) async {
    try {
      // Vérifier si le dossier venv existe
      final venvPath = path.join(backendPath, 'venv');
      if (!await Directory(venvPath).exists()) {
        debugPrint('[PythonBackend] 🔍 Environnement virtuel manquant');
        return true;
      }
      
      // Vérifier si l'exécutable Python existe dans le venv
      final pythonExe = path.join(venvPath, 'Scripts', 'python.exe');
      if (!await File(pythonExe).exists()) {
        debugPrint('[PythonBackend] 🔍 Exécutable Python venv manquant');
        return true;
      }
      
      // Vérifier si les principales dépendances sont installées
      final packages = ['fastapi', 'uvicorn', 'cv2', 'pyzbar'];
      var allInstalled = true;
      
      for (final package in packages) {
        final result = await Process.run(
          pythonExe,
          ['-c', 'import $package; print("$package: OK")'],
          workingDirectory: backendPath,
          runInShell: true,
        );
        
        if (result.exitCode != 0 || !result.stdout.toString().contains('OK')) {
          debugPrint('[PythonBackend] 🔍 Package manquant: $package');
          allInstalled = false;
        }
      }
      
      if (allInstalled) {
        debugPrint('[PythonBackend] 🔍 Toutes les dépendances sont installées');
        return false;
      } else {
        debugPrint('[PythonBackend] 🔍 Certaines dépendances manquent');
        return true;
      }
      
    } catch (e) {
      debugPrint('[PythonBackend] 🔍 Erreur vérification: $e - Installation requise');
      return true;
    }
  }

  /// Installe les dépendances Python de manière automatique
  Future<void> _installDependencies(String backendPath) async {
    _progressCallback?.call('Installation de l\'environnement Python...');
    debugPrint('[PythonBackend] 📦 Installation automatique des dépendances Python...');
    
    try {
      // Étape 1: Nettoyer l'ancien environnement si corrompu
      final venvPath = path.join(backendPath, 'venv');
      if (await Directory(venvPath).exists()) {
        debugPrint('[PythonBackend] 🧹 Nettoyage ancien environnement...');
        await Directory(venvPath).delete(recursive: true);
      }
      
      // Étape 2: Créer l'environnement virtuel
      _progressCallback?.call('Création de l\'environnement virtuel...');
      debugPrint('[PythonBackend] 🔧 Création de l\'environnement virtuel...');
      final venvResult = await Process.run(
        'python',
        ['-m', 'venv', 'venv', '--clear'],
        workingDirectory: backendPath,
        runInShell: true,
      );
      
      if (venvResult.exitCode != 0) {
        throw Exception('Erreur création venv: ${venvResult.stderr}');
      }
      
      // Étape 3: Déterminer le chemin de l'exécutable Python dans le venv
      final pythonExe = path.join(backendPath, 'venv', 'Scripts', 'python.exe');
      
      // Étape 4: Installer directement les packages sans mise à jour pip
      _progressCallback?.call('Installation des packages Python...');
      debugPrint('[PythonBackend] 📥 Installation des packages Python (sans mise à jour pip)...');
      final requirementsFile = path.join(backendPath, 'requirements.txt');
      
      if (!await File(requirementsFile).exists()) {
        throw Exception('Fichier requirements.txt introuvable');
      }
      
      // Tentative d'installation avec pip par défaut
      var installResult = await Process.run(
        pythonExe,
        ['-m', 'pip', 'install', '-r', 'requirements.txt', '--no-cache-dir'],
        workingDirectory: backendPath,
        runInShell: true,
      );
      
      // Si échec, essayer avec --user (fallback)
      if (installResult.exitCode != 0) {
        debugPrint('[PythonBackend] ⚠️ Première tentative échouée, essai avec --user...');
        installResult = await Process.run(
          pythonExe,
          ['-m', 'pip', 'install', '-r', 'requirements.txt', '--user', '--no-cache-dir'],
          workingDirectory: backendPath,
          runInShell: true,
        );
      }
      
      // Si échec persistant, installer les packages un par un
      if (installResult.exitCode != 0) {
        debugPrint('[PythonBackend] ⚠️ Installation groupée échouée, installation individuelle...');
        await _installPackagesIndividually(pythonExe, backendPath);
      }
      
      debugPrint('[PythonBackend] ✅ Installation terminée avec succès!');
      
    } catch (e) {
      debugPrint('[PythonBackend] ❌ Erreur installation: $e');
      rethrow;
    }
  }

  /// Installe les packages individuellement en cas d'échec groupé
  Future<void> _installPackagesIndividually(String pythonExe, String backendPath) async {
    final packages = [
      'fastapi==0.104.1',
      'uvicorn[standard]==0.24.0', 
      'opencv-python==4.8.1.78',
      'pyzbar==0.1.9',
      'Pillow==10.1.0',
      'numpy==1.24.3',
      'python-multipart==0.0.6'
    ];
    
    for (final package in packages) {
      _progressCallback?.call('Installation de $package...');
      debugPrint('[PythonBackend] 📦 Installation: $package');
      
      final result = await Process.run(
        pythonExe,
        ['-m', 'pip', 'install', package, '--no-cache-dir'],
        workingDirectory: backendPath,
        runInShell: true,
      );
      
      if (result.exitCode != 0) {
        debugPrint('[PythonBackend] ⚠️ Échec $package: ${result.stderr}');
        // Continuer avec les autres packages
      } else {
        debugPrint('[PythonBackend] ✅ $package installé');
      }
    }
  }



  /// Lance le serveur Python
  Future<void> _launchServer(String backendPath) async {
    _progressCallback?.call('Démarrage du serveur de détection...');
    debugPrint('[PythonBackend] 🚀 Lancement du serveur FastAPI...');
    
    try {
      // Utiliser directement l'exécutable Python du venv
      final pythonExe = path.join(backendPath, 'venv', 'Scripts', 'python.exe');
      
      // Utiliser toujours main.py (mode complet uniquement)
      final mainFile = path.join(backendPath, 'main.py');
      debugPrint('[PythonBackend] ✅ Utilisation du backend complet: main.py');
      
      // Vérifier que les fichiers existent
      if (!await File(pythonExe).exists()) {
        throw Exception('Exécutable Python venv non trouvé: $pythonExe');
      }
      
      if (!await File(mainFile).exists()) {
        throw Exception('Fichier main non trouvé: $mainFile');
      }
      
      debugPrint('[PythonBackend] 🔧 Démarrage: $pythonExe ${path.basename(mainFile)}');
      _progressCallback?.call('Démarrage du serveur de détection...');
      
      _serverProcess = await Process.start(
        pythonExe,
        [path.basename(mainFile)],
        workingDirectory: backendPath,
        runInShell: true,
        environment: {
          'PYTHONPATH': backendPath,
        },
      );
      
      // Écouter les logs du serveur avec meilleur formatting
      _serverProcess!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        data.split('\n').where((line) => line.trim().isNotEmpty).forEach((line) {
          // Nettoyer les caractères problématiques des logs
          final cleanLine = _cleanLogLine(line);
          debugPrint('[PythonServer] $cleanLine');
        });
      });
      
      _serverProcess!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        data.split('\n').where((line) => line.trim().isNotEmpty).forEach((line) {
          final cleanLine = _cleanLogLine(line);
          debugPrint('[PythonServer ERROR] $cleanLine');
        });
      });
      
      // Surveiller l'état du processus
      _serverProcess!.exitCode.then((exitCode) {
        if (exitCode != 0) {
          debugPrint('[PythonBackend] ❌ Processus terminé avec code de sortie: $exitCode');
        }
      });
      
    } catch (e) {
      debugPrint('[PythonBackend] ❌ Erreur lors du lancement: $e');
      rethrow;
    }
  }

  /// Attend que le serveur soit prêt
  Future<bool> _waitForServerReady() async {
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < _startupTimeout) {
      if (await _checkServerHealth()) {
        return true;
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return false;
  }



  /// Nettoie les caractères problématiques des logs Python
  String _cleanLogLine(String line) {
    // Nettoyer seulement les caractères vraiment problématiques
    // Garder les émojis simples pour les logs
    return line
        .replaceAll('\u0000', '') // Caractères null
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ''); // Caractères de contrôle
  }

  /// Nettoie les ressources
  void dispose() {
    stopServer();
  }
}