import '../models/models.dart';

/// Service temporaire pour gérer les groupes de livres
/// En attendant l'intégration complète avec Google Sheets
class BookGroupService {
  static final BookGroupService _instance = BookGroupService._internal();
  factory BookGroupService() => _instance;
  BookGroupService._internal();

  // Données temporaires en mémoire
  final List<BookGroup> _groups = [];

  final Map<String, Book> _books = {};

  Future<List<BookGroup>> getAllBookGroups() async {
    // Simulation d'un délai réseau
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_groups);
  }

  Future<BookGroup?> getBookGroupById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _groups.firstWhere((group) => group.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Book?> searchBookByIsbn(String isbn) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _books[isbn];
  }

  Future<void> addBook(Book book) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _books[book.isbn] = book;
  }

  Future<void> updateBook(Book book) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _books[book.isbn] = book;
  }

  Future<void> addBookGroup(BookGroup group) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _groups.add(group);
  }

  Future<void> updateBookGroup(BookGroup group) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      _groups[index] = group;
    }
  }

  Future<void> deleteBookGroup(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _groups.removeWhere((group) => group.id == id);
  }

  Future<List<Book>> getAllBooks() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _books.values.toList();
  }

  Future<List<Book>> getBooksByGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _books.values.where((book) => book.groupId == groupId).toList();
  }

  // Méthodes utilitaires
  List<BookGroup> getSuggestedGroups(List<String> bookSubjects) {
    final groupScores = <BookGroup, int>{};
    
    for (final group in _groups) {
      final score = group.calculateMatchScore(bookSubjects);
      if (score > 0) {
        groupScores[group] = score;
      }
    }

    // Trier par score décroissant
    final sortedGroups = groupScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedGroups.map((e) => e.key).toList();
  }
}