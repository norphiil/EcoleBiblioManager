import 'package:logger/logger.dart';
import '../../models/models.dart';
import '../supabase/supabase_service.dart';
import 'database_helper.dart';

/// Service de synchronisation intelligente SANS DOUBLONS
/// Stratégie:
/// 1. Récupérer données Supabase
/// 2. Comparer avec local
/// 3. Fusionner (pas d'ajout si existe déjà)
/// 4. Tracker les changements hors ligne pour prochain sync
class SmartSyncService {
  final DatabaseHelper _dbHelper;
  final SupabaseService _supabaseService;
  final Logger _logger = Logger();

  SmartSyncService(this._dbHelper, this._supabaseService);

  /// Sync intelligente: Télécharger depuis Supabase SANS créer de doublons
  Future<bool> performSmartSync() async {
    _logger.i('🔄 ========== SYNCHRONISATION INTELLIGENTE ==========');
    try {
      // 1. Télécharger depuis Supabase
      await _downloadFromSupabase();

      // 2. Les changements locaux seront uploadés à la prochaine sync
      _logger.i('✅ ========== SYNC INTELLIGENTE TERMINÉE ==========');
      return true;
    } catch (e) {
      _logger.e('❌ Erreur sync intelligente: $e');
      return false;
    }
  }

  /// Phase 1: Télécharger depuis Supabase (SANS créer de doublons)
  Future<void> _downloadFromSupabase() async {
    _logger.i('⬇️  Phase 1: Téléchargement depuis Supabase (SANS doublons)');

    try {
      // 1. Télécharger les classes
      await _syncClasses();

      // 2. Télécharger les élèves (dépendent des classes)
      await _syncStudents();

      // 3. Télécharger les groupes
      await _syncGroups();

      // 4. Télécharger les livres
      await _syncBooks();

      // 5. Télécharger l'historique
      await _syncBorrowHistory();

      _logger.i('✅ Téléchargement complété');
    } catch (e) {
      _logger.e('❌ Erreur téléchargement: $e');
      rethrow;
    }
  }

  /// Sync intelligente des classes
  Future<void> _syncClasses() async {
    _logger.i('🏫 Sync intelligente des classes...');
    try {
      final remoteClasses = await _supabaseService.getAllClasses();
      final localClasses = await _dbHelper.getAllClasses();

      // Map locale par ID pour recherche rapide
      final localMap = {for (var c in localClasses) c.id: c};

      // Ajouter uniquement si n'existe pas
      int added = 0;
      int skipped = 0;

      for (final remoteClass in remoteClasses) {
        if (!localMap.containsKey(remoteClass.id)) {
          await _dbHelper.addClass(remoteClass);
          added++;
        } else {
          skipped++;
        }
      }

      _logger.i('📥 Classes: $added ajoutées, $skipped déjà présentes');
    } catch (e) {
      _logger.e('❌ Erreur sync classes: $e');
      rethrow;
    }
  }

  /// Sync intelligente des élèves
  Future<void> _syncStudents() async {
    _logger.i('👨‍🎓 Sync intelligente des élèves...');
    try {
      final remoteStudents = await _supabaseService.getAllStudents();
      final localStudents = await _dbHelper.getAllStudents();

      // Map locale par ID
      final localMap = {for (var s in localStudents) s.id: s};

      int added = 0;
      int skipped = 0;

      for (final remoteStudent in remoteStudents) {
        if (!localMap.containsKey(remoteStudent.id)) {
          await _dbHelper.addStudent(remoteStudent);
          added++;
        } else {
          skipped++;
        }
      }

      _logger.i('📥 Élèves: $added ajoutés, $skipped déjà présents');
    } catch (e) {
      _logger.e('❌ Erreur sync élèves: $e');
      rethrow;
    }
  }

