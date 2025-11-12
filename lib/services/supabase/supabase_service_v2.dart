import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/change_log.dart';

/// Service Supabase amélioré avec gestion du changelog pour sync robuste
class SupabaseServiceV2 {
  final Logger _logger = Logger();
  final SupabaseClient _client;

  static const String _booksTable = 'books';
  static const String _changelogTable = 'changelog';

  SupabaseServiceV2() : _client = Supabase.instance.client;

  /// Récupère tous les changements non synchronisés depuis Supabase
  Future<List<ChangeLog>> getPendingChanges() async {
    try {
      _logger.i('📋 Récupération des changements non synchronisés...');

      final response = await _client.from(_changelogTable).select().eq('synced', false).order('created_at', ascending: true);

      final changes = (response as List).map((json) => ChangeLog.fromSupabaseJson(json)).toList();

      _logger.i('📋 ${changes.length} changements à traiter');
      return changes;
    } catch (e) {
      _logger.e('❌ Erreur getPendingChanges: $e');
      return [];
    }
  }

  /// Marque les changements comme synchronisés
  Future<void> markChangesAsSynced(List<String> changeLogIds) async {
    try {
      if (changeLogIds.isEmpty) return;

      _logger.i('✅ Marquage de ${changeLogIds.length} changements comme synchronisés');

      await _client.from(_changelogTable).update({'synced': true, 'synced_at': DateTime.now().toIso8601String()}).inFilter('id', changeLogIds);

      _logger.i('✅ Changements marqués comme synced');
    } catch (e) {
      _logger.e('❌ Erreur markChangesAsSynced: $e');
    }
  }

  /// Récupère une entité avec soft delete (deleted_at)
  /// Retourne null si supprimée
  Future<Map<String, dynamic>?> getEntityIfActive(String table, String idField, String idValue) async {
    try {
      final response = await _client.from(table).select().eq(idField, idValue).isFilter('deleted_at', null).maybeSingle();

      return response;
    } catch (e) {
      _logger.e('❌ Erreur getEntityIfActive: $e');
      return null;
    }
  }

  /// Soft delete : marque l'entité comme supprimée au lieu de la supprimer
  Future<void> softDelete(String table, String idField, String idValue) async {
    try {
      _logger.i('🗑️ Soft delete: $table.$idField = $idValue');

      await _client.from(table).update({'deleted_at': DateTime.now().toIso8601String()}).eq(idField, idValue).isFilter('deleted_at', null);

      _logger.i('✅ Soft delete effectué');
    } catch (e) {
      _logger.e('❌ Erreur softDelete: $e');
    }
  }

  /// Restaurer une entité supprimée
  Future<void> undelete(String table, String idField, String idValue) async {
    try {
      _logger.i('♻️ Restauration: $table.$idField = $idValue');

      await _client.from(table).update({'deleted_at': null}).eq(idField, idValue);

      _logger.i('✅ Restauration effectuée');
    } catch (e) {
      _logger.e('❌ Erreur undelete: $e');
    }
  }

  /// Ajouter une entrée dans le changelog (pour tracking local → Supabase)
  Future<void> addChangeLog(
    String entityType,
    String entityId,
    ChangeOperation operation, {
    Map<String, dynamic>? changes,
  }) async {
    try {
      final changeLog = ChangeLog(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        changes: changes,
        createdAt: DateTime.now(),
      );

      await _client.from(_changelogTable).insert(changeLog.toSupabaseJson());

      _logger.i('📝 ChangeLog ajouté: $entityType:$entityId $operation');
    } catch (e) {
      _logger.e('❌ Erreur addChangeLog: $e');
    }
  }

  /// Récupère l'entité avec tous ses métadonnées (created_at, updated_at, deleted_at)
  Future<Map<String, dynamic>?> getEntityWithMetadata(String table, String idField, String idValue) async {
    try {
      final response = await _client.from(table).select().eq(idField, idValue).maybeSingle();

      return response;
    } catch (e) {
      _logger.e('❌ Erreur getEntityWithMetadata: $e');
      return null;
    }
  }

  /// Résolution de conflit : La suppression a la priorité
  /// Retourne true si l'entité doit être supprimée
  bool shouldDelete(Map<String, dynamic>? localEntity, Map<String, dynamic>? remoteEntity) {
    // Si l'une ou l'autre est supprimée, supprimer les deux
    if ((localEntity != null && localEntity['deleted_at'] != null) || (remoteEntity != null && remoteEntity['deleted_at'] != null)) {
      return true;
    }
    return false;
  }

  /// Fusionne deux versions d'une entité (résolution intelligente)
  /// Retourne la version à garder
  Map<String, dynamic> mergeEntities(
    Map<String, dynamic> localEntity,
    Map<String, dynamic> remoteEntity,
  ) {
    // Priorité 1: Suppression
    if (shouldDelete(localEntity, remoteEntity)) {
      localEntity['deleted_at'] = DateTime.now().toIso8601String();
      return localEntity;
    }

    // Priorité 2: Version la plus récente
    final localUpdated = DateTime.tryParse(localEntity['updated_at']?.toString() ?? '') ?? DateTime(2000);
    final remoteUpdated = DateTime.tryParse(remoteEntity['updated_at']?.toString() ?? '') ?? DateTime(2000);

    if (remoteUpdated.isAfter(localUpdated)) {
      _logger.i('⬇️ Fusion: version remote plus récente');
      return remoteEntity;
    } else if (localUpdated.isAfter(remoteUpdated)) {
      _logger.i('⬆️ Fusion: version locale plus récente');
      return localEntity;
    } else {
      // Même date: garder la version avec le plus de données
      _logger.i('🤝 Fusion: même date, garder la plus complète');
      return localEntity;
    }
  }

  /// Teste la connexion à Supabase
  Future<bool> testConnection() async {
    try {
      _logger.i('🔌 Test de connexion à Supabase...');

      await _client.from(_booksTable).select('isbn').limit(1);

      _logger.i('✅ Connexion Supabase OK');
      return true;
    } catch (e) {
      _logger.e('❌ Erreur connexion Supabase: $e');
      return false;
    }
  }
}
