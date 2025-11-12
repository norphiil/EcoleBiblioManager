import 'package:logger/logger.dart';
import '../../models/models.dart';
import 'database_helper.dart';
import 'tracked_database_service.dart';

/// Service de base de données locale - Interface principale pour les opérations CRUD
class LocalDatabaseService {
  final DatabaseHelper _dbHelper;
  late final TrackedDatabaseService _trackedDb;
  final Logger _logger = Logger();

  LocalDatabaseService(this._dbHelper) {
    _trackedDb = TrackedDatabaseService(_dbHelper);
  }

  // ==================== LIVRES ====================

  /// Récupère tous les livres (rapide - depuis SQLite)
  Future<List<Book>> getAllBooks() async {
    _logger.d('📖 Récupération de tous les livres depuis la BDD locale');
    final books = await _dbHelper.getAllBooks();
    _logger.d('📖 ${books.length} livres récupérés');
    return books;
  }

  /// Récupère un livre par ISBN (rapide - depuis SQLite)
  Future<Book?> getBookByIsbn(String isbn) async {
    _logger.d('📖 Recherche du livre ISBN: $isbn');
    final book = await _dbHelper.getBook(isbn);
    if (book != null) {
      _logger.d('✅ Livre trouvé: ${book.title}');
    } else {
      _logger.d('❌ Livre non trouvé');
    }
    return book;
  }

  /// Recherche des livres (rapide - depuis SQLite)
  Future<List<Book>> searchBooks(String field, String value) async {
    _logger.d('🔍 Recherche de livres: $field contient "$value"');
    final books = await _dbHelper.searchBooks(field, value);
    _logger.d('🔍 ${books.length} livres trouvés');
    return books;
  }

  /// Récupère les livres d'un groupe (rapide - depuis SQLite)
  Future<List<Book>> getBooksByGroup(String groupId) async {
    _logger.d('📚 Récupération des livres du groupe: $groupId');
    final books = await _dbHelper.getBooksByGroup(groupId);
    _logger.d('📚 ${books.length} livres dans le groupe');
    return books;
  }

  /// Ajoute un livre (rapide - dans SQLite, sync plus tard)
  Future<Book> addBook(Book book) async {
    _logger.i('➕ Ajout du livre: ${book.title}');
    await _trackedDb.insertBook(book);
    _logger.i('✅ Livre ajouté localement (sera synchronisé)');
    return book;
  }

  /// Met à jour un livre (rapide - dans SQLite, sync plus tard)
  Future<Book> updateBook(Book book) async {
    _logger.i('🔄 Mise à jour du livre: ${book.title}');
    await _trackedDb.updateBook(book);
    _logger.i('✅ Livre mis à jour localement (sera synchronisé)');
    return book;
  }

  /// Supprime un livre (rapide - dans SQLite, sync plus tard)
  Future<void> deleteBook(String isbn) async {
    _logger.i('🗑️  Suppression du livre ISBN: $isbn');
    await _trackedDb.deleteBook(isbn);
    _logger.i('✅ Livre supprimé localement (sera synchronisé)');
  }

  // ==================== GROUPES ====================

  /// Récupère tous les groupes (rapide - depuis SQLite)
  Future<List<BookGroup>> getAllBookGroups() async {
    _logger.d('📚 Récupération de tous les groupes depuis la BDD locale');
    final groups = await _dbHelper.getAllGroups();
    _logger.d('📚 ${groups.length} groupes récupérés');
    return groups;
  }

  /// Récupère un groupe par ID (rapide - depuis SQLite)
  Future<BookGroup?> getBookGroupById(String id) async {
    _logger.d('📚 Recherche du groupe ID: $id');
    final group = await _dbHelper.getGroup(id);
    if (group != null) {
      _logger.d('✅ Groupe trouvé: ${group.title}');
    } else {
      _logger.d('❌ Groupe non trouvé');
    }
    return group;
  }

