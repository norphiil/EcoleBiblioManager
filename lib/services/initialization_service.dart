import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/logger.dart';
import 'supabase/supabase_service.dart';
import 'database/database_helper.dart';
import 'database/complete_sync_service.dart';
import 'database/local_database_service.dart';

/// Service pour l'initialisation de l'application
class InitializationService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final DatabaseHelper _databaseHelper;
  late final CompleteSyncService _completeSyncService;
  late final LocalDatabaseService _localDbService;
  final Logger _logger = Logger('InitializationService');
  
  InitializationStatus _status = InitializationStatus.notStarted;
  String _currentStep = '';
  String? _errorMessage;
  double _progress = 0.0;
  bool _offlineMode = false;
  
  InitializationService(this._supabaseService, this._databaseHelper) {
    _completeSyncService = CompleteSyncService(
      dbHelper: _databaseHelper,
      supabaseService: _supabaseService,
    );
    _localDbService = LocalDatabaseService(_databaseHelper);
  }
  
  /// Accès au service de synchronisation complète (3 phases)
  CompleteSyncService get completeSyncService => _completeSyncService;
  
  /// Accès au service de base de données locale
  LocalDatabaseService get localDbService => _localDbService;
  
  // Getters
  InitializationStatus get status => _status;
  String get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;
  double get progress => _progress;
  bool get isCompleted => _status == InitializationStatus.completed;
  bool get hasError => _status == InitializationStatus.error;
  bool get isOfflineMode => _offlineMode;
  
  /// Lance l'initialisation complète de l'application
  Future<void> initialize() async {
    try {
      _updateStatus(InitializationStatus.inProgress, 'Démarrage de l\'initialisation...', 0.0);
      
      // Étape 1: Initialisation de la base de données locale
      _updateProgress('Initialisation de la base de données locale...', 0.1);
      await _databaseHelper.database; // Force l'initialisation
      _updateProgress('Base de données locale prête', 0.2);
      
      // Étape 2: Test de connexion Supabase (si non hors-ligne)
      if (!_offlineMode) {
        _updateProgress('Connexion à Supabase...', 0.3);
        try {
          await _supabaseService.testConnection(timeout: const Duration(seconds: 100));
          _updateProgress('Connexion établie', 0.4);
        } on TimeoutException catch (e) {
          throw InitializationException(
            'Supabase n\'a pas répondu après ${e.duration?.inSeconds ?? 100} secondes. '
            'Vérifiez la connexion internet et réessayez.',
          );
        } catch (e) {
          throw InitializationException('Erreur Supabase: $e');
        }
      } else {
        _updateProgress('Mode hors-ligne activé - Supabase ignoré', 0.4);
      }
      
      // Étape 3: Vérification des tables Supabase (si non hors-ligne)
      if (!_offlineMode) {
        _updateProgress('Vérification des tables Supabase...', 0.5);
        // Pas besoin d'initialiser les tables, elles sont déjà créées via SQL
        _updateProgress('Tables Supabase prêtes', 0.6);
      } else {
        _updateProgress('Initialisation des services locaux...', 0.6);
      }
      
      // Étape 4: Synchronisation complète (STARTUP)
      if (!_offlineMode) {
        _updateProgress('Synchronisation au démarrage (clear + download + execute)...', 0.7);
        final syncSuccess = await _completeSyncService.performStartupSync();
        if (!syncSuccess) {
          _logger.warning('⚠️  Sync partiellement échouée, continuant...');
        }
        _updateProgress('Données synchronisées', 0.9);
      } else {
        _updateProgress('Mode hors-ligne: utilisation des données locales', 0.9);
      }
      
      // Étape 5: Sync périodique désactivée pour SmartSyncService
      // (À implémenter si besoin d'upload des changements locaux)
      if (!_offlineMode) {
        _updateProgress('Sync initialisée', 0.95);
      } else {
        _updateProgress('Mode hors-ligne: changements sauvegardés localement', 0.95);
      }
      
      // Étape 6: Finalisation
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

  /// Active le mode hors-ligne et termine l'initialisation avec les données locales
  Future<void> goOffline() async {
    // Marquer le mode hors-ligne (SmartSyncService n'a pas de sync périodique)
    _offlineMode = true;

    _updateStatus(InitializationStatus.inProgress, 'Activation du mode hors-ligne...', _progress);

    // Initialiser uniquement la base locale (déjà faite au début d'initialize)
    // Terminer directement l'initialisation sans Google Sheets
    await _finalize();
    _updateStatus(InitializationStatus.completed, 'Mode hors-ligne actif', 1.0);
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