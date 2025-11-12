import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Service de logging persistant pour capturer tous les logs de l'application
/// Les logs sont sauvegardés dans un fichier pour diagnostic ultérieur
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  File? _logFile;
  final List<String> _memoryLogs = []; // Logs en mémoire comme backup
  static const int _maxMemoryLogs = 1000;
  bool _initialized = false;

  /// Initialise le service de logs
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Créer le dossier logs dans le répertoire de l'application
      final logsDir = Directory(path.join(Directory.current.path, 'logs'));
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Créer un fichier de log avec timestamp
      final now = DateTime.now();
      final logFileName = 'ebm_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.log';
      _logFile = File(path.join(logsDir.path, logFileName));

      // Écrire l'en-tête
      await _writeToFile('=' * 80);
      await _writeToFile('EBM - École Biblio Manager - Log Session');
      await _writeToFile('Démarrage: ${now.toString()}');
      await _writeToFile('=' * 80);
      await _writeToFile('');

      _initialized = true;
      debugPrint('✓ LogService initialisé: ${_logFile?.path}');
    } catch (e) {
      debugPrint('❌ Erreur initialisation LogService: $e');
    }
  }

  /// Pad un nombre avec un zéro si nécessaire
  String _pad(int number) => number.toString().padLeft(2, '0');

  /// Log un message avec un niveau de sévérité
  Future<void> log(String message, {LogLevel level = LogLevel.info}) async {
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:mm:ss
    final prefix = _getLevelPrefix(level);
    final logLine = '[$timestamp] $prefix $message';

    // Ajouter en mémoire
    _memoryLogs.add(logLine);
    if (_memoryLogs.length > _maxMemoryLogs) {
      _memoryLogs.removeAt(0);
    }

    // Écrire dans le fichier
    await _writeToFile(logLine);

    // Afficher dans la console en mode debug
    if (kDebugMode) {
      debugPrint(logLine);
    }
  }

  /// Obtient le préfixe selon le niveau
  String _getLevelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO] ';
      case LogLevel.warning:
        return '[WARN] ';
      case LogLevel.error:
        return '[ERROR]';
      case LogLevel.critical:
        return '[FATAL]';
    }
  }

  /// Écrit dans le fichier de log
  Future<void> _writeToFile(String line) async {
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString('$line\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('❌ Erreur écriture log: $e');
      }
    }
  }

  /// Log une erreur avec stack trace
  Future<void> logError(String message, Object? error, StackTrace? stackTrace) async {
    await log('ERROR: $message', level: LogLevel.error);
    if (error != null) {
      await log('  Exception: $error', level: LogLevel.error);
    }
    if (stackTrace != null) {
      await log('  Stack Trace:', level: LogLevel.error);
      final lines = stackTrace.toString().split('\n');
      for (final line in lines.take(10)) {
        // Limiter à 10 premières lignes
        await log('    $line', level: LogLevel.error);
      }
    }
  }

  /// Log le démarrage d'une opération
  Future<void> logOperation(String operation) async {
    await log('>>> $operation', level: LogLevel.info);
  }

  /// Log la fin d'une opération
  Future<void> logOperationEnd(String operation, {bool success = true}) async {
    final status = success ? '✓' : '✗';
    await log('<<< $operation $status', level: LogLevel.info);
  }

  /// Obtient tous les logs en mémoire
  List<String> getMemoryLogs() => List.unmodifiable(_memoryLogs);

  /// Obtient les derniers N logs
  List<String> getRecentLogs(int count) {
    final start = _memoryLogs.length > count ? _memoryLogs.length - count : 0;
    return _memoryLogs.sublist(start);
  }

  /// Obtient le chemin du fichier de log actuel
  String? getLogFilePath() => _logFile?.path;

  /// Obtient le contenu complet du fichier de log
  Future<String?> getLogFileContent() async {
    if (_logFile != null && await _logFile!.exists()) {
      try {
        return await _logFile!.readAsString();
      } catch (e) {
        debugPrint('❌ Erreur lecture log: $e');
      }
    }
    return null;
  }

  /// Liste tous les fichiers de logs disponibles
  Future<List<File>> getAllLogFiles() async {
    try {
      final logsDir = Directory(path.join(Directory.current.path, 'logs'));
      if (!await logsDir.exists()) {
        return [];
      }

      final files = await logsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // Trier par date de modification (plus récent en premier)
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('❌ Erreur listage logs: $e');
      return [];
    }
  }

  /// Supprime les anciens fichiers de logs (garde les 10 plus récents)
  Future<void> cleanOldLogs({int keepCount = 10}) async {
    try {
      final allLogs = await getAllLogFiles();
      if (allLogs.length > keepCount) {
        final toDelete = allLogs.sublist(keepCount);
        for (final file in toDelete) {
          await file.delete();
          debugPrint('🗑 Log supprimé: ${path.basename(file.path)}');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur nettoyage logs: $e');
    }
  }
}

/// Niveaux de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}
