import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/dynamic_color_scheme.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../widgets/books/book_info_card.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/database/database_helper.dart';

/// Écran pour scanner et emprunter un livre
class ScanToBorrowScreen extends StatefulWidget {
  const ScanToBorrowScreen({Key? key}) : super(key: key);

  @override
  State<ScanToBorrowScreen> createState() => _ScanToBorrowScreenState();
}

class _ScanToBorrowScreenState extends State<ScanToBorrowScreen> {
  late final LocalDatabaseService _localDbService;
  
  Book? _scannedBook;
  BookGroup? _bookGroup;
  String? _borrowerName;
  ClassRoom? _selectedClass;
  List<ClassRoom> _allClasses = [];
  bool _isProcessing = false;
  DynamicColorScheme? _currentColors; // Stocke les couleurs actuelles
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localDbService = context.read<LocalDatabaseService>();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await DatabaseHelper().getAllClasses();
      if (mounted) {
        setState(() {
          _allClasses = classes;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des classes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Créer le schéma de couleurs dynamique basé sur le groupe du livre
    final dynamicColors = _bookGroup != null
        ? DynamicColorScheme.fromGroupColor(_bookGroup!.groupColor)
        : DynamicColorScheme.fromColor(Theme.of(context).colorScheme.primary);
    
    // Stocker pour utilisation dans les méthodes
    _currentColors = dynamicColors;

    return DynamicThemeProvider(
      colorScheme: dynamicColors,
      child: Builder(
        builder: (context) {
          final colors = context.dynamicColors;
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('Prendre un livre'),
              backgroundColor: colors.primaryColor,
              foregroundColor: colors.onPrimaryColor,
            ),
            body: _scannedBook == null ? _buildScanner() : _buildBorrowForm(colors),
          );
        },
      ),
    );
  }

  Widget _buildScanner() {
    return PythonBarcodeScanner(
      onBarcodeDetected: _handleBarcodeScanned,
      captureInterval: const Duration(milliseconds: 300), // Délai rapide
    );
  }

