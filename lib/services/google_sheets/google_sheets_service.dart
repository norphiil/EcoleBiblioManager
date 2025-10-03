import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/models.dart';
import 'api_client.dart';
import 'books_operations.dart';
import 'groups_operations.dart';
import 'classes_operations.dart';
import 'borrow_history_operations.dart';

/// Service principal Google Sheets
class GoogleSheetsService {
  GoogleSheetsApiClient? _client;
  BooksOperations? books;
  GroupsOperations? groups;
  ClassesOperations? classes;
  BorrowHistoryOperations? borrowHistory;
  bool _initialized = false;

  /// Initialise le service
  Future<void> initialize() async {
    if (_initialized) return; // Éviter la double initialisation
    
    final scriptUrl = dotenv.env['GOOGLE_APPS_SCRIPT_URL'];
    if (scriptUrl == null || scriptUrl.isEmpty) {
      throw Exception('GOOGLE_APPS_SCRIPT_URL manquant dans .env');
    }

    final booksSheet = dotenv.env['BOOKS_SHEET_NAME'] ?? 'Livres';
    final groupsSheet = dotenv.env['GROUPS_SHEET_NAME'] ?? 'Groupes';
    final classesSheet = dotenv.env['CLASSES_SHEET_NAME'] ?? 'Classes';
    final borrowHistorySheet = dotenv.env['BORROW_HISTORY_SHEET_NAME'] ?? 'Historique';

    _client = GoogleSheetsApiClient(scriptUrl);
    books = BooksOperations(_client!, booksSheet);
    groups = GroupsOperations(_client!, groupsSheet);
    classes = ClassesOperations(_client!, classesSheet);
    borrowHistory = BorrowHistoryOperations(_client!, borrowHistorySheet);

    // Test de connexion
    await _client!.testConnection();
    
    _initialized = true;
  }

  /// Initialise les feuilles dans Google Sheets
  Future<void> initializeSheets() async {
    await _client!.call({'action': 'initializeSheets'});
  }

  // === LIVRES ===

  Future<List<Book>> getAllBooks() => books!.getAll();
  Future<Book> addBook(Book book) => books!.add(book);
  Future<Book> updateBook(Book book) => books!.update(book);
  Future<void> deleteBook(String id) => books!.delete(id);
  Future<List<Book>> searchBooks(String field, String value) => books!.search(field, value);

  // === GROUPES ===

  Future<List<BookGroup>> getAllBookGroups() => groups!.getAll();
  Future<BookGroup> addBookGroup(BookGroup group) => groups!.add(group);
  Future<BookGroup> updateBookGroup(BookGroup group) => groups!.update(group);
  Future<void> deleteBookGroup(String id) => groups!.delete(id);
  Future<List<BookGroup>> searchBookGroups(String field, String value) => groups!.search(field, value);

  // === CLASSES ===

  Future<List<ClassRoom>> getAllClasses() => classes!.getAll();
  Future<ClassRoom> addClass(ClassRoom classRoom) => classes!.add(classRoom);
  Future<ClassRoom> updateClass(ClassRoom classRoom) => classes!.update(classRoom);
  Future<void> deleteClass(String id) => classes!.delete(id);
  Future<List<ClassRoom>> searchClasses(String field, String value) => classes!.search(field, value);

  // === HISTORIQUE DES EMPRUNTS ===

  Future<List<BorrowHistory>> getAllBorrowHistory() => borrowHistory!.getAll();
  Future<BorrowHistory> addBorrowHistory(BorrowHistory history) => borrowHistory!.add(history);
  Future<BorrowHistory> updateBorrowHistory(BorrowHistory history) => borrowHistory!.update(history);
  Future<void> deleteBorrowHistory(String id) => borrowHistory!.delete(id);
  Future<List<BorrowHistory>> searchBorrowHistory(String field, String value) => borrowHistory!.search(field, value);
  Future<List<BorrowHistory>> getBorrowHistoryByIsbn(String isbn) => borrowHistory!.getByIsbn(isbn);
  Future<List<BorrowHistory>> getBorrowHistoryByClassId(String classId) => borrowHistory!.getByClassId(classId);
}
