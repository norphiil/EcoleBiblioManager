import '../../models/models.dart';
import 'api_client.dart';
import 'data_converter.dart';

/// Opérations sur les élèves dans Google Sheets
class StudentsOperations {
  final GoogleSheetsApiClient _client;
  final String _sheetName;

  StudentsOperations(this._client, this._sheetName);

  /// Récupère tous les élèves
  Future<List<Student>> getAll() async {
    final data = await _client.call({
      'action': 'getAll',
      'sheet': _sheetName,
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la récupération');
    }

    final List<dynamic> rows = data['data'] ?? [];
    return rows.map((row) => DataConverter.toStudent(row as Map<String, dynamic>)).toList();
  }

  /// Récupère les élèves d'une classe
  Future<List<Student>> getByClassId(String classId) async {
    return search('classId', classId);
  }

  /// Ajoute un nouvel élève
  Future<Student> add(Student student) async {
    final data = await _client.call({
      'action': 'add',
      'sheet': _sheetName,
      'params': {
        'data': DataConverter.fromStudent(student),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de l\'ajout');
    }

    return DataConverter.toStudent(data['data'] as Map<String, dynamic>);
  }

  /// Ajoute plusieurs élèves
  Future<void> addMultiple(List<Student> students) async {
    for (final student in students) {
      await add(student);
    }
  }

  /// Met à jour un élève existant
  Future<Student> update(Student student) async {
    final data = await _client.call({
      'action': 'update',
      'sheet': _sheetName,
      'params': {
        'id': student.id,
        'data': DataConverter.fromStudent(student),
      },
    });

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Erreur lors de la mise à jour');
    }

    return DataConverter.toStudent(data['data'] as Map<String, dynamic>);
  }

  /// Supprime un élève
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

  /// Recherche des élèves
  Future<List<Student>> search(String field, String value) async {
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
    return rows.map((row) => DataConverter.toStudent(row as Map<String, dynamic>)).toList();
  }
}
