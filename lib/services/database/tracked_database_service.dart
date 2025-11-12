import 'package:logging/logging.dart';
import 'database_helper.dart';
import '../../models/models.dart';

/// Service qui wrappe DatabaseHelper et track automatiquement TOUTES les modifications
/// dans changelog_local pour la synchronisation offline
class TrackedDatabaseService {
  final DatabaseHelper _dbHelper;
  final Logger _logger = Logger('TrackedDatabaseService');

  TrackedDatabaseService(this._dbHelper);

  // ==========================================
  // LIVRES - Avec tracking automatique
  // ==========================================

  /// Insère un livre ET track l'action
  Future<void> insertBook(Book book) async {
    await _dbHelper.insertBook(book);
    await _trackAction(
      entityType: 'book',
      entityId: book.isbn,
      operation: 'create',
      data: book.toSupabaseJson(),
    );
    _logger.info('📚 Livre créé: ${book.title} (tracked)');
  }

  /// Met à jour un livre ET track l'action
  Future<void> updateBook(Book book) async {
    await _dbHelper.updateBook(book);
    await _trackAction(
      entityType: 'book',
      entityId: book.isbn,
      operation: 'update',
      data: book.toSupabaseJson(),
    );
    _logger.info('📚 Livre mis à jour: ${book.title} (tracked)');
  }

  /// Supprime un livre ET track l'action
  Future<void> deleteBook(String isbn) async {
    await _dbHelper.deleteBook(isbn);
    await _trackAction(
      entityType: 'book',
      entityId: isbn,
      operation: 'delete',
    );
    _logger.info('📚 Livre supprimé: $isbn (tracked)');
  }

  // READ operations (pas besoin de tracking)
  Future<List<Book>> getAllBooks() => _dbHelper.getAllBooks();
  Future<Book?> getBook(String isbn) => _dbHelper.getBook(isbn);
  Future<List<Book>> getBooksByGroup(String groupId) => _dbHelper.getBooksByGroup(groupId);
  Future<List<Book>> searchBooks(String field, String value) => _dbHelper.searchBooks(field, value);

  // ==========================================
  // GROUPES - Avec tracking automatique
  // ==========================================

  /// Insère un groupe ET track l'action
  Future<void> insertGroup(BookGroup group) async {
    await _dbHelper.insertGroup(group);
    await _trackAction(
      entityType: 'group',
      entityId: group.id,
      operation: 'create',
      data: group.toSupabaseJson(),
    );
    _logger.info('📁 Groupe créé: ${group.title} (tracked)');
  }

  /// Met à jour un groupe ET track l'action
  Future<void> updateGroup(BookGroup group) async {
    await _dbHelper.updateGroup(group);
    await _trackAction(
      entityType: 'group',
      entityId: group.id,
      operation: 'update',
      data: group.toSupabaseJson(),
    );
    _logger.info('📁 Groupe mis à jour: ${group.title} (tracked)');
  }

  /// Supprime un groupe ET track l'action
  Future<void> deleteGroup(String id) async {
    await _dbHelper.deleteGroup(id);
    await _trackAction(
      entityType: 'group',
      entityId: id,
      operation: 'delete',
    );
    _logger.info('📁 Groupe supprimé: $id (tracked)');
  }

  // READ operations
  Future<List<BookGroup>> getAllGroups() => _dbHelper.getAllGroups();
  Future<BookGroup?> getGroup(String id) => _dbHelper.getGroup(id);

  // ==========================================
  // ÉTUDIANTS - Avec tracking automatique
  // ==========================================

  /// Ajoute un étudiant ET track l'action
  Future<void> addStudent(Student student) async {
    await _dbHelper.addStudent(student);
    await _trackAction(
      entityType: 'student',
      entityId: student.id,
      operation: 'create',
      data: student.toSupabaseJson(),
    );
    _logger.info('👤 Étudiant créé: ${student.firstName} ${student.lastName} (tracked)');
  }

  /// Ajoute plusieurs étudiants ET track les actions
  Future<void> addStudents(List<Student> students) async {
    for (final student in students) {
      await addStudent(student); // Utilise addStudent qui track déjà
    }
  }

  /// Met à jour un étudiant ET track l'action
  Future<void> updateStudent(Student student) async {
    await _dbHelper.updateStudent(student);
    await _trackAction(
      entityType: 'student',
      entityId: student.id,
      operation: 'update',
      data: student.toSupabaseJson(),
    );
    _logger.info('👤 Étudiant mis à jour: ${student.firstName} ${student.lastName} (tracked)');
  }

  /// Supprime un étudiant ET track l'action
  Future<void> deleteStudent(String id) async {
    await _dbHelper.deleteStudent(id);
    await _trackAction(
      entityType: 'student',
      entityId: id,
      operation: 'delete',
    );
    _logger.info('👤 Étudiant supprimé: $id (tracked)');
  }

