import 'package:flutter/material.dart';
import 'dart:async';

/// Écran affiché pendant la synchronisation finale avant fermeture
class ClosingSyncScreen extends StatefulWidget {
  final Future<void> Function() onSync;
  
  const ClosingSyncScreen({
    Key? key,
    required this.onSync,
  }) : super(key: key);

  @override
  State<ClosingSyncScreen> createState() => _ClosingSyncScreenState();
}

class _ClosingSyncScreenState extends State<ClosingSyncScreen> with SingleTickerProviderStateMixin {
  bool _isSyncing = true;
  bool _hasError = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _performSync();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _performSync() async {
    try {
      await widget.onSync();
      
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        
        // Attendre un peu pour montrer le succès, puis fermer automatiquement
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(true); // Retourne true pour indiquer le succès
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Empêcher le retour arrière pendant la synchronisation
      onWillPop: () async => !_isSyncing,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône ou animation
                if (_isSyncing)
                  RotationTransition(
                    turns: _animationController,
                    child: Icon(
                      Icons.sync,
                      size: 80,
                      color: Colors.blue.shade600,
                    ),
                  )
                else if (_hasError)
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red.shade600,
                  )
                else
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green.shade600,
                  ),
                
                const SizedBox(height: 32),
                
                // Titre
                Text(
                  _isSyncing
                      ? 'Synchronisation en cours...'
                      : _hasError
                          ? 'Erreur de synchronisation'
                          : 'Synchronisation terminée',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Message
                Text(
                  _isSyncing
                      ? '⚠️ NE FERMEZ PAS L\'APPLICATION\nSynchronisation des données avec Google Sheets...'
                      : _hasError
                          ? 'Une erreur est survenue lors de la synchronisation.\nVos données locales sont sauvegardées.'
                          : 'Toutes vos données ont été synchronisées avec succès.\nL\'application va se fermer automatiquement.',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isSyncing ? Colors.orange.shade700 : Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                if (_hasError && _errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Barre de progression
                if (_isSyncing)
                  SizedBox(
                    width: 200,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                
                // Boutons d'action en cas d'erreur
                if (_hasError) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isSyncing = true;
                            _hasError = false;
                            _errorMessage = '';
                          });
                          _performSync();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(false); // Fermer sans sync
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Fermer quand même'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade600),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
