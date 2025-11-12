import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/services.dart';
import '../services/supabase/supabase_service.dart';
import '../services/full_sync_service.dart';
import '../screens/closing_sync_screen.dart';

/// Widget qui intercepte la fermeture de l'application et lance la synchronisation
class AppExitHandler extends StatefulWidget {
  final Widget child;
  
  const AppExitHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<AppExitHandler> createState() => _AppExitHandlerState();
}

class _AppExitHandlerState extends State<AppExitHandler> 
    with WidgetsBindingObserver, WindowListener {
  bool _isSyncing = false;
  bool _appIsClosing = false;
  
  @override
  void initState() {
    super.initState();
    // Enregistrer l'observateur du cycle de vie
    WidgetsBinding.instance.addObserver(this);
    
    // Enregistrer le listener pour la fenêtre (Desktop uniquement)
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      // CRITIQUE: Activer la prévention de fermeture dès le départ
      _setupWindowCloseHandler();
    }
  }
  
  /// Configure la gestion de la fermeture de fenêtre
  Future<void> _setupWindowCloseHandler() async {
    // Empêcher la fermeture par défaut dès le démarrage
    await windowManager.setPreventClose(true);
    print('🔒 Prévention de fermeture activée - toutes les fermetures passeront par onWindowClose()');
  }
  
  @override
  void dispose() {
    // Supprimer l'observateur pour éviter les fuites mémoire
    WidgetsBinding.instance.removeObserver(this);
    
    // Supprimer le listener de fenêtre
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    
    super.dispose();
  }
  
  // ========== WindowListener pour Desktop ==========
  
  @override
  Future<void> onWindowClose() async {
    // Cette méthode est appelée quand l'utilisateur clique sur le X
    print('🔴 Tentative de fermeture de la fenêtre détectée');
    
    if (_isSyncing) {
      print('⚠️ Synchronisation en cours, fermeture bloquée');
      return;
    }
    
    // Empêcher la fermeture par défaut
    await windowManager.setPreventClose(true);
    print('🛑 Fermeture bloquée, affichage de l\'écran de synchronisation...');
    
    // Lancer la synchronisation avec l'écran dédié
    final shouldClose = await _onWillPop();
    
    print('📋 Résultat de la synchronisation: shouldClose=$shouldClose');
    
    if (shouldClose) {
      // Autoriser la fermeture et détruire la fenêtre
      print('✅ Fermeture autorisée, destruction de la fenêtre...');
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } else {
      // L'utilisateur a annulé, réactiver la prévention
      print('❌ Fermeture annulée par l\'utilisateur');
    }
  }
  
  @override
  void onWindowFocus() {
    // Optionnel: faire quelque chose quand la fenêtre reçoit le focus
  }
  
  @override
  void onWindowBlur() {
    // Optionnel: faire quelque chose quand la fenêtre perd le focus
  }
  
  @override
  void onWindowMaximize() {
    // Optionnel
  }
  
  @override
  void onWindowUnmaximize() {
    // Optionnel
  }
  
  @override
  void onWindowMinimize() {
    // Optionnel
  }
  
  @override
  void onWindowRestore() {
    // Optionnel
  }
  
  @override
  void onWindowResize() {
    // Optionnel
  }
  
  @override
  void onWindowMove() {
    // Optionnel
  }
  
  @override
  void onWindowEnterFullScreen() {
    // Optionnel
  }
  
  @override
  void onWindowLeaveFullScreen() {
    // Optionnel
  }
  
  @override
  void onWindowEvent(String eventName) {
    // Optionnel: pour capturer tous les événements
    print('[WindowEvent] $eventName');
  }
  
  @override
  void onWindowDocked() {
    // Optionnel
  }
  
  @override
  void onWindowUndocked() {
    // Optionnel
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Détecter quand l'application passe en arrière-plan ou se ferme
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (!_isSyncing && !_appIsClosing) {
        // Lancer la synchronisation automatique
        _performBackgroundSync();
      }
    }
  }
  
  /// Synchronisation automatique en arrière-plan (sans dialog)
  Future<void> _performBackgroundSync() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      print('🔄 Synchronisation automatique en cours...');
      final completeSyncService = context.read<CompleteSyncService?>();
      
      if (completeSyncService != null) {
        await completeSyncService.performShutdownSync();
        print('✅ Synchronisation automatique terminée');
      } else {
        print('⚠️ CompleteSyncService non disponible');
      }
    } catch (e) {
      print('❌ Erreur synchronisation automatique: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
  
  Future<bool> _onWillPop() async {
    if (_isSyncing) {
      // Ne pas permettre la fermeture pendant la sync
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Synchronisation en cours, veuillez patienter...'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }
    
    // Marquer que l'app est en cours de fermeture
    setState(() {
      _appIsClosing = true;
    });
    
    // Afficher l'écran de synchronisation de fermeture
    final shouldExit = await _showSyncScreen();
    
    if (!shouldExit) {
      setState(() {
        _appIsClosing = false;
      });
    }
    
    return shouldExit;
  }

  Future<bool> _showSyncScreen() async {
    setState(() {
      _isSyncing = true;
    });
    
    try {
      // Naviguer vers l'écran de synchronisation en mode fullscreen
      final result = await Navigator.of(context).push<bool>(
        PageRouteBuilder(
          opaque: true,
          barrierDismissible: false,
          pageBuilder: (context, _, __) => ClosingSyncScreen(
            onSync: () async {
              final completeSyncService = context.read<CompleteSyncService?>();
              
              if (completeSyncService == null) {
                print('⚠️ CompleteSyncService non disponible');
                return;
              }
              
              // PHASE 3: Synchronisation à la fermeture
              print('� Lancement de la synchronisation shutdown...');
              await completeSyncService.performShutdownSync();
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      
      return result ?? false;
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser PopScope (Flutter 3.12+) pour intercepter le bouton retour/fermeture
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldExit = await _onWillPop();
        if (shouldExit) {
          // Fermer l'application après la sync
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
            exit(0);
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: widget.child,
    );
  }
}

/// Dialog qui affiche la progression de la synchronisation
class _SyncDialog extends StatefulWidget {
  final VoidCallback onSyncComplete;
  
  const _SyncDialog({
    required this.onSyncComplete,
  });

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  String _currentStep = 'Préparation...';
  bool _isComplete = false;
  bool _hasErrors = false;
  String? _errorMessage;
  int _totalSynced = 0;
  
  @override
  void initState() {
    super.initState();
    _startSync();
  }

  Future<void> _startSync() async {
    try {
      final dbHelper = context.read<DatabaseHelper>();
      final supabaseService = context.read<SupabaseService>();
      
      final syncService = FullSyncService(dbHelper, supabaseService);
      
      final result = await syncService.syncAllToSheets(
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _currentStep = message;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _isComplete = true;
          _hasErrors = result.hasErrors;
          _totalSynced = result.totalSynced;
          
          if (result.hasErrors) {
            _errorMessage = 'Quelques erreurs se sont produites';
          }
        });
        
        // Attendre 1.5 secondes pour montrer le résultat, puis fermer
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (mounted) {
          widget.onSyncComplete();
          Navigator.of(context).pop(true); // Autoriser la fermeture
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isComplete = true;
          _hasErrors = true;
          _errorMessage = 'Erreur: $e';
        });
        
        // Attendre avant de fermer même en cas d'erreur
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          widget.onSyncComplete();
          Navigator.of(context).pop(true); // Autoriser la fermeture malgré l'erreur
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            if (!_isComplete)
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                ),
              )
            else if (_hasErrors)
              Icon(
                Icons.warning_amber_rounded,
                size: 60,
                color: Colors.orange.shade600,
              )
            else
              Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.green.shade600,
              ),
            
            const SizedBox(height: 24),
            
            // Titre
            Text(
              _isComplete 
                  ? (_hasErrors ? 'Synchronisation terminée avec des erreurs' : 'Synchronisation terminée !')
                  : 'Synchronisation en cours...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Message
            Text(
              _isComplete 
                  ? (_errorMessage ?? '$_totalSynced éléments synchronisés')
                  : _currentStep,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Note en bas
            if (!_isComplete)
              Text(
                'Veuillez patienter...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
