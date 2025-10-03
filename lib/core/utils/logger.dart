/// Simple logger pour l'application
class Logger {
  final String _tag;

  Logger(this._tag);

  void info(String message) {
    print('[INFO][$_tag] $message');
  }

  void warning(String message, [dynamic error]) {
    print('[WARNING][$_tag] $message${error != null ? ' - Error: $error' : ''}');
  }

  void error(String message, [dynamic error]) {
    print('[ERROR][$_tag] $message${error != null ? ' - Error: $error' : ''}');
  }

  void debug(String message) {
    print('[DEBUG][$_tag] $message');
  }
}