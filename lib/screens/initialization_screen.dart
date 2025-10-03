import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../services/initialization_service.dart';

/// Écran d'initialisation de l'application
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    _animationController.forward();
    
    // Lance l'initialisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initService = context.read<InitializationService>();
      if (!initService.isCompleted && !initService.hasError) {
        initService.initialize();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Consumer<InitializationService>(
        builder: (context, initService, child) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                            (AppConstants.paddingLarge * 2) - 
                            MediaQuery.of(context).padding.top - 
                            MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Logo et titre animés
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(60),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.library_books,
                              size: 60,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingLarge),
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppConstants.paddingSmall),
                          Text(
                            'Gestionnaire de bibliothèque',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppConstants.paddingLarge * 2),
                  
                  // Indicateur de progression
                  _buildProgressIndicator(initService),
                  
                  const SizedBox(height: AppConstants.paddingLarge),
                  
                  // Statut et étape courante
                  _buildStatusInfo(initService),
                  
                  const SizedBox(height: AppConstants.paddingLarge),
                  
                  // Bouton d'action (en cas d'erreur)
                  if (initService.hasError) _buildRetryButton(initService),
                ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(InitializationService initService) {
    return Column(
      children: [
        // Barre de progression circulaire
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: initService.hasError ? null : initService.progress,
                strokeWidth: 6,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  initService.hasError ? Colors.red : Colors.white,
                ),
              ),
              Center(
                child: Text(
                  initService.hasError 
                      ? '!' 
                      : '${(initService.progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: AppConstants.paddingMedium),
        
        // Barre de progression linéaire
        Container(
          width: double.infinity,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: initService.hasError ? 1.0 : initService.progress,
            child: Container(
              decoration: BoxDecoration(
                color: initService.hasError ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusInfo(InitializationService initService) {
    return Column(
      children: [
        // Étape courante
        Text(
          initService.currentStep.isNotEmpty 
              ? initService.currentStep 
              : 'Préparation...',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        
        // Message d'erreur si nécessaire
        if (initService.hasError && initService.errorMessage != null) ...[
          const SizedBox(height: AppConstants.paddingMedium),
          Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        'Erreur d\'initialisation',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                Text(
                  initService.errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Message de succès
        if (initService.isCompleted) ...[
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: AppConstants.paddingSmall),
              Text(
                'Initialisation terminée !',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRetryButton(InitializationService initService) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => initService.retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge,
                  vertical: AppConstants.paddingMedium,
                ),
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            OutlinedButton.icon(
              onPressed: () => _showConfigurationHelp(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('Aide'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge,
                  vertical: AppConstants.paddingMedium,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showConfigurationHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration Google Sheets'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour résoudre les erreurs de permissions :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Aller sur console.cloud.google.com'),
              Text('2. Créer ou sélectionner un projet'),
              Text('3. Activer l\'API "Google Sheets API"'),
              Text('4. Créer une clé API'),
              SizedBox(height: 16),
              Text('5. Dans votre Google Sheets :'),
              Text('   • Cliquer sur "Partager"'),
              Text('   • Sélectionner "Toute personne ayant le lien peut modifier"'),
              SizedBox(height: 16),
              Text('6. Vérifier le fichier .env avec :'),
              Text('   • GOOGLE_SHEET_API=votre_clé_api'),
              Text('   • SPREADSHEET_ID=id_de_votre_feuille'),
              SizedBox(height: 16),
              Text(
                'Consultez le fichier .env.example pour plus de détails.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}