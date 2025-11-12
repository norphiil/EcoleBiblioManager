import 'package:flutter/foundation.dart';

/// Modèle représentant un élève d'une classe
@immutable
class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String classId;

  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.classId,
  });

  /// Retourne le nom complet de l'élève
  String get fullName => '$firstName $lastName';

  /// Retourne le nom au format "Nom Prénom"
  String get displayName => '$lastName $firstName';

  /// Constructeur depuis une Map (pour la BDD)
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      classId: map['classId'] as String,
    );
  }

  /// Convertir en Map (pour la BDD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'classId': classId,
    };
  }

  /// Constructeur depuis Supabase JSON
  factory Student.fromSupabaseJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      classId: json['class_id'] as String? ?? '',
    );
  }

  /// Convertit en JSON pour Supabase
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'class_id': classId.isEmpty ? null : classId,
    };
  }

  /// Copier avec modifications
  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? classId,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      classId: classId ?? this.classId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Student && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Student(id: $id, firstName: $firstName, lastName: $lastName, classId: $classId)';
}
