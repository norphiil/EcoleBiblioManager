import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../models/models.dart';

/// Écran pour scanner et emprunter un livre
class ScanToBorrowScreen extends StatefulWidget {
  const ScanToBorrowScreen({Key? key}) : super(key: key);

  @override
  State<ScanToBorrowScreen> createState() => _ScanToBorrowScreenState();
}

class _ScanToBorrowScreenState extends State<ScanToBorrowScreen> {
  Book? _scannedBook;
  String? _borrowerName;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prendre un livre'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _scannedBook == null ? _buildScanner() : _buildBorrowForm(),
    );
  }

  Widget _buildScanner() {
    return PythonBarcodeScanner(
      onBarcodeDetected: _handleBarcodeScanned,
      captureInterval: const Duration(milliseconds: 300), // Délai rapide
    );
  }

  Widget _buildBorrowForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Informations du livre
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Livre sélectionné',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppConstants.paddingSmall),
                  Text(
                    _scannedBook!.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'par ${_scannedBook!.author}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'ISBN: ${_scannedBook!.isbn}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppConstants.paddingMedium),
          
          // Formulaire d'emprunt
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations d\'emprunt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'emprunteur',
                      hintText: 'Saisissez le nom complet',
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _borrowerName = value;
                      });
                    },
                  ),
                  
                  const SizedBox(height: AppConstants.paddingMedium),
                  
                  Container(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: AppConstants.paddingSmall),
                        Expanded(
                          child: Text(
                            'Durée d\'emprunt: 14 jours\nDate de retour: ${DateTime.now().add(AppConstants.defaultLoanDuration).day}/${DateTime.now().add(AppConstants.defaultLoanDuration).month}/${DateTime.now().add(AppConstants.defaultLoanDuration).year}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppConstants.paddingLarge),
          
          // Boutons d'action
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _canConfirmBorrow() ? _confirmBorrow : null,
          icon: _isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isProcessing ? 'Enregistrement...' : 'Confirmer l\'emprunt'),
        ),
        
        const SizedBox(height: AppConstants.paddingSmall),
        
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _scanAnother,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner un autre livre'),
        ),
        
        const SizedBox(height: AppConstants.paddingSmall),
        
        TextButton.icon(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.home),
          label: const Text('Retour à l\'accueil'),
        ),
      ],
    );
  }

  bool _canConfirmBorrow() {
    return _borrowerName != null && 
           _borrowerName!.trim().isNotEmpty && 
           !_isProcessing;
  }

  void _handleBarcodeScanned(String code) {
    // TODO: Rechercher le livre dans la base de données locale
    setState(() {
      _scannedBook = Book(
        isbn: code,
        title: 'Livre scanné',
        author: 'Auteur du livre',
        status: BookStatus.available,
      );
    });
  }

  Future<void> _confirmBorrow() async {
    if (!_canConfirmBorrow()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // TODO: Enregistrer l'emprunt dans la base de données
      _scannedBook!.borrow(_borrowerName!.trim());
      
      // Afficher la confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Livre emprunté par ${_borrowerName!.trim()}'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        
        // Réinitialiser pour permettre un nouvel emprunt
        _scanAnother();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _scanAnother() {
    setState(() {
      _scannedBook = null;
      _borrowerName = null;
      _isProcessing = false;
    });
  }
}