import 'dart:io';

/// HttpOverrides that trust any certificate (optionally restricted to listed hosts).
/// Use only for troubleshooting environments with custom proxy certificates.
class InsecureHttpOverrides extends HttpOverrides {
  InsecureHttpOverrides({Set<String>? allowedHosts})
      : _allowedHosts = allowedHosts?.map((h) => h.toLowerCase()).toSet();

  final Set<String>? _allowedHosts;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      final hosts = _allowedHosts;
      if (hosts == null || hosts.isEmpty) {
        return true;
      }
      return hosts.contains(host.toLowerCase());
    };
    return client;
  }
}