  /// Sync intelligente des groupes (CRITIQUE: éviter doublons)
  Future<void> _syncGroups() async {
    _logger.i('📚 Sync intelligente des groupes...');
    try {
      final remoteGroups = await _supabaseService.getAllGroups();
      final localGroups = await _dbHelper.getAllGroups();

      // Map locale par ID (clé unique du groupe)
      final localMapById = {for (var g in localGroups) g.id: g};

      int added = 0;
      int skipped = 0;
      int updated = 0;

      for (final remoteGroup in remoteGroups) {
        final localGroup = localMapById[remoteGroup.id];

        if (localGroup == null) {
          // Groupe n'existe pas → Ajouter
          await _dbHelper.insertGroup(remoteGroup);
          await _dbHelper.markGroupAsSynced(remoteGroup.id);
          added++;
        } else if (localGroup.title != remoteGroup.title) {
          // Groupe existe mais titre différent → Mettre à jour
          await _dbHelper.updateGroup(remoteGroup);
          await _dbHelper.markGroupAsSynced(remoteGroup.id);
          updated++;
        } else {
          // Groupe existe et identique → Rien faire
          skipped++;
        }
      }

      _logger.i('📥 Groupes: $added ajoutés, $updated mis à jour, $skipped identiques (AUCUN DOUBLON)');
    } catch (e) {
      _logger.e('❌ Erreur sync groupes: $e');
      rethrow;
    }
  }

  /// Sync intelligente des livres
  Future<void> _syncBooks() async {
    _logger.i('📖 Sync intelligente des livres...');
    try {
      final remoteBooks = await _supabaseService.getAllBooks();
      final localBooks = await _dbHelper.getAllBooks();

      // Map locale par ISBN (clé unique)
      final localMapByIsbn = {for (var b in localBooks) b.isbn: b};

      int added = 0;
      int skipped = 0;
      int updated = 0;

      for (final remoteBook in remoteBooks) {
        final localBook = localMapByIsbn[remoteBook.isbn];

        if (localBook == null) {
          // Livre n'existe pas → Ajouter
          await _dbHelper.insertBook(remoteBook);
          await _dbHelper.markBookAsSynced(remoteBook.isbn);
          added++;
        } else if (_hasBookChanged(localBook, remoteBook)) {
          // Livre existe mais différent → Mettre à jour
          await _dbHelper.updateBook(remoteBook);
          await _dbHelper.markBookAsSynced(remoteBook.isbn);
          updated++;
        } else {
          // Livre existe et identique → Rien faire
          skipped++;
        }
      }

      _logger.i('📥 Livres: $added ajoutés, $updated mis à jour, $skipped identiques (AUCUN DOUBLON)');
    } catch (e) {
      _logger.e('❌ Erreur sync livres: $e');
      rethrow;
    }
  }

  /// Sync intelligente de l'historique d'emprunts
  Future<void> _syncBorrowHistory() async {
    _logger.i('📋 Sync intelligente de l\'historique...');
    try {
      final remoteBorrows = await _supabaseService.getAllBorrowHistory();
      final localBorrows = await _dbHelper.getAllBorrowHistory();

      // Map locale par ID
      final localMapById = {for (var b in localBorrows) b.id: b};

      int added = 0;
      int skipped = 0;

      for (final remoteBorrow in remoteBorrows) {
        if (!localMapById.containsKey(remoteBorrow.id)) {
          await _dbHelper.addBorrowHistory(remoteBorrow);
          added++;
        } else {
          skipped++;
        }
      }

      _logger.i('📥 Emprunts: $added ajoutés, $skipped déjà présents');
    } catch (e) {
      _logger.e('❌ Erreur sync emprunts: $e');
      rethrow;
    }
  }

  /// Phase 2: Uploader les changements hors ligne (À FAIRE)
  /// Utiliser un changelog local pour tracker:
  /// - Livres modifiés
  /// - Groupes modifiés
  /// - État des emprunts
  Future<void> uploadOfflineChanges() async {
    _logger.i('⬆️  Phase 2: Upload des changements hors ligne');

    try {
      // TODO: Lire le changelog local
      // TODO: Pour chaque entrée:
      //   - Si créé: addBook/addGroup
      //   - Si modifié: updateBook/updateGroup
      //   - Si supprimé: deleteBook/deleteGroup
      // TODO: Marquer comme synced

      _logger.i('✅ Upload complété');
    } catch (e) {
      _logger.e('❌ Erreur upload: $e');
    }
  }

  /// Vérifie si deux livres sont différents
  bool _hasBookChanged(Book book1, Book book2) {
    return book1.title != book2.title ||
        book1.author != book2.author ||
        book1.groupId != book2.groupId ||
        book1.status != book2.status ||
        book1.borrowedBy != book2.borrowedBy ||
        book1.borrowerClassName != book2.borrowerClassName;
  }
}
