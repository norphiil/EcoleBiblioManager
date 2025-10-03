import '../../models/models.dart';
import 'api_client.dart';
import 'data_converter.dart';

/// Opérations CRUD pour l'historique des emprunts dans Google Sheets
class BorrowHistoryOperations {
  final GoogleSheetsApiClient _client;
  final String _sheetName;

  BorrowHistoryOperations(this._client, this._sheetName);

  /// Récupère tous les enregistrements d'historique
  Future<List<BorrowHistory>> getAll() async {
    final response = await _client.call({
      'action': 'getAll',
      'sheet': _sheetName,
    });

    if (response['status'] != 'success') {
      throw Exception(response['message']);
    }

    final data = response['data'] as List;
    return data.map((row) => DataConverter.toBorrowHistory(row)).toList();
  }

  /// Ajoute un enregistrement d'historique
  Future<BorrowHistory> add(BorrowHistory history) async {
    final response = await _client.call({
      'action': 'add',
      'sheet': _sheetName,
      'params': DataConverter.fromBorrowHistory(history),
    });

    if (response['status'] != 'success') {
      throw Exception(response['message']);
    }

    return DataConverter.toBorrowHistory(response['data']);
  }

  /// Met à jour un enregistrement d'historique
  Future<BorrowHistory> update(BorrowHistory history) async {
    final response = await _client.call({
      'action': 'update',
      'sheet': _sheetName,
      'params': {
        'id': history.id,
        'data': DataConverter.fromBorrowHistory(history),
      },
    });

    if (response['status'] != 'success') {
      throw Exception(response['message']);
    }

    return DataConverter.toBorrowHistory(response['data']);
  }

  /// Supprime un enregistrement d'historique
  Future<void> delete(String id) async {
    final response = await _client.call({
      'action': 'delete',
      'sheet': _sheetName,
      'params': {'id': id},
    });

    if (response['status'] != 'success') {
      throw Exception(response['message']);
    }
  }

  /// Recherche dans l'historique
  Future<List<BorrowHistory>> search(String field, String value) async {
    final response = await _client.call({
      'action': 'search',
      'sheet': _sheetName,
      'params': {field: value},
    });

    if (response['status'] != 'success') {
      throw Exception(response['message']);
    }

    final data = response['data'] as List;
    return data.map((row) => DataConverter.toBorrowHistory(row)).toList();
  }

  /// Récupère l'historique pour un livre spécifique (par ISBN)
  Future<List<BorrowHistory>> getByIsbn(String isbn) async {
    return search('isbn', isbn);
  }

  /// Récupère l'historique pour une classe spécifique
  Future<List<BorrowHistory>> getByClassId(String classId) async {
    return search('classId', classId);
  }
}
