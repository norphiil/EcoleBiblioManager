import 'package:flutter/foundation.dart';

/// Modèle représentant une entrée dans l'historique des emprunts d'un livre
/// Stocké dans une table séparée pour un historique bien formaté
@immutable
class BorrowHistory {
  final String? id; // ID auto-généré pour la table
  final String isbn; // ISBN du livre emprunté
  final String bookTitle; // Copie du titre du livre
  final String borrowerName;
  final String? classId; // ID de la classe
  final String? className; // Nom de la classe
  final DateTime borrowedAt; // Date et heure d'emprunt
  final DateTime? returnedAt; // Date et heure de retour (nullable si en cours)
  
  const BorrowHistory({
    this.id,
    required this.isbn,
    required this.bookTitle,
    required this.borrowerName,
    this.classId,
    this.className,
    required this.borrowedAt,
    this.returnedAt,
  });

  /// Constructeur depuis une Map (base de données)
  factory BorrowHistory.fromMap(Map<String, dynamic> map) {
    return BorrowHistory(
      id: map['id'] as String?,
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

  /// Convertir en Map (pour base de données)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'isbn': isbn,
      'bookTitle': bookTitle,
      'borrowerName': borrowerName,
      'classId': classId,
      'className': className,
      'borrowedAt': borrowedAt.toIso8601String(),
      'returnedAt': returnedAt?.toIso8601String(),
    };
  }

  /// Créer depuis une chaîne JSON
  factory BorrowHistory.fromJson(Map<String, dynamic> json) {
    return BorrowHistory.fromMap(json);
  }

  /// Convertir en JSON
  Map<String, dynamic> toJson() => toMap();

  /// Copier avec modifications
  BorrowHistory copyWith({
    String? id,
    String? isbn,
    String? bookTitle,
    String? borrowerName,
    String? classId,
    String? className,
    DateTime? borrowedAt,
    DateTime? returnedAt,
  }) {
    return BorrowHistory(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      bookTitle: bookTitle ?? this.bookTitle,
      borrowerName: borrowerName ?? this.borrowerName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      borrowedAt: borrowedAt ?? this.borrowedAt,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }

  /// Marquer comme retourné
  BorrowHistory markAsReturned() {
    return copyWith(returnedAt: DateTime.now());
  }

  /// Est-ce que le livre est actuellement emprunté (pas encore retourné)
  bool get isCurrentlyBorrowed => returnedAt == null;

  @override
  String toString() {
    return 'BorrowHistory(id: $id, isbn: $isbn, bookTitle: $bookTitle, '
        'borrowerName: $borrowerName, classId: $classId, className: $className, '
        'borrowedAt: $borrowedAt, returnedAt: $returnedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorrowHistory &&
        other.id == id &&
        other.isbn == isbn &&
        other.bookTitle == bookTitle &&
        other.borrowerName == borrowerName &&
        other.classId == classId &&
        other.className == className &&
        other.borrowedAt == borrowedAt &&
        other.returnedAt == returnedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        isbn.hashCode ^
        bookTitle.hashCode ^
        borrowerName.hashCode ^
        classId.hashCode ^
        className.hashCode ^
        borrowedAt.hashCode ^
        returnedAt.hashCode;
  }
}
