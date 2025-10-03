import '../../models/models.dart';

/// Convertit les données entre API et modèles
class DataConverter {
  
  // === BOOK ===
  
  static Book toBook(Map<String, dynamic> row) {
    return Book(
      isbn: row['isbn']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      author: row['author']?.toString() ?? '',
      publisher: row['publisher']?.toString() ?? '',
      publishYear: int.tryParse(row['publishYear']?.toString() ?? '') ?? 0,
      publishPlace: row['publishPlace']?.toString() ?? '',
      subjects: _splitString(row['subjects']?.toString() ?? ''),
      pageCount: int.tryParse(row['pageCount']?.toString() ?? '') ?? 0,
      coverImageUrl: row['coverImageUrl']?.toString(),
      groupId: row['groupId']?.toString(),
      status: _toBookStatus(row['status']?.toString() ?? ''),
      borrowedBy: row['borrowedBy']?.toString(),
      borrowerClassName: row['borrowerClassName']?.toString(),
      borrowedDate: _toDateTime(row['borrowedDate']?.toString()),
    );
  }

  static Map<String, dynamic> fromBook(Book book) {
    return {
      'isbn': book.isbn,
      'title': book.title,
      'author': book.author,
      'publisher': book.publisher,
      'publishYear': book.publishYear.toString(),
      'publishPlace': book.publishPlace,
      'subjects': book.subjects.join('|'),
      'pageCount': book.pageCount.toString(),
      'coverImageUrl': book.coverImageUrl ?? '',
      'groupId': book.groupId ?? '',
      'status': book.status.name,
      'borrowedBy': book.borrowedBy ?? '',
      'borrowerClassName': book.borrowerClassName ?? '',
      'borrowedDate': book.borrowedDate?.toIso8601String() ?? '',
    };
  }

  // === BOOKGROUP ===
  
  static BookGroup toBookGroup(Map<String, dynamic> row) {
    return BookGroup(
      id: row['id']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      key: row['key']?.toString() ?? '',
      logoPath: row['logoPath']?.toString(),
      svgData: row['svgData']?.toString().isNotEmpty == true ? row['svgData']?.toString() : null,
      groupColor: row['groupColor']?.toString().isNotEmpty == true ? row['groupColor']?.toString() : null,
      keywords: _splitString(row['keywords']?.toString() ?? ''),
      description: row['description']?.toString(),
    );
  }

  static Map<String, dynamic> fromBookGroup(BookGroup group) {
    return {
      'id': group.id,
      'title': group.title,
      'key': group.key,
      'logoPath': group.logoPath ?? '',
      'svgData': group.svgData ?? '',
      'groupColor': group.groupColor ?? '',
      'keywords': group.keywords.join('|'),
      'description': group.description ?? '',
    };
  }

  // === CLASSROOM ===
  
  static ClassRoom toClassRoom(Map<String, dynamic> row) {
    return ClassRoom(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> fromClassRoom(ClassRoom classRoom) {
    return {
      'id': classRoom.id,
      'name': classRoom.name,
    };
  }

  // === BORROW HISTORY ===
  
  static BorrowHistory toBorrowHistory(Map<String, dynamic> row) {
    return BorrowHistory(
      id: row['id']?.toString() ?? '',
      isbn: row['isbn']?.toString() ?? '',
      bookTitle: row['bookTitle']?.toString() ?? '',
      borrowerName: row['borrowerName']?.toString() ?? '',
      classId: row['classId']?.toString(),
      className: row['className']?.toString(),
      borrowedAt: _toDateTime(row['borrowedAt']?.toString()) ?? DateTime.now(),
      returnedAt: _toDateTime(row['returnedAt']?.toString()),
    );
  }

  static Map<String, dynamic> fromBorrowHistory(BorrowHistory history) {
    return {
      'id': history.id ?? '', // Assurer que l'ID n'est jamais null
      'isbn': history.isbn,
      'bookTitle': history.bookTitle,
      'borrowerName': history.borrowerName,
      'classId': history.classId ?? '',
      'className': history.className ?? '',
      'borrowedAt': history.borrowedAt.toIso8601String(),
      'returnedAt': history.returnedAt?.toIso8601String() ?? '',
    };
  }

  // === HELPERS ===
  
  static List<String> _splitString(String value) {
    if (value.isEmpty) return [];
    return value.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static BookStatus _toBookStatus(String value) {
    switch (value.toLowerCase()) {
      case 'borrowed':
        return BookStatus.borrowed;
      case 'lost':
        return BookStatus.lost;
      default:
        return BookStatus.available;
    }
  }

  static DateTime? _toDateTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (e) {
      return null;
    }
  }
}
