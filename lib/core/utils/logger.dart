import 'package:flutter/foundation.dart';

/// Simple logger pour l'application
class Logger {
  final String _tag;

  Logger(this._tag);

  void info(String message) {
    debugPrint('[INFO][$_tag] $message');
  }

  void warning(String message, [dynamic error]) {
    debugPrint('[WARNING][$_tag] $message${error != null ? ' - Error: $error' : ''}');
  }

  void error(String message, [dynamic error]) {
    debugPrint('[ERROR][$_tag] $message${error != null ? ' - Error: $error' : ''}');
  }

  void debug(String message) {
    debugPrint('[DEBUG][$_tag] $message');
  }
}