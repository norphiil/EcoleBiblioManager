import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/home_screen.dart';
import '../../screens/scan_to_shelve_screen.dart';
import '../../screens/scan_to_borrow_screen.dart';
import '../../screens/search_book_screen.dart';
import '../../screens/book_info_screen.dart';
import '../../screens/shelve_book_screen.dart';
import '../../screens/groups_management_screen.dart';
import '../../screens/class_management_screen.dart';
import '../../screens/log_viewer_screen.dart';
import '../../models/book.dart';
import '../constants/app_constants.dart';

/// Configuration de la navigation de l'application
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      // Page d'accueil
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Scanner pour ranger un livre
      GoRoute(
        path: AppRoutes.scanToShelve,
        name: 'scan-to-shelve',
        builder: (context, state) => const ScanToShelveScreen(),
      ),
      
      // Scanner pour emprunter un livre
      GoRoute(
        path: AppRoutes.scanToBorrow,
        name: 'scan-to-borrow',
        builder: (context, state) => const ScanToBorrowScreen(),
      ),
      
      // Page de recherche de livre
      GoRoute(
        path: '/search-book',
        name: 'search-book',
        builder: (context, state) => const SearchBookScreen(),
      ),
      
      // Informations sur un livre
      GoRoute(
        path: AppRoutes.bookInfo,
        name: 'book-info',
        builder: (context, state) {
          final book = state.extra as Book?;
          return BookInfoScreen(book: book);
        },
      ),

      // Ranger un livre (avec ISBN optionnel)
      GoRoute(
        path: AppRoutes.shelveBook,
        name: 'shelve-book',
        builder: (context, state) {
          final isbn = state.uri.queryParameters['isbn'];
          return ShelveBookScreen(scannedIsbn: isbn);
        },
      ),
      
      // Détails d'un livre spécifique
      GoRoute(
        path: '${AppRoutes.bookDetails}/:bookId',
        name: 'book-details',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookDetailsScreen(bookId: bookId);
        },
      ),

      // Gestion des groupes
      GoRoute(
        path: AppRoutes.groupManagement,
        name: 'group-management',
        builder: (context, state) => const GroupsManagementScreen(),
      ),

      // Gestion des classes
      GoRoute(
        path: AppRoutes.classManagement,
        name: 'class-management',
        builder: (context, state) => const ClassManagementScreen(),
      ),

      // Visualiseur de logs (Debug)
      GoRoute(
        path: '/logs',
        name: 'logs',
        builder: (context, state) => const LogViewerScreen(),
      ),
    ],
    
    // Gestion des erreurs de navigation
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

/// Écran d'erreur de navigation
class ErrorScreen extends StatelessWidget {
  final GoException? error;

  const ErrorScreen({Key? key, this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erreur'),
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                'Page introuvable',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              Text(
                error?.toString() ?? 'Une erreur s\'est produite lors de la navigation',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingXLarge),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home),
                label: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran placeholder pour les détails d'un livre
class BookDetailsScreen extends StatelessWidget {
  final String bookId;

  const BookDetailsScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du livre'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Détails du livre',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text('ID: $bookId'),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran placeholder pour la gestion des utilisateurs
class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: const Center(
        child: Text('Écran de gestion des utilisateurs à implémenter'),
      ),
    );
  }
}

/// Écran placeholder pour les paramètres
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: const Center(
        child: Text('Écran des paramètres à implémenter'),
      ),
    );
  }
}