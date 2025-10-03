import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../models/models.dart';

/// Helper pour gérer la base de données SQLite locale
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Retourne l'instance de la base de données
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialise la base de données
  Future<Database> _initDatabase() async {
    // Pour Windows desktop, utiliser sqflite_common_ffi
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ebm_local.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Crée les tables de la base de données
  Future<void> _createDatabase(Database db, int version) async {
    // Table des livres (sans dueDate et sans borrowHistory - maintenant dans table séparée)
    await db.execute('''
      CREATE TABLE books (
        isbn TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        publisher TEXT,
        publishYear INTEGER,
        publishPlace TEXT,
        pageCount INTEGER,
        subjects TEXT,
        coverImageUrl TEXT,
        groupId TEXT,
        status TEXT NOT NULL,
        borrowedBy TEXT,
        borrowerClassName TEXT,
        borrowedDate TEXT,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'synced',
        localModifiedAt TEXT
      )
    ''');

    // Table des groupes
    await db.execute('''
      CREATE TABLE book_groups (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        key TEXT NOT NULL,
        logoPath TEXT,
        svgData TEXT,
        groupColor TEXT,
        keywords TEXT,
        description TEXT,
        lastModified TEXT,
        syncStatus TEXT DEFAULT 'synced',
        localModifiedAt TEXT
      )
    ''');

    // Table des classes
    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');

    // Table de l'historique des emprunts
    await db.execute('''
      CREATE TABLE borrow_history (
        id TEXT PRIMARY KEY,
        isbn TEXT NOT NULL,
        bookTitle TEXT NOT NULL,
        borrowerName TEXT NOT NULL,
        classId TEXT,
        className TEXT,
        borrowedAt TEXT NOT NULL,
        returnedAt TEXT,
        FOREIGN KEY (isbn) REFERENCES books(isbn) ON DELETE CASCADE
      )
    ''');

    // Table de métadonnées de synchronisation
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Index pour améliorer les performances
    await db.execute('CREATE INDEX idx_books_groupId ON books(groupId)');
    await db.execute('CREATE INDEX idx_books_status ON books(status)');
    await db.execute('CREATE INDEX idx_books_syncStatus ON books(syncStatus)');
    await db.execute('CREATE INDEX idx_groups_syncStatus ON book_groups(syncStatus)');
    await db.execute('CREATE INDEX idx_classes_name ON classes(name)');
    await db.execute('CREATE INDEX idx_borrow_history_isbn ON borrow_history(isbn)');
    await db.execute('CREATE INDEX idx_borrow_history_borrowedAt ON borrow_history(borrowedAt)');
    await db.execute('CREATE INDEX idx_borrow_history_classId ON borrow_history(classId)');
  }

  /// Met à jour la base de données lors d'un changement de version
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration vers version 2 : Ajouter la table classes et les champs d'historique
      print('Migration de la base de données de v$oldVersion vers v2');
      
      // Ajouter les nouveaux champs dans books
      await db.execute('ALTER TABLE books ADD COLUMN borrowerClassName TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN borrowHistory TEXT DEFAULT "[]"');
      
      // Créer la table classes
      await db.execute('''
        CREATE TABLE classes (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL
        )
      ''');
      
      await db.execute('CREATE INDEX idx_classes_name ON classes(name)');
      
      print('Migration v1→v2 terminée avec succès');
    }
    
    if (oldVersion < 3) {
      // Migration vers version 3 : Créer table d'historique séparée et supprimer dueDate
      print('Migration de la base de données de v$oldVersion vers v3');
      
      // Créer la nouvelle table borrow_history
      await db.execute('''
        CREATE TABLE borrow_history (
          id TEXT PRIMARY KEY,
          isbn TEXT NOT NULL,
          bookTitle TEXT NOT NULL,
          borrowerName TEXT NOT NULL,
          classId TEXT,
          className TEXT,
          borrowedAt TEXT NOT NULL,
          returnedAt TEXT,
          FOREIGN KEY (isbn) REFERENCES books(isbn) ON DELETE CASCADE
        )
      ''');
      
      // Créer des index pour améliorer les performances de recherche
      await db.execute('CREATE INDEX idx_borrow_history_isbn ON borrow_history(isbn)');
      await db.execute('CREATE INDEX idx_borrow_history_borrowedAt ON borrow_history(borrowedAt)');
      await db.execute('CREATE INDEX idx_borrow_history_classId ON borrow_history(classId)');
      
      // SQLite ne supporte pas DROP COLUMN, donc on doit recréer la table books
      // 1. Créer une table temporaire sans dueDate et borrowHistory
      await db.execute('''
        CREATE TABLE books_temp (
          isbn TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT NOT NULL,
          publisher TEXT,
          publishYear INTEGER,
          publishPlace TEXT,
          pageCount INTEGER,
          subjects TEXT,
          coverImageUrl TEXT,
          groupId TEXT,
          status TEXT NOT NULL,
          borrowedBy TEXT,
          borrowerClassName TEXT,
          borrowedDate TEXT,
          lastModified TEXT,
          syncStatus TEXT DEFAULT 'synced',
          localModifiedAt TEXT
        )
      ''');
      
      // 2. Copier les données (sans dueDate et borrowHistory)
      await db.execute('''
        INSERT INTO books_temp 
        SELECT isbn, title, author, publisher, publishYear, publishPlace, 
               pageCount, subjects, coverImageUrl, groupId, status, borrowedBy, 
               borrowerClassName, borrowedDate, lastModified, syncStatus, localModifiedAt
        FROM books
      ''');
      
      // 3. Supprimer l'ancienne table
      await db.execute('DROP TABLE books');
      
      // 4. Renommer la table temporaire
      await db.execute('ALTER TABLE books_temp RENAME TO books');
      
      // 5. Recréer les index
      await db.execute('CREATE INDEX idx_books_groupId ON books(groupId)');
      await db.execute('CREATE INDEX idx_books_status ON books(status)');
      await db.execute('CREATE INDEX idx_books_syncStatus ON books(syncStatus)');
      
      print('Migration v2→v3 terminée avec succès');
    }
    
    if (oldVersion < 4) {
      // Migration vers version 4 : Ajouter support SVG et couleur pour les groupes
      print('Migration de la base de données de v$oldVersion vers v4');
      
      // Ajouter les colonnes svgData et groupColor à book_groups
      await db.execute('ALTER TABLE book_groups ADD COLUMN svgData TEXT');
      await db.execute('ALTER TABLE book_groups ADD COLUMN groupColor TEXT');
      
      print('Migration v3→v4 terminée avec succès');
    }
  }

  // ==================== LIVRES ====================

  /// Récupère tous les livres
  Future<List<Book>> getAllBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return maps.map((map) => _bookFromMap(map)).toList();
  }

  /// Récupère un livre par ISBN
  Future<Book?> getBook(String isbn) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
    if (maps.isEmpty) return null;
    return _bookFromMap(maps.first);
  }

  /// Recherche des livres
  Future<List<Book>> searchBooks(String field, String value) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: '$field LIKE ?',
      whereArgs: ['%$value%'],
    );
    return maps.map((map) => _bookFromMap(map)).toList();
  }

  /// Récupère les livres d'un groupe
  Future<List<Book>> getBooksByGroup(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    return maps.map((map) => _bookFromMap(map)).toList();
  }

  /// Ajoute un livre
  Future<void> insertBook(Book book) async {
    final db = await database;
    await db.insert(
      'books',
      _bookToMap(book, syncStatus: 'pending'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Met à jour un livre
  Future<void> updateBook(Book book) async {
    final db = await database;
    await db.update(
      'books',
      _bookToMap(book, syncStatus: 'pending'),
      where: 'isbn = ?',
      whereArgs: [book.isbn],
    );
  }

  /// Supprime un livre
  Future<void> deleteBook(String isbn) async {
    final db = await database;
    await db.delete(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
  }

  /// Récupère les livres non synchronisés
  Future<List<Book>> getPendingBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'syncStatus = ?',
      whereArgs: ['pending'],
    );
    return maps.map((map) => _bookFromMap(map)).toList();
  }

  /// Marque un livre comme synchronisé
  Future<void> markBookAsSynced(String isbn) async {
    final db = await database;
    await db.update(
      'books',
      {'syncStatus': 'synced'},
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
  }

  // ==================== GROUPES ====================

  /// Récupère tous les groupes
  Future<List<BookGroup>> getAllGroups() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('book_groups');
    return maps.map((map) => _groupFromMap(map)).toList();
  }

  /// Récupère un groupe par ID
  Future<BookGroup?> getGroup(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _groupFromMap(maps.first);
  }

  /// Ajoute un groupe
  Future<void> insertGroup(BookGroup group) async {
    final db = await database;
    await db.insert(
      'book_groups',
      _groupToMap(group, syncStatus: 'pending'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Met à jour un groupe
  Future<void> updateGroup(BookGroup group) async {
    final db = await database;
    await db.update(
      'book_groups',
      _groupToMap(group, syncStatus: 'pending'),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  /// Supprime un groupe
  Future<void> deleteGroup(String id) async {
    final db = await database;
    await db.delete(
      'book_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Récupère les groupes non synchronisés
  Future<List<BookGroup>> getPendingGroups() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_groups',
      where: 'syncStatus = ?',
      whereArgs: ['pending'],
    );
    return maps.map((map) => _groupFromMap(map)).toList();
  }

  /// Marque un groupe comme synchronisé
  Future<void> markGroupAsSynced(String id) async {
    final db = await database;
    await db.update(
      'book_groups',
      {'syncStatus': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== MÉTADONNÉES DE SYNC ====================

  /// Enregistre une métadonnée de synchronisation
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': key,
        'value': value,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Récupère une métadonnée de synchronisation
  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  /// Récupère la date de dernière synchronisation
  Future<DateTime?> getLastSyncTime() async {
    final value = await getSyncMetadata('last_sync_time');
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Enregistre la date de dernière synchronisation
  Future<void> setLastSyncTime(DateTime time) async {
    await setSyncMetadata('last_sync_time', time.toIso8601String());
  }

  // ==================== UTILITAIRES ====================

  /// Vide toutes les tables (pour réinitialisation)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('books');
    await db.delete('book_groups');
    await db.delete('sync_metadata');
  }

  /// Convertit un Map en Book
  Book _bookFromMap(Map<String, dynamic> map) {
    final subjectsStr = map['subjects'] as String?;
    final subjects = (subjectsStr != null && subjectsStr.isNotEmpty)
        ? subjectsStr.split('|').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    
    return Book(
      isbn: map['isbn'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      publisher: map['publisher'] as String?,
      publishYear: map['publishYear'] as int?,
      publishPlace: map['publishPlace'] as String?,
      pageCount: map['pageCount'] as int?,
      subjects: subjects,
      coverImageUrl: map['coverImageUrl'] as String?,
      groupId: map['groupId'] as String?,
      status: BookStatus.fromString(map['status'] as String? ?? 'available'),
      borrowedBy: map['borrowedBy'] as String?,
      borrowerClassName: map['borrowerClassName'] as String?,
      borrowedDate: map['borrowedDate'] != null
          ? DateTime.tryParse(map['borrowedDate'] as String)
          : null,
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified'] as String)
          : null,
    );
  }

  /// Convertit un Book en Map
  Map<String, dynamic> _bookToMap(Book book, {String syncStatus = 'synced'}) {
    return {
      'isbn': book.isbn,
      'title': book.title,
      'author': book.author,
      'publisher': book.publisher,
      'publishYear': book.publishYear,
      'publishPlace': book.publishPlace,
      'pageCount': book.pageCount,
      'subjects': book.subjects.join('|'),
      'coverImageUrl': book.coverImageUrl,
      'groupId': book.groupId,
      'status': book.status.name,
      'borrowedBy': book.borrowedBy,
      'borrowerClassName': book.borrowerClassName,
      'borrowedDate': book.borrowedDate?.toIso8601String(),
      'lastModified': book.lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'syncStatus': syncStatus,
      'localModifiedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Convertit un Map en BookGroup
  BookGroup _groupFromMap(Map<String, dynamic> map) {
    final keywordsStr = map['keywords'] as String?;
    final keywords = (keywordsStr != null && keywordsStr.isNotEmpty)
        ? keywordsStr.split('|').where((k) => k.trim().isNotEmpty).toList()
        : <String>[];
    
    return BookGroup(
      id: map['id'] as String,
      title: map['title'] as String,
      key: map['key'] as String,
      logoPath: map['logoPath'] as String?,
      svgData: map['svgData'] as String?,
      groupColor: map['groupColor'] as String?,
      keywords: keywords,
      description: map['description'] as String?,
    );
  }

  /// Convertit un BookGroup en Map
  Map<String, dynamic> _groupToMap(BookGroup group, {String syncStatus = 'synced'}) {
    return {
      'id': group.id,
      'title': group.title,
      'key': group.key,
      'logoPath': group.logoPath,
      'svgData': group.svgData,
      'groupColor': group.groupColor,
      'keywords': group.keywords.join('|'),
      'description': group.description,
      'lastModified': DateTime.now().toIso8601String(),
      'syncStatus': syncStatus,
      'localModifiedAt': DateTime.now().toIso8601String(),
    };
  }

  // ==================== MÉTHODES POUR LES CLASSES ====================

  /// Récupère toutes les classes (triées par nom)
  Future<List<ClassRoom>> getAllClasses() async {
    final db = await database;
    final maps = await db.query('classes', orderBy: 'name ASC');
    return maps.map((map) => _classFromMap(map)).toList();
  }

  /// Ajoute une nouvelle classe
  Future<void> addClass(ClassRoom classRoom) async {
    final db = await database;
    await db.insert(
      'classes',
      _classToMap(classRoom),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Met à jour une classe existante
  Future<void> updateClass(ClassRoom classRoom) async {
    final db = await database;
    await db.update(
      'classes',
      _classToMap(classRoom),
      where: 'id = ?',
      whereArgs: [classRoom.id],
    );
  }

  /// Supprime une classe
  Future<void> deleteClass(String id) async {
    final db = await database;
    await db.delete(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Convertit un Map en ClassRoom
  ClassRoom _classFromMap(Map<String, dynamic> map) {
    return ClassRoom(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  /// Convertit un ClassRoom en Map
  Map<String, dynamic> _classToMap(ClassRoom classRoom) {
    return {
      'id': classRoom.id,
      'name': classRoom.name,
    };
  }

  // ==================== HISTORIQUE DES EMPRUNTS ====================

  /// Récupère tout l'historique des emprunts
  Future<List<BorrowHistory>> getAllBorrowHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_history',
      orderBy: 'borrowedAt DESC',
    );
    return maps.map((map) => _borrowHistoryFromMap(map)).toList();
  }

  /// Récupère l'historique pour un livre spécifique
  Future<List<BorrowHistory>> getBorrowHistoryForBook(String isbn) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_history',
      where: 'isbn = ?',
      whereArgs: [isbn],
      orderBy: 'borrowedAt DESC',
    );
    return maps.map((map) => _borrowHistoryFromMap(map)).toList();
  }

  /// Récupère l'historique pour une classe spécifique
  Future<List<BorrowHistory>> getBorrowHistoryForClass(String classId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_history',
      where: 'classId = ?',
      whereArgs: [classId],
      orderBy: 'borrowedAt DESC',
    );
    return maps.map((map) => _borrowHistoryFromMap(map)).toList();
  }

  /// Ajoute un enregistrement d'emprunt
  Future<String> addBorrowHistory(BorrowHistory history) async {
    final db = await database;
    
    // Générer un ID si non fourni
    final id = history.id ?? '${DateTime.now().millisecondsSinceEpoch}-${history.isbn}';
    final historyWithId = history.copyWith(id: id);
    
    await db.insert('borrow_history', _borrowHistoryToMap(historyWithId));
    return id;
  }

  /// Met à jour un enregistrement d'emprunt (par exemple pour marquer le retour)
  Future<void> updateBorrowHistory(BorrowHistory history) async {
    final db = await database;
    await db.update(
      'borrow_history',
      _borrowHistoryToMap(history),
      where: 'id = ?',
      whereArgs: [history.id],
    );
  }

  /// Supprime un enregistrement d'historique
  Future<void> deleteBorrowHistory(String id) async {
    final db = await database;
    await db.delete(
      'borrow_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque le dernier emprunt comme retourné pour un livre
  Future<void> markLastBorrowAsReturned(String isbn) async {
    final db = await database;
    
    // Récupérer le dernier emprunt non retourné
    final maps = await db.query(
      'borrow_history',
      where: 'isbn = ? AND returnedAt IS NULL',
      whereArgs: [isbn],
      orderBy: 'borrowedAt DESC',
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      final history = _borrowHistoryFromMap(maps.first);
      final updatedHistory = history.markAsReturned();
      await updateBorrowHistory(updatedHistory);
    }
  }

  /// Convertit un Map en BorrowHistory
  BorrowHistory _borrowHistoryFromMap(Map<String, dynamic> map) {
    return BorrowHistory(
      id: map['id'] as String,
      isbn: map['isbn'] as String,
      bookTitle: map['bookTitle'] as String,
      borrowerName: map['borrowerName'] as String,
      classId: map['classId'] as String?,
      className: map['className'] as String?,
      borrowedAt: DateTime.parse(map['borrowedAt'] as String),
      returnedAt: map['returnedAt'] != null
          ? DateTime.parse(map['returnedAt'] as String)
          : null,
    );
  }

  /// Convertit un BorrowHistory en Map
  Map<String, dynamic> _borrowHistoryToMap(BorrowHistory history) {
    return {
      'id': history.id,
      'isbn': history.isbn,
      'bookTitle': history.bookTitle,
      'borrowerName': history.borrowerName,
      'classId': history.classId,
      'className': history.className,
      'borrowedAt': history.borrowedAt.toIso8601String(),
      'returnedAt': history.returnedAt?.toIso8601String(),
    };
  }

  /// Ferme la base de données
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
