import 'package:flutter/foundation.dart';
import 'student.dart';

/// Modèle représentant une classe scolaire
@immutable
class ClassRoom {
  final String id;
  final String name;
  final List<Student> students;

  const ClassRoom({
    required this.id,
    required this.name,
    this.students = const [],
  });

  /// Constructeur depuis une Map (pour la BDD)
  factory ClassRoom.fromMap(Map<String, dynamic> map) {
    return ClassRoom(
      id: map['id'] as String,
      name: map['name'] as String,
      students: const [],
    );
  }

  /// Convertir en Map (pour la BDD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Constructeur depuis Supabase JSON
  factory ClassRoom.fromSupabaseJson(Map<String, dynamic> json) {
    return ClassRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      students: const [],
    );
  }

  /// Convertit en JSON pour Supabase
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Copier avec modifications
  ClassRoom copyWith({
    String? id,
    String? name,
    List<Student>? students,
  }) {
    return ClassRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      students: students ?? this.students,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassRoom && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ClassRoom(id: $id, name: $name, students: ${students.length})';
}
