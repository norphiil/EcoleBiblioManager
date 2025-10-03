import 'base_model.dart';

/// Modèle pour représenter un utilisateur de la bibliothèque
class LibraryUser extends Synchronizable {
  String id;
  String name;
  String className;
  String? email;
  String? phone;
  UserType type;
  
  // Historique d'emprunts
  List<String> borrowedBookIds;
  List<String> borrowingHistory;
  int maxBorrowLimit;
  
  // Métadonnées
  DateTime? lastModified;
  bool _isDirty;
  Map<String, dynamic> _changes = {};

  LibraryUser({
    required this.id,
    required this.name,
    required this.className,
    this.email,
    this.phone,
    this.type = UserType.student,
    List<String>? borrowedBookIds,
    List<String>? borrowingHistory,
    int? maxBorrowLimit,
    this.lastModified,
  }) : borrowedBookIds = borrowedBookIds ?? [],
        borrowingHistory = borrowingHistory ?? [],
        maxBorrowLimit = maxBorrowLimit ?? (type == UserType.teacher ? 10 : 3),
        _isDirty = false;

  /// Constructeur depuis les données Google Sheets
  factory LibraryUser.fromSheetRow(List<dynamic> row) {
    final userType = row.length > 3 ? UserType.fromString(row[3]?.toString() ?? 'student') : UserType.student;
    
    return LibraryUser(
      id: row.isNotEmpty ? row[0]?.toString() ?? '' : '',
      name: row.length > 1 ? row[1]?.toString() ?? '' : '',
      className: row.length > 2 ? row[2]?.toString() ?? '' : '',
      type: userType,
      email: row.length > 4 && row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
      phone: row.length > 5 && row[5]?.toString().isNotEmpty == true ? row[5].toString() : null,
      borrowedBookIds: row.length > 6 && row[6]?.toString().isNotEmpty == true 
          ? row[6].toString().split(',').map((e) => e.trim()).toList()
          : [],
      borrowingHistory: row.length > 7 && row[7]?.toString().isNotEmpty == true 
          ? row[7].toString().split(',').map((e) => e.trim()).toList()
          : [],
      maxBorrowLimit: row.length > 8 && row[8] != null ? int.tryParse(row[8].toString()) : null,
      lastModified: row.length > 9 && row[9]?.toString().isNotEmpty == true ? DateTime.tryParse(row[9].toString()) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'className': className,
      'email': email,
      'phone': phone,
      'type': type.toString(),
      'borrowedBookIds': borrowedBookIds,
      'borrowingHistory': borrowingHistory,
      'maxBorrowLimit': maxBorrowLimit,
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  /// Convertit en ligne pour Google Sheets
  List<dynamic> toSheetRow() {
    return [
      id,
      name,
      className,
      type.toString(),
      email ?? '',
      phone ?? '',
      borrowedBookIds.join(','),
      borrowingHistory.join(','),
      maxBorrowLimit.toString(),
      lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
    ];
  }

  @override
  String getId() => id;

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

  /// Vérifie si l'utilisateur peut emprunter un livre
  bool canBorrow() {
    return borrowedBookIds.length < maxBorrowLimit;
  }

  /// Ajoute un livre emprunté
  void borrowBook(String bookId) {
    if (!canBorrow()) {
      throw UserException('Limite d\'emprunt atteinte ($maxBorrowLimit livres maximum)');
    }
    
    if (borrowedBookIds.contains(bookId)) {
      throw UserException('Ce livre est déjà emprunté par cet utilisateur');
    }
    
    borrowedBookIds.add(bookId);
    borrowingHistory.add('$bookId:${DateTime.now().toIso8601String()}');
    setLastModified(DateTime.now());
  }

  /// Retire un livre emprunté
  void returnBook(String bookId) {
    if (!borrowedBookIds.contains(bookId)) {
      throw UserException('Ce livre n\'est pas emprunté par cet utilisateur');
    }
    
    borrowedBookIds.remove(bookId);
    setLastModified(DateTime.now());
  }

  /// Copie l'utilisateur avec de nouvelles valeurs
  LibraryUser copyWith({
    String? id,
    String? name,
    String? className,
    String? email,
    String? phone,
    UserType? type,
    List<String>? borrowedBookIds,
    List<String>? borrowingHistory,
    int? maxBorrowLimit,
  }) {
    return LibraryUser(
      id: id ?? this.id,
      name: name ?? this.name,
      className: className ?? this.className,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type ?? this.type,
      borrowedBookIds: borrowedBookIds ?? List.from(this.borrowedBookIds),
      borrowingHistory: borrowingHistory ?? List.from(this.borrowingHistory),
      maxBorrowLimit: maxBorrowLimit ?? this.maxBorrowLimit,
      lastModified: DateTime.now(),
    );
  }
}

/// Type d'utilisateur dans la bibliothèque
enum UserType {
  student('student'),
  teacher('teacher'),
  staff('staff'),
  admin('admin');

  const UserType(this.value);
  
  final String value;

  static UserType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'student':
        return UserType.student;
      case 'teacher':
        return UserType.teacher;
      case 'staff':
        return UserType.staff;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.student;
    }
  }

  @override
  String toString() => value;
}

/// Exception spécifique aux utilisateurs
class UserException extends AppException {
  const UserException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}