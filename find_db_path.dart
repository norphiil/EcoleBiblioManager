import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = await databaseFactory.getDatabasesPath();
  print('Chemin de la base de données: $dbPath');
  print('Fichier complet: ${join(dbPath, "ebm_local.db")}');
}