  /// Supprime tous les étudiants d'une classe ET track les actions
  Future<void> deleteStudentsByClass(String classId) async {
    // Récupérer les étudiants avant de les supprimer pour tracker chacun
    final students = await _dbHelper.getStudentsByClass(classId);
    
    for (final student in students) {
      await deleteStudent(student.id); // Utilise deleteStudent qui track déjà
    }
    
    _logger.info('👥 ${students.length} étudiants supprimés de la classe $classId (tracked)');
  }

  // READ operations
  Future<List<Student>> getAllStudents() => _dbHelper.getAllStudents();
  Future<List<Student>> getStudentsByClass(String classId) => _dbHelper.getStudentsByClass(classId);

  // ==========================================
  // CLASSES - Avec tracking automatique
  // ==========================================

  /// Ajoute une classe ET track l'action
  Future<void> addClass(ClassRoom classRoom) async {
    await _dbHelper.addClass(classRoom);
    await _trackAction(
      entityType: 'class',
      entityId: classRoom.id,
      operation: 'create',
      data: classRoom.toSupabaseJson(),
    );
    _logger.info('🏫 Classe créée: ${classRoom.name} (tracked)');
  }

  /// Met à jour une classe ET track l'action
  Future<void> updateClass(ClassRoom classRoom) async {
    await _dbHelper.updateClass(classRoom);
    await _trackAction(
      entityType: 'class',
      entityId: classRoom.id,
      operation: 'update',
      data: classRoom.toSupabaseJson(),
    );
    _logger.info('🏫 Classe mise à jour: ${classRoom.name} (tracked)');
  }

  /// Supprime une classe ET track l'action
  Future<void> deleteClass(String id) async {
    // D'abord supprimer les étudiants (avec tracking)
    await deleteStudentsByClass(id);
    
    // Puis supprimer la classe
    await _dbHelper.deleteClass(id);
    await _trackAction(
      entityType: 'class',
      entityId: id,
      operation: 'delete',
    );
    _logger.info('🏫 Classe supprimée: $id (tracked)');
  }

  // READ operations
  Future<List<ClassRoom>> getAllClasses() => _dbHelper.getAllClasses();

  // ==========================================
  // HISTORIQUE D'EMPRUNTS - Avec tracking automatique
  // ==========================================

  /// Insère un historique d'emprunt ET track l'action
  Future<void> insertBorrowHistory(BorrowHistory history) async {
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
    
    await _trackAction(
      entityType: 'borrow_history',
      entityId: history.id ?? '',
      operation: 'create',
      data: history.toSupabaseJson(),
    );
    _logger.info('📖 Emprunt créé: ${history.bookTitle} par ${history.borrowerName} (tracked)');
  }

  /// Met à jour un historique d'emprunt ET track l'action
  Future<void> updateBorrowHistory(BorrowHistory history) async {
    await _dbHelper.updateBorrowHistory(history);
    await _trackAction(
      entityType: 'borrow_history',
      entityId: history.id ?? '',
      operation: 'update',
      data: history.toSupabaseJson(),
    );
    _logger.info('📖 Emprunt mis à jour: ${history.bookTitle} (tracked)');
  }

  /// Supprime un historique d'emprunt ET track l'action
  Future<void> deleteBorrowHistory(String id) async {
    await _dbHelper.deleteBorrowHistory(id);
    await _trackAction(
      entityType: 'borrow_history',
      entityId: id,
      operation: 'delete',
    );
    _logger.info('📖 Emprunt supprimé: $id (tracked)');
  }

  /// Marque le dernier emprunt comme retourné ET track l'action
  Future<void> markLastBorrowAsReturned(String isbn) async {
    // Récupérer les emprunts non retournés pour ce livre
    final histories = await _dbHelper.getBorrowHistoryForBook(isbn);
    final activeHistory = histories.firstWhere(
      (h) => h.returnedAt == null,
      orElse: () => histories.first,
    );
    
    final updatedHistory = activeHistory.markAsReturned();
    await updateBorrowHistory(updatedHistory); // Utilise updateBorrowHistory qui track déjà
  }

  // READ operations
  Future<List<BorrowHistory>> getAllBorrowHistory() => _dbHelper.getAllBorrowHistory();
  Future<List<BorrowHistory>> getBorrowHistoryForBook(String isbn) => _dbHelper.getBorrowHistoryForBook(isbn);

  // ==========================================
  // MÉTHODE PRIVÉE DE TRACKING
  // ==========================================

  /// Track une action dans changelog_local
  Future<void> _trackAction({
    required String entityType,
    required String entityId,
    required String operation,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _dbHelper.addToChangeLog(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        data: data,
      );
      _logger.fine('✅ Action trackée: $operation $entityType $entityId');
    } catch (e, stackTrace) {
      _logger.severe('❌ Erreur tracking action', e, stackTrace);
      // Ne pas faire échouer l'opération principale si le tracking échoue
    }
  }

  // ==========================================
  // MÉTHODES UTILITAIRES (pass-through)
  // ==========================================

  Future<void> close() => _dbHelper.close();
}
