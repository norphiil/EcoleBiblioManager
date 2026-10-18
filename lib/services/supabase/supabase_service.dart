import 'dart:async';

import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

/// Service de gestion de Supabase (remplace GoogleSheetsService)
/// Gère la synchronisation avec la base de données PostgreSQL en ligne
class SupabaseService {
  final Logger _logger = Logger();
  final SupabaseClient _client;
  
  // Noms des tables Supabase (correspondent aux anciennes Google Sheets)
  static const String _booksTable = 'books';
  static const String _groupsTable = 'groups';
  static const String _classesTable = 'classes';
  static const String _studentsTable = 'students';
  static const String _borrowHistoryTable = 'borrow_history';
  
  SupabaseService() : _client = Supabase.instance.client;
  
  /// Teste la connexion à Supabase et lève une erreur détaillée en cas d'échec
  Future<void> testConnection({Duration timeout = const Duration(seconds: 30)}) async {
    final stopwatch = Stopwatch()..start();
    final timeoutLabel = timeout.inSeconds;
    try {
      _logger.i('🔌 Test de connexion à Supabase (timeout ${timeoutLabel}s)...');
      await _client
          .from(_booksTable)
          .select('isbn')
          .limit(1)
          .timeout(timeout);

      stopwatch.stop();
      _logger.i('✅ Connexion Supabase OK (${stopwatch.elapsedMilliseconds} ms)');
    } on TimeoutException catch (e) {
      stopwatch.stop();
      final message = '⏱️ Timeout connexion Supabase après ${timeoutLabel}s';
      _logger.e(message, error: e, stackTrace: StackTrace.current);
      throw TimeoutException(message, e.duration ?? timeout);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.e('❌ Erreur connexion Supabase', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  // ========== BOOKS ==========
  
  /// Récupère tous les livres
  Future<List<Book>> getAllBooks() async {
    try {
      _logger.i('📚 Récupération de tous les livres...');
      
      final response = await _client
          .from(_booksTable)
          .select()
          .order('title');
      
      final books = (response as List)
          .map((json) => Book.fromSupabaseJson(json))
          .toList();
      
      _logger.i('✅ ${books.length} livres récupérés');
      return books;
    } catch (e) {
      _logger.e('❌ Erreur getAllBooks: $e');
      rethrow;
    }
  }
  
  /// Récupère un livre par ISBN
  Future<Book?> getBookByIsbn(String isbn) async {
    try {
      final response = await _client
          .from(_booksTable)
          .select()
          .eq('isbn', isbn)
          .maybeSingle();
      
      if (response == null) return null;
      return Book.fromSupabaseJson(response);
    } catch (e) {
      _logger.e('❌ Erreur getBookByIsbn: $e');
      return null;
    }
  }
  
  /// Recherche des livres par ISBN (pour FullSyncService)
  Future<List<Book>> searchBooks(String field, String value) async {
    try {
      if (field == 'isbn') {
        final book = await getBookByIsbn(value);
        return book != null ? [book] : [];
      }
      return [];
    } catch (e) {
      _logger.e('❌ Erreur searchBooks: $e');
      return [];
    }
  }
  
  /// Ajoute un livre
  Future<void> addBook(Book book) async {
    try {
      _logger.i('➕ Ajout du livre: ${book.title}');
      
      await _client
          .from(_booksTable)
          .insert(book.toSupabaseJson());
      
      _logger.i('✅ Livre ajouté');
    } catch (e) {
      _logger.e('❌ Erreur addBook: $e');
      rethrow;
    }
  }
  
  /// Met à jour un livre
  Future<void> updateBook(Book book) async {
    try {
      _logger.i('🔄 Mise à jour du livre: ${book.title}');
      
      await _client
          .from(_booksTable)
          .update(book.toSupabaseJson())
          .eq('isbn', book.isbn);
      
      _logger.i('✅ Livre mis à jour');
    } catch (e) {
      _logger.e('❌ Erreur updateBook: $e');
      rethrow;
    }
  }
  
  /// Supprime un livre
  Future<void> deleteBook(String isbn) async {
    try {
      _logger.i('🗑️ Suppression du livre ISBN: $isbn');
      
      await _client
          .from(_booksTable)
          .delete()
          .eq('isbn', isbn);
      
      _logger.i('✅ Livre supprimé');
    } catch (e) {
      _logger.e('❌ Erreur deleteBook: $e');
      rethrow;
    }
  }
  
  // ========== GROUPS ==========
  
  /// Récupère tous les groupes
  Future<List<BookGroup>> getAllGroups() async {
    try {
      _logger.i('📚 Récupération de tous les groupes...');
      
      final response = await _client
          .from(_groupsTable)
          .select()
          .order('title');
      
      final groups = (response as List)
          .map((json) => BookGroup.fromSupabaseJson(json))
          .toList();
      
      _logger.i('✅ ${groups.length} groupes récupérés');
      return groups;
    } catch (e) {
      _logger.e('❌ Erreur getAllGroups: $e');
      rethrow;
    }
  }
  
  /// Ajoute un groupe
  Future<void> addGroup(BookGroup group) async {
    try {
      _logger.i('➕ Ajout du groupe: ${group.title}');
      
      await _client
          .from(_groupsTable)
          .insert(group.toSupabaseJson());
      
      _logger.i('✅ Groupe ajouté');
    } catch (e) {
      _logger.e('❌ Erreur addGroup: $e');
      rethrow;
    }
  }
  
  /// Met à jour un groupe
  Future<void> updateGroup(BookGroup group) async {
    try {
      _logger.i('🔄 Mise à jour du groupe: ${group.title}');
      
      await _client
          .from(_groupsTable)
          .update(group.toSupabaseJson())
          .eq('key', group.key);
      
      _logger.i('✅ Groupe mis à jour');
    } catch (e) {
      _logger.e('❌ Erreur updateGroup: $e');
      rethrow;
    }
  }
  
  /// Supprime un groupe
  Future<void> deleteGroup(String key) async {
    try {
      _logger.i('🗑️ Suppression du groupe: $key');
      
      await _client
          .from(_groupsTable)
          .delete()
          .eq('key', key);
      
      _logger.i('✅ Groupe supprimé');
    } catch (e) {
      _logger.e('❌ Erreur deleteGroup: $e');
      rethrow;
    }
  }
  
  /// Recherche des groupes (pour FullSyncService)
  Future<List<BookGroup>> searchBookGroups(String field, String value) async {
    try {
      final response = await _client
          .from(_groupsTable)
          .select()
          .eq(field, value)
          .limit(1);
      
      return (response as List)
          .map((json) => BookGroup.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      _logger.e('❌ Erreur searchBookGroups: $e');
      return [];
    }
  }
  
  // ========== CLASSES ==========
  
  /// Récupère toutes les classes
  Future<List<ClassRoom>> getAllClasses() async {
    try {
      _logger.i('🏫 Récupération de toutes les classes...');
      
      final response = await _client
          .from(_classesTable)
          .select()
          .order('name');
      
      final classes = (response as List)
          .map((json) => ClassRoom.fromSupabaseJson(json))
          .toList();
      
      _logger.i('✅ ${classes.length} classes récupérées');
      return classes;
    } catch (e) {
      _logger.e('❌ Erreur getAllClasses: $e');
      rethrow;
    }
  }
  
  /// Ajoute une classe
  Future<void> addClass(ClassRoom classRoom) async {
    try {
      _logger.i('➕ Ajout de la classe: ${classRoom.name}');
      
      await _client
          .from(_classesTable)
          .insert(classRoom.toSupabaseJson());
      
      _logger.i('✅ Classe ajoutée');
    } catch (e) {
      _logger.e('❌ Erreur addClass: $e');
      rethrow;
    }
  }
  
  /// Met à jour une classe
  Future<void> updateClass(ClassRoom classRoom) async {
    try {
      _logger.i('🔄 Mise à jour de la classe: ${classRoom.name}');
      
      await _client
          .from(_classesTable)
          .update(classRoom.toSupabaseJson())
          .eq('id', classRoom.id);
      
      _logger.i('✅ Classe mise à jour');
    } catch (e) {
      _logger.e('❌ Erreur updateClass: $e');
      rethrow;
    }
  }
  
  /// Supprime une classe
  Future<void> deleteClass(String id) async {
    try {
      _logger.i('🗑️ Suppression de la classe ID: $id');
      
      await _client
          .from(_classesTable)
          .delete()
          .eq('id', id);
      
      _logger.i('✅ Classe supprimée');
    } catch (e) {
      _logger.e('❌ Erreur deleteClass: $e');
      rethrow;
    }
  }
  
  /// Recherche des classes (pour FullSyncService)
  Future<List<ClassRoom>> searchClasses(String field, String value) async {
    try {
      final response = await _client
          .from(_classesTable)
          .select()
          .eq(field, value)
          .limit(1);
      
      return (response as List)
          .map((json) => ClassRoom.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      _logger.e('❌ Erreur searchClasses: $e');
      return [];
    }
  }
  
  // ========== STUDENTS ==========
  
  /// Récupère tous les élèves
  Future<List<Student>> getAllStudents() async {
    try {
      _logger.i('👨‍🎓 Récupération de tous les élèves...');
      
      final response = await _client
          .from(_studentsTable)
          .select()
          .order('first_name');
      
      final students = (response as List)
          .map((json) => Student.fromSupabaseJson(json))
          .toList();
      
      _logger.i('✅ ${students.length} élèves récupérés');
      return students;
    } catch (e) {
      _logger.e('❌ Erreur getAllStudents: $e');
      rethrow;
    }
  }
  
  /// Recherche des élèves par prénom/nom
  Future<List<Student>> searchStudents(String queryOrField, [String? value]) async {
    try {
      // Si 2 paramètres: recherche par field exact (pour FullSyncService)
      if (value != null) {
        final response = await _client
            .from(_studentsTable)
            .select()
            .eq(queryOrField, value)
            .limit(1);
        
        return (response as List)
            .map((json) => Student.fromSupabaseJson(json))
            .toList();
      }
      
      // Si 1 paramètre: recherche texte libre (pour autocomplete)
      final response = await _client
          .from(_studentsTable)
          .select()
          .or('first_name.ilike.%$queryOrField%,last_name.ilike.%$queryOrField%')
          .order('first_name');
      
      return (response as List)
          .map((json) => Student.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      _logger.e('❌ Erreur searchStudents: $e');
      return [];
    }
  }
  
  /// Ajoute un élève
  Future<void> addStudent(Student student) async {
    try {
      _logger.i('➕ Ajout de l\'élève: ${student.fullName}');
      
      await _client
          .from(_studentsTable)
          .insert(student.toSupabaseJson());
      
      _logger.i('✅ Élève ajouté');
    } catch (e) {
      _logger.e('❌ Erreur addStudent: $e');
      rethrow;
    }
  }
  
  /// Met à jour un élève
  Future<void> updateStudent(Student student) async {
    try {
      _logger.i('🔄 Mise à jour de l\'élève: ${student.fullName}');
      
      await _client
          .from(_studentsTable)
          .update(student.toSupabaseJson())
          .eq('id', student.id);
      
      _logger.i('✅ Élève mis à jour');
    } catch (e) {
      _logger.e('❌ Erreur updateStudent: $e');
      rethrow;
    }
  }
  
  /// Supprime un élève
  Future<void> deleteStudent(String id) async {
    try {
      _logger.i('🗑️ Suppression de l\'élève ID: $id');
      
      await _client
          .from(_studentsTable)
          .delete()
          .eq('id', id);
      
      _logger.i('✅ Élève supprimé');
    } catch (e) {
      _logger.e('❌ Erreur deleteStudent: $e');
      rethrow;
    }
  }
  
  // ========== BORROW HISTORY ==========
  
  /// Récupère tout l'historique
  Future<List<BorrowHistory>> getAllBorrowHistory() async {
    try {
      _logger.i('📜 Récupération de l\'historique d\'emprunts...');
      
      final response = await _client
          .from(_borrowHistoryTable)
          .select()
          .order('borrowed_at', ascending: false);
      
      final history = (response as List)
          .map((json) => BorrowHistory.fromSupabaseJson(json))
          .toList();
      
      _logger.i('✅ ${history.length} entrées d\'historique récupérées');
      return history;
    } catch (e) {
      _logger.e('❌ Erreur getAllBorrowHistory: $e');
      rethrow;
    }
  }
  
  /// Ajoute une entrée d'historique
  Future<void> addBorrowHistory(BorrowHistory history) async {
    try {
      _logger.i('➕ Ajout historique emprunt: ${history.isbn}');
      
      await _client
          .from(_borrowHistoryTable)
          .insert(history.toSupabaseJson());
      
      _logger.i('✅ Historique ajouté');
    } catch (e) {
      _logger.e('❌ Erreur addBorrowHistory: $e');
      rethrow;
    }
  }
  
  /// Met à jour une entrée d'historique
  Future<void> updateBorrowHistory(BorrowHistory history) async {
    try {
      if (history.id == null) {
        throw Exception('Cannot update borrow history without an ID');
      }
      
      _logger.i('🔄 Mise à jour historique ID: ${history.id}');
      
      await _client
          .from(_borrowHistoryTable)
          .update(history.toSupabaseJson())
          .eq('id', history.id!);
      
      _logger.i('✅ Historique mis à jour');
    } catch (e) {
      _logger.e('❌ Erreur updateBorrowHistory: $e');
      rethrow;
    }
  }
  
  /// Recherche l'historique d'emprunts (pour FullSyncService)
  Future<List<BorrowHistory>> searchBorrowHistory(String field, String value) async {
    try {
      final response = await _client
          .from(_borrowHistoryTable)
          .select()
          .eq(field, value)
          .limit(1);
      
      return (response as List)
          .map((json) => BorrowHistory.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      _logger.e('❌ Erreur searchBorrowHistory: $e');
      return [];
    }
  }
}
