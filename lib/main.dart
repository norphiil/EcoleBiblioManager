import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/services.dart';
import 'services/supabase/supabase_service.dart';
import 'services/log_service.dart';
import 'screens/initialization_screen.dart';
import 'widgets/app_exit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser window_manager pour les plateformes desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    // Configuration de la fenêtre
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
  
  // Initialiser le service de logs
  final logService = LogService();
  await logService.initialize();
  await logService.log('=== APPLICATION DEMARREE ===', level: LogLevel.info);
  
  // Charge les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
    await logService.log('Variables d\'environnement chargées');
    await logService.log('Mode DEBUG: ${AppConstants.isDebugMode}');
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
  } catch (e) {
    print('Erreur lors de l\'initialisation de Supabase: $e');
    await logService.logError('Erreur initialisation Supabase', e, null);
  }
  
  runApp(const EBMApp());
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