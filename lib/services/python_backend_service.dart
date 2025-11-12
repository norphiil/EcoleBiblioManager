import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'log_service.dart';

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
  
  // Capture des erreurs de démarrage
  final List<String> _startupErrors = [];
  String? _lastError;
  
  // Service de logs
  final LogService _logService = LogService();

  /// Singleton
  static final PythonBackendService _instance = PythonBackendService._internal();
  factory PythonBackendService() => _instance;
  PythonBackendService._internal();

  /// État du serveur
  bool get isRunning => _isRunning;
  bool get isStarting => _isStarting;
  
  /// Erreurs de démarrage capturées
  String? get lastError => _lastError;
  List<String> get startupErrors => List.unmodifiable(_startupErrors);

  /// Démarre le serveur Python s'il n'est pas déjà en cours d'exécution
  Future<bool> startServer({Function(String)? onProgress}) async {
    await _logService.logOperation('Démarrage serveur Python');
    
    if (_isRunning || _isStarting) {
      debugPrint('[PythonBackend] 🔄 Serveur déjà en cours...');
      await _logService.log('Serveur déjà en cours d\'exécution', level: LogLevel.warning);
      return _isRunning;
    }
    
    _progressCallback = onProgress;
    _startupErrors.clear(); // Réinitialiser les erreurs
    _lastError = null;

    _isStarting = true;
    debugPrint('[PythonBackend] 🚀 Démarrage du serveur Python...');
    await _logService.log('Début du démarrage du serveur Python');

    try {
      // Vérifier d'abord si le serveur n'est pas déjà lancé
      await _logService.log('Vérification si serveur déjà actif...');
      if (await _checkServerHealth()) {
        debugPrint('[PythonBackend] ✅ Serveur déjà actif');
        await _logService.log('Serveur déjà actif sur http://127.0.0.1:8000');
        _isRunning = true;
        _isStarting = false;
        await _logService.logOperationEnd('Démarrage serveur Python', success: true);
        return true;
      }

      // Obtenir le chemin du backend
      await _logService.log('Recherche du dossier python_backend...');
      final backendPath = await _getBackendPath();
      if (backendPath == null) {
        await _logService.log('ERREUR: Dossier python_backend introuvable', level: LogLevel.error);
        throw Exception('Impossible de trouver le dossier python_backend');
      }
      await _logService.log('Dossier backend trouvé: $backendPath');

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

    } catch (e, stackTrace) {
      debugPrint('[PythonBackend] ❌ Erreur lors du démarrage: $e');
      await _logService.logError('Erreur critique lors du démarrage du serveur', e, stackTrace);
      _lastError = e.toString();
      _startupErrors.add('Erreur démarrage: $e');
      _isRunning = false;
      _isStarting = false;
      await _logService.logOperationEnd('Démarrage serveur Python', success: false);
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
    // Obtenir le chemin de l'exécutable (pour les builds compilés)
    final executablePath = Platform.resolvedExecutable;
    final executableDir = path.dirname(executablePath);
    
    await _logService.log('Exécutable: $executablePath');
    await _logService.log('Dossier exécutable: $executableDir');
    await _logService.log('Current directory: ${Directory.current.path}');
    
    // Essayer plusieurs chemins possibles
    final possiblePaths = [
      // Chemins relatifs à l'exécutable (pour builds compilés)
      path.join(executableDir, 'python_backend'),
      path.join(executableDir, '..', 'python_backend'),
      path.join(executableDir, '..', '..', 'python_backend'),
      path.join(executableDir, 'data', 'python_backend'),
      
      // Chemins relatifs au répertoire courant (pour développement)
      'python_backend',
      '../python_backend',
      '../../python_backend',
      path.join(Directory.current.path, 'python_backend'),
      path.join(Directory.current.parent.path, 'python_backend'),
    ];

    for (final possiblePath in possiblePaths) {
      await _logService.log('Tentative: $possiblePath');
      final dir = Directory(possiblePath);
      if (await dir.exists()) {
        final mainFile = File(path.join(possiblePath, 'main.py'));
        if (await mainFile.exists()) {
          final absolutePath = path.absolute(possiblePath);
          await _logService.log('✓ Backend trouvé: $absolutePath');
          return absolutePath;
        } else {
          await _logService.log('  Dossier existe mais main.py absent');
        }
      }
    }

    await _logService.log('❌ Aucun chemin valide trouvé', level: LogLevel.error);
    return null;
  }

  /// Vérifie si l'installation des dépendances est nécessaire
  Future<bool> _checkInstallationNeeded(String backendPath) async {
    try {
      // Si un exécutable autonome est disponible, aucune installation n'est nécessaire
      final exePath = await _getBundledExecutable(backendPath);
      if (exePath != null) {
        debugPrint('[PythonBackend] 🧰 Exécutable autonome détecté: ${path.basename(exePath)}');
        return false;
      }

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

  /// Recherche un exécutable packagé du backend (PyInstaller)
  Future<String?> _getBundledExecutable(String backendPath) async {
    final candidates = <String>[
      path.join(backendPath, 'dist', 'ebm_backend.exe'),
      path.join(backendPath, 'ebm_backend.exe'),
      path.join(backendPath, 'dist', 'backend.exe'),
      path.join(backendPath, 'backend.exe'),
    ];

    for (final exe in candidates) {
      if (await File(exe).exists()) {
        return exe;
      }
    }
    return null;
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
      // 1) Préférence: exécutable packagé si présent (pas besoin de Python système)
      final bundledExe = await _getBundledExecutable(backendPath);
      if (bundledExe != null) {
        debugPrint('[PythonBackend] 🧰 Démarrage de l\'exécutable packagé: ${path.basename(bundledExe)}');
        _serverProcess = await Process.start(
          bundledExe,
          const <String>[],
          workingDirectory: path.dirname(bundledExe),
          runInShell: true,
        );

        _serverProcess!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
          data.split('\n').where((line) => line.trim().isNotEmpty).forEach((line) {
            final cleanLine = _cleanLogLine(line);
            debugPrint('[PythonServer] $cleanLine');
            _logService.log('[Python exe stdout] $cleanLine');
          });
        });
        _serverProcess!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
          data.split('\n').where((line) => line.trim().isNotEmpty).forEach((line) {
            final cleanLine = _cleanLogLine(line);
            debugPrint('[PythonServer ERROR] $cleanLine');
            // Capturer les erreurs pour le DEBUG
            _startupErrors.add(cleanLine);
            _lastError = cleanLine;
            _logService.log('[Python exe stderr] $cleanLine', level: LogLevel.error);
          });
        });
        _serverProcess!.exitCode.then((exitCode) {
          if (exitCode != 0) {
            debugPrint('[PythonBackend] ❌ Processus exécutable terminé avec code: $exitCode');
          }
        });
        return;
      }

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
          // Logger dans le fichier
          _logService.log('[Python stdout] $cleanLine');
        });
      });
      
      _serverProcess!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        data.split('\n').where((line) => line.trim().isNotEmpty).forEach((line) {
          final cleanLine = _cleanLogLine(line);
          debugPrint('[PythonServer ERROR] $cleanLine');
          // Capturer les erreurs pour le DEBUG
          _startupErrors.add(cleanLine);
          _lastError = cleanLine;
          // Logger dans le fichier
          _logService.log('[Python stderr] $cleanLine', level: LogLevel.error);
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