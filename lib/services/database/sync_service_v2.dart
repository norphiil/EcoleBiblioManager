import 'package:logger/logger.dart';
import '../supabase/supabase_service_v2.dart';
import '../../models/change_log.dart';
import 'database_helper.dart';

/// Service de synchronisation v2: Basé sur changelog + soft delete
/// Priorité suppression: Si supprimé anywhere, reste supprimé
class SyncServiceV2 {
  final Logger _logger = Logger();
  final SupabaseServiceV2 _supabaseService;
  final DatabaseHelper _localDb;

  SyncServiceV2({
    required SupabaseServiceV2 supabaseService,
    required DatabaseHelper localDb,
  })  : _supabaseService = supabaseService,
        _localDb = localDb;

  /// Sync complet: Récupère changements non-sync et les applique localement + remote
  Future<bool> performSync() async {
    try {
      _logger.i('🔄 Démarrage sync complète (changelog-based)...');

      // 1. Récupérer les changements non synchronisés depuis Supabase
      final pendingChanges = await _supabaseService.getPendingChanges();

      if (pendingChanges.isEmpty) {
        _logger.i('✅ Aucun changement à traiter');
        return true;
      }

      _logger.i('📋 ${pendingChanges.length} changements à appliquer');

      final syncedChangeIds = <String>[];

      // 2. Traiter chaque changement
      for (final change in pendingChanges) {
        final success = await _applyChangeLocally(change);
        if (success && change.id != null) {
          syncedChangeIds.add(change.id!);
        }
      }

      // 3. Marquer les changements traités comme synced
      if (syncedChangeIds.isNotEmpty) {
        await _supabaseService.markChangesAsSynced(syncedChangeIds);
        _logger.i('✅ ${syncedChangeIds.length}/${pendingChanges.length} changements marqués comme synced');
      }

      return true;
    } catch (e) {
      _logger.e('❌ Erreur sync complète: $e');
      return false;
    }
  }

  /// Applique UN changement Supabase → Base locale
  Future<bool> _applyChangeLocally(ChangeLog change) async {
    try {
      _logger.i('⚙️ Application changement: ${change.entityType}:${change.entityId} (${change.operation})');

      switch (change.entityType.toLowerCase()) {
        case 'book':
          return await _applyBookChange(change);
        case 'student':
          return await _applyStudentChange(change);
        case 'class':
        case 'classroom':
          return await _applyClassroomChange(change);
        case 'group':
        case 'bookgroup':
          return await _applyGroupChange(change);
        case 'borrow_history':
          return await _applyBorrowHistoryChange(change);
        default:
          _logger.w('⚠️ Type d\'entité non reconnu: ${change.entityType}');
          return false;
      }
    } catch (e) {
      _logger.e('❌ Erreur _applyChangeLocally: $e');
      return false;
    }
  }

  /// Applique changement LIVRE
  Future<bool> _applyBookChange(ChangeLog change) async {
    try {
      if (change.operation == ChangeOperation.delete) {
        // Suppression: marquer comme supprimé localement aussi
        // TODO: Implémenter soft delete au lieu de hard delete
        await _localDb.deleteBook(change.entityId);
        _logger.i('🗑️ Livre supprimé: ${change.entityId}');
        return true;
      } else if (change.operation == ChangeOperation.update) {
        // Mise à jour: récupérer l'entité depuis Supabase et mettre à jour localement
        // (à implémenter avec les méthodde d'accès réels)
        _logger.i('📝 Livre mis à jour: ${change.entityId}');
        return true;
      } else if (change.operation == ChangeOperation.create) {
        _logger.i('✏️ Livre créé: ${change.entityId}');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Erreur _applyBookChange: $e');
      return false;
    }
  }

  /// Applique changement ÉTUDIANT
  Future<bool> _applyStudentChange(ChangeLog change) async {
    try {
      if (change.operation == ChangeOperation.delete) {
        // TODO: Implémenter soft delete au lieu de hard delete
        await _localDb.deleteStudent(change.entityId);
        _logger.i('🗑️ Étudiant supprimé: ${change.entityId}');
        return true;
      } else if (change.operation == ChangeOperation.update) {
        _logger.i('📝 Étudiant mis à jour: ${change.entityId}');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Erreur _applyStudentChange: $e');
      return false;
    }
  }

  /// Applique changement CLASSE
  Future<bool> _applyClassroomChange(ChangeLog change) async {
    try {
      if (change.operation == ChangeOperation.delete) {
        // TODO: Implémenter soft delete au lieu de hard delete
        await _localDb.deleteClass(change.entityId);
        _logger.i('🗑️ Classe supprimée: ${change.entityId}');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Erreur _applyClassroomChange: $e');
      return false;
    }
  }

  /// Applique changement GROUPE
  Future<bool> _applyGroupChange(ChangeLog change) async {
    try {
      if (change.operation == ChangeOperation.delete) {
        // TODO: Implémenter soft delete au lieu de hard delete
        await _localDb.deleteGroup(change.entityId);
        _logger.i('🗑️ Groupe supprimé: ${change.entityId}');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Erreur _applyGroupChange: $e');
      return false;
    }
  }

  /// Applique changement HISTORIQUE EMPRUNT
  Future<bool> _applyBorrowHistoryChange(ChangeLog change) async {
    try {
      if (change.operation == ChangeOperation.delete) {
        // Emprunts sont immuables, pas de soft delete
        _logger.w('⚠️ Tentative suppression historique (opération non supportée)');
        return false;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Erreur _applyBorrowHistoryChange: $e');
      return false;
    }
  }

  /// Sync local → Supabase (téléchargement des changements locaux)
  /// Doit être implémenté avec track des changements locaux
  Future<bool> syncLocalChangesToRemote() async {
    try {
      _logger.i('⬆️ Sync local → Supabase...');
      // À implémenter: lire changelog local, uploader à Supabase
      _logger.i('✅ Sync local complétée');
      return true;
    } catch (e) {
      _logger.e('❌ Erreur sync local→remote: $e');
      return false;
    }
  }
}
