import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/network/insecure_http_overrides.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/services.dart';
import 'services/supabase/supabase_service.dart';
import 'services/log_service.dart';
import 'screens/initialization_screen.dart';
import 'widgets/app_exit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logService = LogService();
  await logService.initialize();
  _installDebugPrintHook(logService);

  await runZonedGuarded<Future<void>>(
    () async {
      await _bootstrapApplication(logService);
    },
    (error, stackTrace) {
      logService.logError('Erreur non capturée', error, stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!logService.isMirroringConsole) {
          unawaited(logService.log('[CONSOLE] $line', level: LogLevel.debug));
        }
        parent.print(zone, line);
      },
    ),
  );
}

Future<void> _bootstrapApplication(LogService logService) async {
  // Initialiser window_manager pour les plateformes desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await logService.log('=== APPLICATION DEMARREE ===', level: LogLevel.info);

  await _loadBundledCaCertificates(logService);

  // Charge les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
    await logService.log('Variables d\'environnement chargées');
    await logService.log('Mode DEBUG: ${AppConstants.isDebugMode}');
    await _configureSslOverridesIfNeeded(logService);
  } catch (e) {
    print('Erreur lors du chargement du fichier .env: $e');
    await logService.logError('Erreur chargement .env', e, null);
  }

  // Initialiser Supabase
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    await logService.log('✅ Supabase initialisé');
  } catch (e, stackTrace) {
    print('Erreur lors de l\'initialisation de Supabase: $e');
    await logService.log('SUPABASE_URL: ${dotenv.env['SUPABASE_URL'] ?? 'non défini'}');
    await logService.logError('Erreur initialisation Supabase', e, stackTrace);
  }

  runApp(const EBMApp());
}

Future<void> _loadBundledCaCertificates(LogService logService) async {
  const assetPath = 'assets/ca/lets-encrypt-r3.pem';
  try {
    final data = await rootBundle.load(assetPath);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );
    await logService.log(
      'Certificat TLS Let\'s Encrypt R3 injecté dans SecurityContext',
      level: LogLevel.info,
    );
  } on FlutterError {
    await logService.log(
      'Certificat TLS local introuvable ($assetPath), utilisation du store système',
      level: LogLevel.warning,
    );
  } catch (e, stackTrace) {
    await logService.logError(
      'Erreur lors du chargement du certificat TLS local',
      e,
      stackTrace,
    );
  }
}

Future<void> _configureSslOverridesIfNeeded(LogService logService) async {
  if (!AppConstants.allowInsecureSsl) {
    return;
  }

  final hosts = <String>{};
  for (final entry in AppConstants.insecureSslHosts) {
    final normalized = _normalizeHost(entry);
    if (normalized != null) {
      hosts.add(normalized);
    }
  }
  final supabaseHost = Uri.tryParse(dotenv.env['SUPABASE_URL'] ?? '')?.host;
  if (supabaseHost != null && supabaseHost.isNotEmpty) {
    hosts.add(supabaseHost);
  }

  HttpOverrides.global = InsecureHttpOverrides(
    allowedHosts: hosts.isEmpty ? null : hosts,
  );

  final scope = hosts.isEmpty ? 'toutes les destinations' : hosts.join(', ');
  await logService.log(
    '⚠️ Mode SSL permissif activé pour $scope',
    level: LogLevel.warning,
  );
}

String? _normalizeHost(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  Uri? uri;
  if (trimmed.contains('://')) {
    uri = Uri.tryParse(trimmed);
  } else if (trimmed.contains('/')) {
    uri = Uri.tryParse('https://$trimmed');
  }

  if (uri != null) {
    if (uri.host.isNotEmpty) {
      return uri.host;
    }
    if (uri.authority.isNotEmpty) {
      return uri.authority;
    }
  }

  return trimmed;
}

class EBMApp extends StatelessWidget {
  const EBMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services de base
        Provider<DatabaseHelper>(
          create: (_) => DatabaseHelper(),
        ),
        Provider<BookApiService>(
          create: (_) => BookApiService(),
        ),
        Provider<BarcodeService>(
          create: (_) => BarcodeService(),
        ),
        Provider<SupabaseService>(
          create: (_) => SupabaseService(),
        ),
        
        // Service d'initialisation avec BDD locale
        ChangeNotifierProvider<InitializationService>(
          create: (context) => InitializationService(
            context.read<SupabaseService>(),
            context.read<DatabaseHelper>(),
          ),
        ),
        
        // Service de base de données locale (après initialisation)
        ProxyProvider<InitializationService, LocalDatabaseService?>(
          update: (_, initService, __) => 
            initService.isCompleted ? initService.localDbService : null,
        ),
        
        // Service de synchronisation complète (après initialisation)
        ProxyProvider<InitializationService, CompleteSyncService?>(
          update: (_, initService, __) => 
            initService.isCompleted ? initService.completeSyncService : null,
        ),
        
        // Service de base de données avec tracking automatique (après initialisation)
        ProxyProvider<DatabaseHelper, TrackedDatabaseService?>(
          update: (_, dbHelper, __) => TrackedDatabaseService(dbHelper),
        ),
      ],
      child: const EBMAppContent(),
    );
  }
}

class EBMAppContent extends StatelessWidget {
  const EBMAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InitializationService>(
      builder: (context, initService, child) {
        return MaterialApp(
          title: AppConstants.appName,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: initService.isCompleted 
              ? _buildMainApp() 
              : const InitializationScreen(),
        );
      },
    );
  }

  Widget _buildMainApp() {
    return AppExitHandler(
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

void _installDebugPrintHook(LogService logService) {
  final void Function(String? message, {int? wrapWidth})? originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && !logService.isMirroringConsole) {
      unawaited(
        logService.log('[CONSOLE] $message', level: LogLevel.debug),
      );
    }
    originalDebugPrint?.call(message, wrapWidth: wrapWidth);
  };
}