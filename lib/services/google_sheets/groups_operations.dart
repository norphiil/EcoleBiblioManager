import '../../models/models.dart';
import 'api_client.dart';
import 'data_converter.dart';

/// Gère les opérations sur les groupes
class GroupsOperations {
  final GoogleSheetsApiClient _client;
  final String _sheetName;

  GroupsOperations(this._client, this._sheetName);

  /// Récupère tous les groupes
  Future<List<BookGroup>> getAll() async {
    final data = await _client.call({
      'action': 'getAll',
      'sheet': _sheetName,
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la récupération');
    }

    final List<dynamic> rows = data['data'] ?? [];
    return rows.map((row) => DataConverter.toBookGroup(row as Map<String, dynamic>)).toList();
  }

  /// Ajoute un groupe
  Future<BookGroup> add(BookGroup group) async {
    final data = await _client.call({
      'action': 'add',
      'sheet': _sheetName,
      'params': {
        'data': DataConverter.fromBookGroup(group),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de l\'ajout');
    }

    return DataConverter.toBookGroup(data['data'] as Map<String, dynamic>);
  }

  /// Met à jour un groupe
  Future<BookGroup> update(BookGroup group) async {
    final data = await _client.call({
      'action': 'update',
      'sheet': _sheetName,
      'params': {
        'id': group.id,
        'data': DataConverter.fromBookGroup(group),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la mise à jour');
    }

    return DataConverter.toBookGroup(data['data'] as Map<String, dynamic>);
  }

  /// Supprime un groupe
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

  /// Recherche des groupes
  Future<List<BookGroup>> search(String field, String value) async {
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
    return rows.map((row) => DataConverter.toBookGroup(row as Map<String, dynamic>)).toList();
  }
}
