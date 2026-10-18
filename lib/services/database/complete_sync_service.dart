import 'dart:convert';
import 'package:logging/logging.dart';
import '../supabase/supabase_service.dart';
import 'database_helper.dart';
import '../../models/models.dart';

/// Service de synchronisation complète avec 3 phases:
/// 1. STARTUP: Clear local + Download all + Execute actions + Upload
/// 2. RUNTIME: Track changes in changelog_local
/// 3. SHUTDOWN: Execute remaining + Upload
class CompleteSyncService {
  final DatabaseHelper _dbHelper;
  final SupabaseService _supabaseService;
  final Logger _logger = Logger('CompleteSyncService');

  CompleteSyncService({
    required DatabaseHelper dbHelper,
    required SupabaseService supabaseService,
  })  : _dbHelper = dbHelper,
        _supabaseService = supabaseService;

  // ==========================================
  // PHASE 1: SYNCHRONISATION AU DÉMARRAGE
  // ==========================================

  /// Synchronisation complète au démarrage de l'app
  /// 1. Sauvegarder les actions hors ligne
  /// 2. Vider SQLite (sauf changelog)
  /// 3. Télécharger toutes les données depuis Supabase
  /// 4. Exécuter les actions stockées
  /// 5. Upload les changements vers Supabase
  Future<bool> performStartupSync() async {
    _logger.info('🚀 === SYNC AU DÉMARRAGE ===');
    
    try {
      // 1. Récupérer les actions hors ligne avant de vider
      final pendingActions = await _dbHelper.getPendingOfflineChanges();
      _logger.info('💾 ${pendingActions.length} actions hors ligne à conserver');

      // 2. Vider la base locale (sauf changelog)
      _logger.info('🧹 Vidage de la base locale...');
      await _dbHelper.clearAllDataExceptChangelog();

      // 3. Télécharger toutes les données depuis Supabase
      _logger.info('⬇️  Téléchargement depuis Supabase...');
      await _downloadAllFromSupabase();

      // 4. Exécuter les actions stockées
      if (pendingActions.isNotEmpty) {
        _logger.info('⚡ Exécution de ${pendingActions.length} actions stockées...');
        await _executeStoredActions(pendingActions);
      }

      // 5. Upload les changements vers Supabase
      _logger.info('⬆️  Upload des changements vers Supabase...');
      await _uploadChangesToSupabase();

      // 6. Nettoyer le changelog des actions synced
      await _dbHelper.cleanSyncedChangelog();

      _logger.info('✅ Synchronisation au démarrage terminée avec succès');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('❌ Erreur lors de la sync au démarrage', e, stackTrace);
      return false;
    }
  }

  /// Télécharge toutes les données depuis Supabase
  Future<void> _downloadAllFromSupabase() async {
    try {
      // 1. Classes
      final classes = await _supabaseService.getAllClasses();
      _logger.info('📥 ${classes.length} classes téléchargées');
      for (final classroom in classes) {
        await _dbHelper.addClass(classroom);
      }

      // 2. Étudiants
      final students = await _supabaseService.getAllStudents();
      _logger.info('📥 ${students.length} étudiants téléchargés');
      for (final student in students) {
        await _dbHelper.addStudent(student);
      }

      // 3. Groupes
      final groups = await _supabaseService.getAllGroups();
      _logger.info('📥 ${groups.length} groupes téléchargés');
      for (final group in groups) {
        await _dbHelper.insertGroup(group);
      }

      // 4. Livres
      final books = await _supabaseService.getAllBooks();
      _logger.info('📥 ${books.length} livres téléchargés');
      for (final book in books) {
        await _dbHelper.insertBook(book);
      }

      // 5. Historique d'emprunts
      final history = await _supabaseService.getAllBorrowHistory();
      _logger.info('📥 ${history.length} enregistrements d\'historique téléchargés');
      for (final record in history) {
        final db = await _dbHelper.database;
        await db.insert('borrow_history', {
          'id': record.id,
          'isbn': record.isbn,
          'bookTitle': record.bookTitle,
          'borrowerName': record.borrowerName,
          'classId': record.classId,
          'className': record.className,
          'borrowedAt': record.borrowedAt.toIso8601String(),
          'returnedAt': record.returnedAt?.toIso8601String(),
        });
      }

      _logger.info('✅ Téléchargement complet terminé');
    } catch (e, stackTrace) {
      _logger.severe('❌ Erreur lors du téléchargement', e, stackTrace);
      rethrow;
    }
  }

