import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/utils/logger.dart';
import 'google_sheets/google_sheets_service.dart';

/// Service pour l'initialisation de l'application
class InitializationService extends ChangeNotifier {
  final GoogleSheetsService _googleSheetsService;
  final Logger _logger = Logger('InitializationService');
  
  InitializationStatus _status = InitializationStatus.notStarted;
  String _currentStep = '';
  String? _errorMessage;
  double _progress = 0.0;
  
  InitializationService(this._googleSheetsService);
  
  // Getters
  InitializationStatus get status => _status;
  String get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  bool get isCompleted => _status == InitializationStatus.completed;
  bool get hasError => _status == InitializationStatus.error;
  
  /// Lance l'initialisation complète de l'application
  Future<void> initialize() async {
    try {
      _updateStatus(InitializationStatus.inProgress, 'Démarrage de l\'initialisation...', 0.0);
      
      // Étape 1: Initialisation du service Google Sheets
      _updateProgress('Connexion à Google Sheets...', 0.3);
      await _googleSheetsService.initialize();
      _updateProgress('Connexion établie', 0.5);
      
      // Étape 2: Création des feuilles si nécessaire
      _updateProgress('Initialisation des feuilles...', 0.7);
      await _googleSheetsService.initializeSheets();
      _updateProgress('Feuilles initialisées', 0.9);
      
      // Étape 3: Finalisation
      await _finalize();
      _updateProgress('Initialisation terminée', 1.0);
      
      _updateStatus(InitializationStatus.completed, 'Application prête à utiliser', 1.0);
      _logger.info('Initialisation terminée avec succès');
      
    } catch (e) {
      _logger.error('Erreur lors de l\'initialisation', e);
      _updateStatus(InitializationStatus.error, 'Erreur d\'initialisation', _progress, e.toString());
    }
  }
  
  /// Finalise l'initialisation
  Future<void> _finalize() async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Ici on peut ajouter d'autres tâches de finalisation
    // Par exemple : migration de données, nettoyage de cache, etc.
    
    _logger.info('Initialisation finalisée');
  }
  
  /// Met à jour le statut et notifie les listeners
  void _updateStatus(InitializationStatus status, String step, double progress, [String? error]) {
    _status = status;
    _currentStep = step;
    _progress = progress;
    _errorMessage = error;
    notifyListeners();
  }
  
  /// Met à jour uniquement le progrès et l'étape courante
  void _updateProgress(String step, double progress) {
    _currentStep = step;
    _progress = progress;
    notifyListeners();
  }
  
  /// Relance l'initialisation en cas d'erreur
  Future<void> retry() async {
    if (_status == InitializationStatus.error) {
      _errorMessage = null;
      await initialize();
    }
  }
}

/// États possibles de l'initialisation
enum InitializationStatus {
  notStarted,
  inProgress,
  completed,
  error,
}

/// Exception spécifique à l'initialisation
class InitializationException implements Exception {
  final String message;
  
  InitializationException(this.message);
  
  @override
  String toString() => 'InitializationException: $message';
}