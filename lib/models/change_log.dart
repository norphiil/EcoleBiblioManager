import 'package:flutter/foundation.dart';

/// Énumération des types d'opérations
enum ChangeOperation {
  create('create'),
  update('update'),
  delete('delete');

  const ChangeOperation(this.value);
  final String value;

  static ChangeOperation fromString(String str) {
    switch (str.toLowerCase()) {
      case 'create':
        return ChangeOperation.create;
      case 'update':
        return ChangeOperation.update;
      case 'delete':
        return ChangeOperation.delete;
      default:
        return ChangeOperation.update;
    }
  }

  @override
  String toString() => value;
}

/// Modèle pour tracker un changement dans la base de données
/// Utilisé pour la synchronisation intelligente
@immutable
class ChangeLog {
  final String? id; // UUID
  final String entityType; // 'book', 'student', 'class', 'group'
  final String entityId; // isbn, id, key, etc
  final ChangeOperation operation; // create, update, delete
  final Map<String, dynamic>? changes; // {field: "old -> new"}
  final DateTime createdAt;
  final bool synced;
  final DateTime? syncedAt;

  const ChangeLog({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    this.changes,
    required this.createdAt,
    this.synced = false,
    this.syncedAt,
  });

  /// Constructeur depuis Map (BDD)
  factory ChangeLog.fromMap(Map<String, dynamic> map) {
    return ChangeLog(
      id: map['id'] as String?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operation: ChangeOperation.fromString(map['operation'] as String),
      changes: map['changes'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: map['synced'] as bool? ?? false,
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at'] as String) : null,
    );
  }

  /// Convertir en Map (BDD)
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.toString(),
      'changes': changes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  /// Constructeur depuis Supabase JSON
  factory ChangeLog.fromSupabaseJson(Map<String, dynamic> json) {
    return ChangeLog(
      id: json['id'] as String?,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      operation: ChangeOperation.fromString(json['operation'] as String),
      changes: json['changes'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      synced: json['synced'] as bool? ?? false,
      syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at'] as String) : null,
    );
  }

  /// Convertir en JSON pour Supabase
  Map<String, dynamic> toSupabaseJson() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.toString(),
      'changes': changes,
    };
  }

  /// Copier avec modifications
  ChangeLog copyWith({
    String? id,
    String? entityType,
    String? entityId,
    ChangeOperation? operation,
    Map<String, dynamic>? changes,
    DateTime? createdAt,
    bool? synced,
    DateTime? syncedAt,
  }) {
    return ChangeLog(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      changes: changes ?? this.changes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() =>
      'ChangeLog($entityType:$entityId $operation at $createdAt${synced ? " (synced)" : ""})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChangeLog &&
        other.id == id &&
        other.entityType == entityType &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => id.hashCode ^ entityType.hashCode ^ entityId.hashCode;
}