  /// Exécute les actions stockées dans changelog_local
  Future<void> _executeStoredActions(List<Map<String, dynamic>> actions) async {
    int executed = 0;
    int failed = 0;

    for (final action in actions) {
      try {
        final entityType = action['entity_type'] as String;
        final entityId = action['entity_id'] as String;
        final operation = action['operation'] as String;
        final dataStr = action['data'] as String?;
        final actionId = action['id'] as String;

        _logger.info('⚙️  Exécution: $operation $entityType $entityId');

        // Parser les données si présentes
        Map<String, dynamic>? data;
        if (dataStr != null && dataStr.isNotEmpty && dataStr != 'null') {
          data = _decodeChangeLogData(dataStr);
        }

        if (operation != 'delete' && (data == null || data.isEmpty)) {
          data = await _loadEntitySnapshot(entityType, entityId);
          if (data == null) {
            _logger.warning('⚠️  Aucune donnée disponible pour $operation $entityType $entityId, action ignorée');
            await _dbHelper.archiveChangeLog(actionId);
            continue;
          }
        }

        // Exécuter l'opération selon le type d'entité
        switch (entityType) {
          case 'book':
            await _executeBookAction(operation, entityId, data);
            break;
          case 'group':
            await _executeGroupAction(operation, entityId, data);
            break;
          case 'student':
            await _executeStudentAction(operation, entityId, data);
            break;
          case 'class':
            await _executeClassAction(operation, entityId, data);
            break;
          case 'borrow_history':
            await _executeBorrowHistoryAction(operation, entityId, data);
            break;
          default:
            _logger.warning('⚠️  Type d\'entité inconnu: $entityType');
        }

        // Marquer comme synchronisée
        await _dbHelper.markChangeLogAsSynced(actionId);
        executed++;
      } catch (e, stackTrace) {
        _logger.severe('❌ Erreur lors de l\'exécution de l\'action', e, stackTrace);
        failed++;
      }
    }

    _logger.info('✅ Actions exécutées: $executed | Échouées: $failed');
  }

  /// Exécute une action sur un livre
  Future<void> _executeBookAction(
    String operation,
    String entityId,
    Map<String, dynamic>? data,
  ) async {
    switch (operation) {
      case 'create':
        if (data != null) {
          final book = Book.fromSupabaseJson(data);
          await _dbHelper.insertBook(book);
          await _supabaseService.addBook(book);
        }
        break;
      case 'update':
        if (data != null) {
          final book = Book.fromSupabaseJson(data);
          await _dbHelper.updateBook(book);
          await _supabaseService.updateBook(book);
        }
        break;
      case 'delete':
        await _dbHelper.deleteBook(entityId);
        await _supabaseService.deleteBook(entityId);
        break;
    }
  }

  /// Exécute une action sur un groupe
  Future<void> _executeGroupAction(
    String operation,
    String entityId,
    Map<String, dynamic>? data,
  ) async {
    switch (operation) {
      case 'create':
        if (data != null) {
          final group = BookGroup.fromSupabaseJson(data);
          await _dbHelper.insertGroup(group);
          await _supabaseService.addGroup(group);
        }
        break;
      case 'update':
        if (data != null) {
          final group = BookGroup.fromSupabaseJson(data);
          await _dbHelper.updateGroup(group);
          await _supabaseService.updateGroup(group);
        }
        break;
      case 'delete':
        await _dbHelper.deleteGroup(entityId);
        await _supabaseService.deleteGroup(entityId);
        break;
    }
  }

  /// Exécute une action sur un étudiant
  Future<void> _executeStudentAction(
    String operation,
    String entityId,
    Map<String, dynamic>? data,
  ) async {
    switch (operation) {
      case 'create':
        if (data != null) {
          final student = Student.fromSupabaseJson(data);
          await _dbHelper.addStudent(student);
          await _supabaseService.addStudent(student);
        }
        break;
      case 'update':
        if (data != null) {
          final student = Student.fromSupabaseJson(data);
          await _dbHelper.updateStudent(student);
          await _supabaseService.updateStudent(student);
        }
        break;
      case 'delete':
        await _dbHelper.deleteStudent(entityId);
        await _supabaseService.deleteStudent(entityId);
        break;
    }
  }

