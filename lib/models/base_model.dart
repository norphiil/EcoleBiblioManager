/// Interface de base pour tous les modèles de données
abstract class BaseModel {
  Map<String, dynamic> toJson();
  
  String getId();
  
  DateTime? getLastModified();
  
  void setLastModified(DateTime dateTime);
}

/// Interface pour les objets synchronisables avec Google Sheets
abstract class Synchronizable extends BaseModel {
  bool get isDirty;
  
  void markAsSynced();
  
  void markAsDirty();
  
  Map<String, dynamic> getChanges();
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