import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../widgets/common/action_card.dart';

/// Page d'accueil principale de l'application
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.homeScreenKey,
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        actions: [
          // Menu paramètres
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Paramètres',
            onSelected: (value) {
              if (value == 'groups') {
                context.go(AppRoutes.groupManagement);
              } else if (value == 'classes') {
                context.go(AppRoutes.classManagement);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'groups',
                child: Row(
                  children: [
                    Icon(Icons.folder, size: 20),
                    SizedBox(width: 12),
                    Text('Gestion des groupes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'classes',
                child: Row(
                  children: [
                    Icon(Icons.school, size: 20),
                    SizedBox(width: 12),
                    Text('Gestion des classes'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête avec message de bienvenue
                _buildWelcomeHeader(context),
                
                const SizedBox(height: AppConstants.paddingXLarge),
                
                // Actions principales
                Expanded(
                  child: _buildMainActions(context),
                ),
                
                // Informations de version (optionnel)
                _buildVersionInfo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            Icon(
              Icons.school,
              size: AppConstants.iconSizeXLarge,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Bienvenue dans la bibliothèque !',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Que souhaitez-vous faire aujourd\'hui ?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return GridView.count(
      crossAxisCount: _getCrossAxisCount(context),
      crossAxisSpacing: AppConstants.paddingMedium,
      mainAxisSpacing: AppConstants.paddingMedium,
      children: [
        ActionCard(
          key: AppKeys.shelveBookButtonKey,
          title: 'Ranger un livre',
          subtitle: 'Enregistrer et placer un livre dans la bibliothèque',
          icon: Icons.add_box,
          color: Theme.of(context).colorScheme.secondary,
          onTap: () => context.push(AppRoutes.scanToShelve),
        ),
        
        ActionCard(
          key: AppKeys.borrowBookButtonKey,
          title: 'Prendre un livre',
          subtitle: 'Scanner un livre pour l\'emprunter',
          icon: Icons.book,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => context.push(AppRoutes.scanToBorrow),
        ),
        
        ActionCard(
          key: AppKeys.bookInfoButtonKey,
          title: 'Rechercher un livre',
          subtitle: 'Rechercher ou scanner un livre',
          icon: Icons.search,
          color: Theme.of(context).colorScheme.tertiary,
          onTap: () => context.push('/search-book'),
        ),
        
      ],
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingMedium),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Détermine le nombre de colonnes en fonction de la taille de l'écran
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 2;
  }
}