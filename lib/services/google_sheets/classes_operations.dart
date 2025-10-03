import '../../models/models.dart';
import 'api_client.dart';
import 'data_converter.dart';

/// Opérations sur les classes dans Google Sheets
class ClassesOperations {
  final GoogleSheetsApiClient _client;
  final String _sheetName;

  ClassesOperations(this._client, this._sheetName);

  /// Récupère toutes les classes
  Future<List<ClassRoom>> getAll() async {
    final data = await _client.call({
      'action': 'getAll',
      'sheet': _sheetName,
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la récupération');
    }

    final List<dynamic> rows = data['data'] ?? [];
    return rows.map((row) => DataConverter.toClassRoom(row as Map<String, dynamic>)).toList();
  }

  /// Ajoute une nouvelle classe
  Future<ClassRoom> add(ClassRoom classRoom) async {
    final data = await _client.call({
      'action': 'add',
      'sheet': _sheetName,
      'params': {
        'data': DataConverter.fromClassRoom(classRoom),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de l\'ajout');
    }

    return DataConverter.toClassRoom(data['data'] as Map<String, dynamic>);
  }

  /// Met à jour une classe existante
  Future<ClassRoom> update(ClassRoom classRoom) async {
    final data = await _client.call({
      'action': 'update',
      'sheet': _sheetName,
      'params': {
        'id': classRoom.id,
        'data': DataConverter.fromClassRoom(classRoom),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la mise à jour');
    }

    return DataConverter.toClassRoom(data['data'] as Map<String, dynamic>);
  }

  /// Supprime une classe
  Future<void> delete(String id) async {
    final data = await _client.call({
      'action': 'delete',
      'sheet': _sheetName,
      'params': {'id': id},
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la suppression');
    }
  }

  /// Recherche des classes
  Future<List<ClassRoom>> search(String field, String value) async {
    final data = await _client.call({
      'action': 'search',
      'sheet': _sheetName,
      'params': {
        'field': field,
        'value': value,
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la recherche');
    }

    final List<dynamic> rows = data['data'] ?? [];
    return rows.map((row) => DataConverter.toClassRoom(row as Map<String, dynamic>)).toList();
  }
}
