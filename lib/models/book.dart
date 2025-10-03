import 'base_model.dart';

/// Modèle pour représenter un livre dans la bibliothèque
class Book extends Synchronizable {
  String isbn;
  String title;
  String author;
  String? publisher;
  int? publishYear;
  String? publishPlace;
  int? pageCount;
  List<String> subjects;
  String? coverImageUrl;
  
  // Référence au groupe de rangement
  String? groupId;
  
  // Statut du livre
  BookStatus status;
  String? borrowedBy;
  DateTime? borrowedDate;
  DateTime? dueDate;
  
  // Métadonnées
  DateTime? lastModified;
  bool _isDirty;
  Map<String, dynamic> _changes = {};

  Book({
    required this.isbn,
    required this.title,
    required this.author,
    this.publisher,
    this.publishYear,
    this.publishPlace,
    this.pageCount,
    this.subjects = const [],
    this.coverImageUrl,
    this.groupId,
    this.status = BookStatus.available,
    this.borrowedBy,
    this.borrowedDate,
    this.dueDate,
    this.lastModified,
  }) : _isDirty = false;

  /// Constructeur depuis une réponse API (OpenLibrary)
  factory Book.fromApiResponse(Map<String, dynamic> json, String isbn) {
    final bookData = json['ISBN:$isbn'] ?? json;
    
    return Book(
      isbn: isbn,
      title: bookData['title'] ?? 'Titre inconnu',
      author: _extractAuthor(bookData),
      publisher: _extractPublisher(bookData),
      publishYear: _extractPublishYear(bookData),
      publishPlace: _extractPublishPlace(bookData),
      pageCount: bookData['number_of_pages'],
      subjects: _extractSubjects(bookData),
      coverImageUrl: _extractCoverImage(bookData),
    );
  }

  /// Constructeur depuis les données Google Sheets
  factory Book.fromSheetRow(List<dynamic> row) {
    return Book(
      isbn: row.isNotEmpty ? row[0]?.toString() ?? '' : '',
      title: row.length > 1 ? row[1]?.toString() ?? '' : '',
      author: row.length > 2 ? row[2]?.toString() ?? '' : '',
      publisher: row.length > 3 && row[3]?.toString().isNotEmpty == true ? row[3].toString() : null,
      publishYear: row.length > 4 && row[4] != null ? int.tryParse(row[4].toString()) : null,
      publishPlace: row.length > 5 && row[5]?.toString().isNotEmpty == true ? row[5].toString() : null,
      pageCount: row.length > 6 && row[6] != null ? int.tryParse(row[6].toString()) : null,
      subjects: row.length > 7 && row[7]?.toString().isNotEmpty == true ? row[7].toString().split(';') : [],
      coverImageUrl: row.length > 8 && row[8]?.toString().isNotEmpty == true ? row[8].toString() : null,
      groupId: row.length > 9 && row[9]?.toString().isNotEmpty == true ? row[9].toString() : null,
      status: row.length > 10 ? BookStatus.fromString(row[10]?.toString() ?? 'available') : BookStatus.available,
      borrowedBy: row.length > 11 && row[11]?.toString().isNotEmpty == true ? row[11].toString() : null,
      borrowedDate: row.length > 12 && row[12]?.toString().isNotEmpty == true ? DateTime.tryParse(row[12].toString()) : null,
      dueDate: row.length > 13 && row[13]?.toString().isNotEmpty == true ? DateTime.tryParse(row[13].toString()) : null,
      lastModified: row.length > 14 && row[14]?.toString().isNotEmpty == true ? DateTime.tryParse(row[14].toString()) : null,
    );
  }

  static String _extractAuthor(Map<String, dynamic> data) {
    if (data['authors'] is List && (data['authors'] as List).isNotEmpty) {
      final author = data['authors'][0];
      if (author is Map) {
        return author['name'] ?? 'Auteur inconnu';
      }
      return author?.toString() ?? 'Auteur inconnu';
    }
    return data['author']?.toString() ?? 'Auteur inconnu';
  }

  static String? _extractPublisher(Map<String, dynamic> data) {
    if (data['publishers'] is List && (data['publishers'] as List).isNotEmpty) {
      final publisher = data['publishers'][0];
      if (publisher is Map) {
        return publisher['name'];
      }
      return publisher?.toString();
    }
    return data['publisher']?.toString();
  }

  static int? _extractPublishYear(Map<String, dynamic> data) {
    final publishDate = data['publish_date'];
    if (publishDate != null) {
      return int.tryParse(publishDate.toString());
    }
    return null;
  }

  static String? _extractPublishPlace(Map<String, dynamic> data) {
    if (data['publish_places'] is List && (data['publish_places'] as List).isNotEmpty) {
      final place = data['publish_places'][0];
      if (place is Map) {
        return place['name'];
      }
      return place?.toString();
    }
    return null;
  }

