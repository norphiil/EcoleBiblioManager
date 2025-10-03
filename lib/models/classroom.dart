import 'package:flutter/foundation.dart';

/// Modèle représentant une classe scolaire
@immutable
class ClassRoom {
  final String id;
  final String name;

  const ClassRoom({
    required this.id,
    required this.name,
  });

  /// Constructeur depuis une Map (pour la BDD)
  factory ClassRoom.fromMap(Map<String, dynamic> map) {
    return ClassRoom(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }

  /// Convertir en Map (pour la BDD)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  /// Copier avec modifications
  ClassRoom copyWith({
    String? id,
    String? name,
  }) {
    return ClassRoom(
      id: id ?? this.id,
      name: name ?? this.name,
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
  String toString() => 'ClassRoom(id: $id, name: $name)';
}
