import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'services/services.dart';
import 'screens/initialization_screen.dart';
import 'widgets/app_exit_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charge les variables d'environnement
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Erreur lors du chargement du fichier .env: $e');
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
        Provider<GoogleSheetsService>(
          create: (_) => GoogleSheetsService(),
        ),
        
        // Service d'initialisation avec BDD locale
        ChangeNotifierProvider<InitializationService>(
          create: (context) => InitializationService(
            context.read<GoogleSheetsService>(),
            context.read<DatabaseHelper>(),
          ),
        ),
        
        // Service de base de données locale (après initialisation)
        ProxyProvider<InitializationService, LocalDatabaseService?>(
          update: (_, initService, __) => 
            initService.isCompleted ? initService.localDbService : null,
        ),
        
        // Service de synchronisation (après initialisation)
        ProxyProvider<InitializationService, SyncService?>(
          update: (_, initService, __) => 
            initService.isCompleted ? initService.syncService : null,
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