  static List<String> _extractSubjects(Map<String, dynamic> data) {
    if (data['subjects'] is List) {
      return (data['subjects'] as List)
          .map((subject) {
            if (subject is Map) {
              return subject['name']?.toString();
            }
            return subject?.toString();
          })
          .where((name) => name != null)
          .cast<String>()
          .toList();
    }
    return [];
  }

  static String? _extractCoverImage(Map<String, dynamic> data) {
    if (data['cover'] is Map) {
      final cover = data['cover'] as Map;
      return cover['medium'] ?? cover['large'] ?? cover['small'];
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'isbn': isbn,
      'title': title,
      'author': author,
      'publisher': publisher,
      'publishYear': publishYear,
      'publishPlace': publishPlace,
      'pageCount': pageCount,
      'subjects': subjects,
      'coverImageUrl': coverImageUrl,
      'groupId': groupId,
      'status': status.toString(),
      'borrowedBy': borrowedBy,
      'borrowedDate': borrowedDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  /// Convertit en ligne pour Google Sheets
  List<dynamic> toSheetRow() {
    return [
      isbn,
      title,
      author,
      publisher ?? '',
      publishYear?.toString() ?? '',
      publishPlace ?? '',
      pageCount?.toString() ?? '',
      subjects.join(';'),
      coverImageUrl ?? '',
      groupId ?? '',
      status.toString(),
      borrowedBy ?? '',
      borrowedDate?.toIso8601String() ?? '',
      dueDate?.toIso8601String() ?? '',
      lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
    ];
  }

  @override
  String getId() => isbn;

  @override
  DateTime? getLastModified() => lastModified;

  @override
  void setLastModified(DateTime dateTime) {
    lastModified = dateTime;
    markAsDirty();
  }

  @override
  bool get isDirty => _isDirty;

  @override
  void markAsSynced() {
    _isDirty = false;
    _changes.clear();
  }

  @override
  void markAsDirty() {
    _isDirty = true;
  }

  @override
  Map<String, dynamic> getChanges() => Map.from(_changes);

  /// Emprunte le livre
  void borrow(String borrowerName, {Duration loanDuration = const Duration(days: 14)}) {
    if (status != BookStatus.available) {
      throw BookException('Le livre n\'est pas disponible pour l\'emprunt');
    }
    
    status = BookStatus.borrowed;
    borrowedBy = borrowerName;
    borrowedDate = DateTime.now();
    dueDate = borrowedDate!.add(loanDuration);
    setLastModified(DateTime.now());
  }

  /// Rend le livre
  void returnBook() {
    status = BookStatus.available;
    borrowedBy = null;
    borrowedDate = null;
    dueDate = null;
    setLastModified(DateTime.now());
  }

  /// Assigne le livre à un groupe
  void assignToGroup(String groupId) {
    this.groupId = groupId;
    setLastModified(DateTime.now());
  }

  /// Retire le livre de son groupe
  void removeFromGroup() {
    groupId = null;
    setLastModified(DateTime.now());
  }

  /// Copie le livre avec de nouvelles valeurs
  Book copyWith({
    String? isbn,
    String? title,
    String? author,
    String? publisher,
    int? publishYear,
    String? publishPlace,
    int? pageCount,
    List<String>? subjects,
    String? coverImageUrl,
    String? groupId,
    BookStatus? status,
    String? borrowedBy,
    DateTime? borrowedDate,
    DateTime? dueDate,
  }) {
    return Book(
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      publishYear: publishYear ?? this.publishYear,
      publishPlace: publishPlace ?? this.publishPlace,
      pageCount: pageCount ?? this.pageCount,
      subjects: subjects ?? this.subjects,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      borrowedBy: borrowedBy ?? this.borrowedBy,
      borrowedDate: borrowedDate ?? this.borrowedDate,
      dueDate: dueDate ?? this.dueDate,
      lastModified: DateTime.now(),
    );
  }
}

/// Statut d'un livre dans la bibliothèque
enum BookStatus {
  available('available'),
  borrowed('borrowed'),
  reserved('reserved'),
  maintenance('maintenance'),
  lost('lost');

  const BookStatus(this.value);
  
  final String value;

  static BookStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return BookStatus.available;
      case 'borrowed':
        return BookStatus.borrowed;
      case 'reserved':
        return BookStatus.reserved;
      case 'maintenance':
        return BookStatus.maintenance;
      case 'lost':
        return BookStatus.lost;
      default:
        return BookStatus.available;
    }
  }

  @override
  String toString() => value;
}

/// Exception spécifique aux livres
class BookException extends AppException {
  const BookException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}