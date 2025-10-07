import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/services.dart';
import '../services/full_sync_service.dart';

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

class _AppExitHandlerState extends State<AppExitHandler> {
  bool _isSyncing = false;
  
  Future<bool> _onWillPop() async {
    if (_isSyncing) {
      // Ne pas permettre la fermeture pendant la sync
      return false;
    }
    
    // Afficher le dialog de synchronisation
    final shouldExit = await _showSyncDialog();
    return shouldExit ?? false;
  }

  Future<bool?> _showSyncDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Empêcher la fermeture par clic extérieur
      builder: (context) => _SyncDialog(
        onSyncComplete: () {
          setState(() {
            _isSyncing = false;
          });
        },
      ),
    );
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
      final sheetsService = context.read<GoogleSheetsService>();
      
      final syncService = FullSyncService(dbHelper, sheetsService);
      
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