  /// Exécute une action sur une classe
  Future<void> _executeClassAction(
    String operation,
    String entityId,
    Map<String, dynamic>? data,
  ) async {
    switch (operation) {
      case 'create':
        if (data != null) {
          final classroom = ClassRoom.fromSupabaseJson(data);
          await _dbHelper.addClass(classroom);
          await _supabaseService.addClass(classroom);
        }
        break;
      case 'update':
        if (data != null) {
          final classroom = ClassRoom.fromSupabaseJson(data);
          await _dbHelper.updateClass(classroom);
          await _supabaseService.updateClass(classroom);
        }
        break;
      case 'delete':
        await _dbHelper.deleteClass(entityId);
        await _supabaseService.deleteClass(entityId);
        break;
    }
  }

  /// Exécute une action sur l'historique d'emprunts
  Future<void> _executeBorrowHistoryAction(
    String operation,
    String entityId,
    Map<String, dynamic>? data,
  ) async {
    switch (operation) {
      case 'create':
        if (data != null) {
          final history = BorrowHistory.fromSupabaseJson(data);
          final db = await _dbHelper.database;
          await db.insert('borrow_history', {
            'id': history.id,
            'isbn': history.isbn,
            'bookTitle': history.bookTitle,
            'borrowerName': history.borrowerName,
            'classId': history.classId,
            'className': history.className,
            'borrowedAt': history.borrowedAt.toIso8601String(),
            'returnedAt': history.returnedAt?.toIso8601String(),
          });
          await _supabaseService.addBorrowHistory(history);
        }
        break;
      case 'update':
        if (data != null) {
          final history = BorrowHistory.fromSupabaseJson(data);
          await _dbHelper.updateBorrowHistory(history);
          await _supabaseService.updateBorrowHistory(history);
        }
        break;
      case 'delete':
        await _dbHelper.deleteBorrowHistory(entityId);
        // Note: Supabase n'a pas de méthode deleteBorrowHistory pour l'instant
        _logger.warning('⚠️  deleteBorrowHistory pas encore implémenté dans SupabaseService');
        break;
    }
  }

  /// Upload les changements vers Supabase
  Future<void> _uploadChangesToSupabase() async {
    // Cette méthode pourrait être améliorée pour détecter les changements locaux
    // et les uploader. Pour l'instant, les changements sont déjà uploadés
    // lors de l'exécution des actions stockées.
    _logger.info('✅ Changements uploadés');
  }

  // ==========================================
  // PHASE 3: SYNCHRONISATION À LA FERMETURE
  // ==========================================

  /// Synchronisation à la fermeture de l'app
  /// 1. Exécuter les actions restantes
  /// 2. Upload vers Supabase
  Future<bool> performShutdownSync() async {
    _logger.info('👋 === SYNC À LA FERMETURE ===');

    try {
      // 1. Récupérer les actions non synchronisées
      final pendingActions = await _dbHelper.getPendingOfflineChanges();
      
      if (pendingActions.isEmpty) {
        _logger.info('✅ Aucune action en attente');
        return true;
      }

      _logger.info('⚡ Exécution de ${pendingActions.length} actions restantes...');

      // 2. Exécuter les actions
      await _executeStoredActions(pendingActions);

      // 3. Upload vers Supabase (déjà fait dans executeStoredActions)
      _logger.info('⬆️  Upload terminé');

      // 4. Nettoyer le changelog
      await _dbHelper.cleanSyncedChangelog();

      _logger.info('✅ Synchronisation à la fermeture terminée');
      return true;
    } catch (e, stackTrace) {
      _logger.severe('❌ Erreur lors de la sync à la fermeture', e, stackTrace);
      return false;
    }
  }

  Map<String, dynamic>? _decodeChangeLogData(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      _logger.warning('⚠️  jsonDecode impossible: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadEntitySnapshot(String entityType, String entityId) async {
    switch (entityType) {
      case 'book':
        final book = await _dbHelper.getBook(entityId);
        return book?.toSupabaseJson();
      case 'group':
        final group = await _dbHelper.getGroup(entityId);
        return group?.toSupabaseJson();
      case 'student':
        final student = await _dbHelper.getStudentById(entityId);
        return student?.toSupabaseJson();
      case 'class':
        final classroom = await _dbHelper.getClassById(entityId);
        return classroom?.toSupabaseJson();
      case 'borrow_history':
        final history = await _dbHelper.getBorrowHistoryById(entityId);
        return history?.toSupabaseJson();
      default:
        return null;
    }
  }
}
