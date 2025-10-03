import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/models.dart';
import 'api_client.dart';
import 'books_operations.dart';
import 'groups_operations.dart';

/// Service principal Google Sheets
class GoogleSheetsService {
  GoogleSheetsApiClient? _client;
  BooksOperations? books;
  GroupsOperations? groups;
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

    _client = GoogleSheetsApiClient(scriptUrl);
    books = BooksOperations(_client!, booksSheet);
    groups = GroupsOperations(_client!, groupsSheet);

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
}