  Widget _buildBorrowForm(DynamicColorScheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Informations du livre
          BookInfoCard(
            book: _scannedBook!,
            showGroupInfo: _bookGroup != null,
            group: _bookGroup,
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
                  
                  DropdownButtonFormField<ClassRoom>(
                    decoration: const InputDecoration(
                      labelText: 'Classe (optionnelle)',
                      hintText: 'Sélectionnez une classe',
                      prefixIcon: Icon(Icons.school),
                    ),
                    value: _selectedClass,
                    items: [
                      const DropdownMenuItem<ClassRoom>(
                        value: null,
                        child: Text('Aucune classe'),
                      ),
                      ..._allClasses.map((classRoom) {
                        return DropdownMenuItem<ClassRoom>(
                          value: classRoom,
                          child: Text(classRoom.name),
                        );
                      }),
                    ],
                    onChanged: (ClassRoom? value) {
                      setState(() {
                        _selectedClass = value;
                      });
                    },
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

  Future<void> _handleBarcodeScanned(String code) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Rechercher le livre dans la base de données locale
      final results = await _localDbService.searchBooks('isbn', code);
      
      if (results.isEmpty) {
        // Livre NON référencé → Afficher erreur
        setState(() {
          _isProcessing = false;
        });
        
        // Afficher un dialog avec message clair
        if (mounted) {
          // Capturer le contexte de l'écran avant d'ouvrir le dialog
          final screenContext = context;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                  SizedBox(width: 12),
                  Text('Livre non référencé'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ce livre n\'est pas encore enregistré dans la bibliothèque.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _currentColors?.backgroundColor ?? Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _currentColors?.borderColor ?? Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _currentColors?.primaryColor ?? Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Veuillez d\'abord ranger ce livre en utilisant l\'option "Ranger un livre".',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Fermer le dialog
                    // Naviguer vers la page de rangement avec l'ISBN scanné en utilisant le contexte de l'écran
                    screenContext.push('${AppRoutes.shelveBook}?isbn=$code');
                  },
                  child: const Text('Aller ranger le livre'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Scanner un autre'),
                ),
              ],
            ),
          );
        }
      } else {
        // Livre trouvé → Continuer le processus d'emprunt
        final book = results.first;
        
        // Charger le groupe du livre si disponible
        BookGroup? group;
        if (book.groupId != null && book.groupId!.isNotEmpty) {
          try {
            final groups = await _localDbService.getAllBookGroups();
            group = groups.firstWhere((g) => g.id == book.groupId);
          } catch (e) {
            print('Groupe non trouvé pour le livre: $e');
          }
        }
        
        // Vérifier si le livre est disponible
        if (book.status != BookStatus.available) {
          setState(() {
            _isProcessing = false;
          });
          
          // Afficher un dialog détaillé si le livre est déjà emprunté
          if (mounted) {
            _showBookAlreadyBorrowedDialog(book);
          }
        } else {
          setState(() {
            _scannedBook = book;
            _bookGroup = group;
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<void> _confirmBorrow() async {
    if (!_canConfirmBorrow()) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Emprunter le livre
      _scannedBook!.borrow(
        _borrowerName!.trim(),
        className: _selectedClass?.name,
      );
      
      // Enregistrer dans la base de données locale
      await _localDbService.updateBook(_scannedBook!);
      
      // Créer un enregistrement dans l'historique
      final borrowHistory = BorrowHistory(
        isbn: _scannedBook!.isbn,
        bookTitle: _scannedBook!.title,
        borrowerName: _borrowerName!.trim(),
        classId: _selectedClass?.id,
        className: _selectedClass?.name,
        borrowedAt: DateTime.now(),
      );
      
      // Ajouter dans la base locale et récupérer l'ID généré
      final generatedId = await DatabaseHelper().addBorrowHistory(borrowHistory);
      
      // Créer une copie avec l'ID généré pour la synchronisation
      final borrowHistoryWithId = borrowHistory.copyWith(id: generatedId);
      
      // Synchroniser avec Google Sheets (en arrière-plan, sans bloquer l'utilisateur)
      _syncBorrowHistoryToSheets(borrowHistoryWithId);
      
      // Afficher la confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Livre emprunté par ${_borrowerName!.trim()}'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Réinitialiser pour permettre un nouvel emprunt
        _scanAnother();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red.shade600,
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

  /// Synchronise l'historique d'emprunt avec Google Sheets (en arrière-plan)
  Future<void> _syncBorrowHistoryToSheets(BorrowHistory history) async {
    try {
      final sheetsService = context.read<GoogleSheetsService>();
      await sheetsService.addBorrowHistory(history);
      print('✅ Historique synchronisé avec Google Sheets');
    } catch (e) {
      print('⚠️ Erreur de synchronisation avec Google Sheets: $e');
      // Ne pas bloquer l'utilisateur en cas d'erreur de synchronisation
    }
  }

  /// Affiche un dialog détaillé quand le livre est déjà emprunté
  void _showBookAlreadyBorrowedDialog(Book book) {
    final borrowedDate = book.borrowedDate;
    final borrowedDateStr = borrowedDate != null
        ? '${borrowedDate.day.toString().padLeft(2, '0')}/${borrowedDate.month.toString().padLeft(2, '0')}/${borrowedDate.year} à ${borrowedDate.hour.toString().padLeft(2, '0')}:${borrowedDate.minute.toString().padLeft(2, '0')}'
        : 'Date inconnue';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red.shade600, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Livre déjà emprunté',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre du livre
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.book, color: _currentColors?.primaryColor ?? Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            book.author,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Message principal
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Ce livre est actuellement emprunté',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Informations d'emprunt
                    _buildBorrowInfoRow('Emprunté par', book.borrowedBy ?? 'Inconnu'),
                    const SizedBox(height: 8),
                    if (book.borrowerClassName != null)
                      _buildBorrowInfoRow('Classe', book.borrowerClassName!),
                    if (book.borrowerClassName != null)
                      const SizedBox(height: 8),
                    _buildBorrowInfoRow('Date d\'emprunt', borrowedDateStr),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentColors?.backgroundColor ?? Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _currentColors?.borderColor ?? Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: _currentColors?.primaryColor ?? Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ce livre doit d\'abord être retourné et rangé avant de pouvoir être emprunté à nouveau.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK, compris'),
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher une ligne d'information d'emprunt
  Widget _buildBorrowInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _scanAnother() {
    setState(() {
      _scannedBook = null;
      _bookGroup = null;
      _borrowerName = null;
      _selectedClass = null;
      _isProcessing = false;
    });
  }
}