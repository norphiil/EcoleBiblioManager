import '../../models/models.dart';
import 'api_client.dart';
import 'data_converter.dart';

/// Gère les opérations sur les livres
class BooksOperations {
  final GoogleSheetsApiClient _client;
  final String _sheetName;

  BooksOperations(this._client, this._sheetName);

  /// Récupère tous les livres
  Future<List<Book>> getAll() async {
    final data = await _client.call({
      'action': 'getAll',
      'sheet': _sheetName,
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la récupération');
    }

    final List<dynamic> rows = data['data'] ?? [];
    return rows.map((row) => DataConverter.toBook(row as Map<String, dynamic>)).toList();
  }

  /// Ajoute un livre
  Future<Book> add(Book book) async {
    final data = await _client.call({
      'action': 'add',
      'sheet': _sheetName,
      'params': {
        'data': DataConverter.fromBook(book),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de l\'ajout');
    }

    return DataConverter.toBook(data['data'] as Map<String, dynamic>);
  }

  /// Met à jour un livre
  Future<Book> update(Book book) async {
    final data = await _client.call({
      'action': 'update',
      'sheet': _sheetName,
      'params': {
        'id': book.isbn,
        'data': DataConverter.fromBook(book),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la mise à jour');
    }

    return DataConverter.toBook(data['data'] as Map<String, dynamic>);
  }

  /// Supprime un livre
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

  /// Recherche des livres
  Future<List<Book>> search(String field, String value) async {
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
    return rows.map((row) => DataConverter.toBook(row as Map<String, dynamic>)).toList();
  }
}
