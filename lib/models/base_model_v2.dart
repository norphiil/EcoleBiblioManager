import 'change_log.dart';

/// Interface de base pour tous les modèles de données
abstract class BaseModel {
  Map<String, dynamic> toJson();

  String getId();

  DateTime? getLastModified();

  void setLastModified(DateTime dateTime);
}

/// Interface pour les objets avec suivi des changements robuste
/// Remplace Synchronizable avec une meilleure gestion du lifecycle
abstract class TrackedEntity extends BaseModel {
  // Timestamps du cycle de vie
  DateTime? get createdAt;
  DateTime? get updatedAt;
  DateTime? get deletedAt;

  // État de synchronisation
  bool get isDirty;
  bool get isDeleted => deletedAt != null;
  bool get isSynced;

  // Gestion du lifecycle
  void markAsDirty();
  void markAsSynced();
  void markAsDeleted(); // Soft delete
  void undelete(); // Restaurer d'une suppression

  // Changements tracés
  Map<String, dynamic> getChanges();
  List<ChangeLog> getChangeHistory();

  // Fusion intelligente (pour résoudre les conflits)
  TrackedEntity? mergeWith(TrackedEntity other);
}

/// Classe de base pour la gestion des erreurs
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  const AppException(this.message, {this.code, this.originalException});

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Ancien Synchronizable - conservé pour compatibilité
abstract class Synchronizable extends BaseModel {
  bool get isDirty;

  void markAsSynced();

  void markAsDirty();

  Map<String, dynamic> getChanges();
}