  /// Ajoute un groupe (rapide - dans SQLite, sync plus tard)
  Future<BookGroup> addBookGroup(BookGroup group) async {
    _logger.i('➕ Ajout du groupe: ${group.title}');
    print('📊 Données du groupe addBookGroup:');
    print('  - ID: ${group.id}');
    print('  - svgData: ${group.svgData != null ? "${group.svgData!.length} chars" : "null"}');
    print('  - groupColor: ${group.groupColor}');
    await _trackedDb.insertGroup(group);
    _logger.i('✅ Groupe ajouté localement (sera synchronisé)');
    return group;
  }

  /// Met à jour un groupe (rapide - dans SQLite, sync plus tard)
  Future<BookGroup> updateBookGroup(BookGroup group) async {
    _logger.i('🔄 Mise à jour du groupe: ${group.title}');
    print('📊 Données du groupe updateBookGroup:');
    print('  - ID: ${group.id}');
    print('  - svgData: ${group.svgData != null ? "${group.svgData!.length} chars" : "null"}');
    print('  - groupColor: ${group.groupColor}');
    await _trackedDb.updateGroup(group);
    _logger.i('✅ Groupe mis à jour localement (sera synchronisé)');
    return group;
  }

  /// Supprime un groupe (rapide - dans SQLite, sync plus tard)
  Future<void> deleteBookGroup(String id) async {
    _logger.i('🗑️  Suppression du groupe ID: $id');
    
    // Vérifier s'il y a des livres dans ce groupe
    final books = await _dbHelper.getBooksByGroup(id);
    if (books.isNotEmpty) {
      _logger.w('⚠️  Le groupe contient ${books.length} livres. Les livres seront dissociés.');
      
      // Dissocier tous les livres du groupe
      for (final book in books) {
        final updatedBook = book.copyWith(groupId: null);
        await _trackedDb.updateBook(updatedBook);
      }
    }
    
    await _trackedDb.deleteGroup(id);
    _logger.i('✅ Groupe supprimé localement (sera synchronisé)');
  }

  // ==================== STATISTIQUES ====================

  /// Récupère le nombre total de livres
  Future<int> getTotalBooksCount() async {
    final books = await _dbHelper.getAllBooks();
    return books.length;
  }

  /// Récupère le nombre de livres disponibles
  Future<int> getAvailableBooksCount() async {
    final books = await _dbHelper.getAllBooks();
    return books.where((b) => b.status == BookStatus.available).length;
  }

  /// Récupère le nombre de livres empruntés
  Future<int> getBorrowedBooksCount() async {
    final books = await _dbHelper.getAllBooks();
    return books.where((b) => b.status == BookStatus.borrowed).length;
  }

  /// Récupère le nombre de groupes
  Future<int> getTotalGroupsCount() async {
    final groups = await _dbHelper.getAllGroups();
    return groups.length;
  }

  /// Récupère les statistiques par groupe
  Future<Map<String, int>> getBookCountByGroup() async {
    final books = await _dbHelper.getAllBooks();
    final Map<String, int> counts = {};
    
    for (final book in books) {
      if (book.groupId != null) {
        counts[book.groupId!] = (counts[book.groupId!] ?? 0) + 1;
      }
    }
    
    return counts;
  }

  // ==================== UTILITAIRES ====================

  /// Récupère le statut de synchronisation
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingBooks = await _dbHelper.getPendingBooks();
    final pendingGroups = await _dbHelper.getPendingGroups();
    final lastSync = await _dbHelper.getLastSyncTime();
    
    return {
      'pendingBooks': pendingBooks.length,
      'pendingGroups': pendingGroups.length,
      'lastSync': lastSync,
      'hasPendingChanges': pendingBooks.isNotEmpty || pendingGroups.isNotEmpty,
    };
  }

  /// Ferme la base de données
  Future<void> close() async {
    _logger.i('🔒 Fermeture de la base de données');
    await _dbHelper.close();
  }
}
