import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../models/models.dart';

/// Écran pour scanner et ranger un livre dans la bibliothèque
class ScanToShelveScreen extends StatefulWidget {
  const ScanToShelveScreen({Key? key}) : super(key: key);

  @override
  State<ScanToShelveScreen> createState() => _ScanToShelveScreenState();
}

class _ScanToShelveScreenState extends State<ScanToShelveScreen> {
  Book? _scannedBook;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranger un livre'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
      ),
      body: _scannedBook == null ? _buildScanner() : _buildBookDetails(),
    );
  }

  Widget _buildScanner() {
    return PythonBarcodeScanner(
      onBarcodeDetected: _handleBarcodeScanned,
      onError: () {
        setState(() {
          _errorMessage = 'Erreur lors de l\'initialisation du scanner';
        });
      },
    );
  }

  Widget _buildBookDetails() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppConstants.paddingMedium),
            Text('Recherche des informations du livre...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppConstants.paddingSmall),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
          ],
          
          // Informations du livre
          _buildBookInfoCard(),
          
          const SizedBox(height: AppConstants.paddingMedium),
          
          // Boutons d'action
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBookInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations du livre',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            
            if (_scannedBook != null) ...[
              _buildInfoRow('Titre', _scannedBook!.title),
              _buildInfoRow('Auteur', _scannedBook!.author),
              _buildInfoRow('ISBN', _scannedBook!.isbn),
              if (_scannedBook!.publisher != null)
                _buildInfoRow('Éditeur', _scannedBook!.publisher!),
              if (_scannedBook!.publishYear != null)
                _buildInfoRow('Année de publication', _scannedBook!.publishYear!.toString()),
            ] else ...[
              const Text('Livre non trouvé dans les bases de données'),
              const SizedBox(height: AppConstants.paddingMedium),
              const Text('Vous pouvez saisir manuellement les informations.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_scannedBook != null) ...[
          ElevatedButton.icon(
            onPressed: _saveBook,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer et ranger'),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
        ],
        
        OutlinedButton.icon(
          onPressed: _editBookInfo,
          icon: const Icon(Icons.edit),
          label: Text(_scannedBook != null ? 'Modifier les informations' : 'Saisir manuellement'),
        ),
        
        const SizedBox(height: AppConstants.paddingSmall),
        
        TextButton.icon(
          onPressed: _scanAnother,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner un autre livre'),
        ),
      ],
    );
  }

  Future<void> _handleBarcodeScanned(String code) async {
    // Navigation immédiate vers l'écran de rangement avec l'ISBN scanné
    if (mounted) {
      context.push('${AppRoutes.shelveBook}?isbn=$code');
    }
  }

  void _saveBook() {
    // TODO: Implémenter la sauvegarde avec emplacement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité de sauvegarde à implémenter'),
      ),
    );
  }

  void _editBookInfo() {
    // TODO: Ouvrir l'écran d'édition
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Écran d\'édition à implémenter'),
      ),
    );
  }

  void _scanAnother() {
    setState(() {
      _scannedBook = null;
      _errorMessage = null;
    });
  }
}