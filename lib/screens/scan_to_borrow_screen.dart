import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/dynamic_color_scheme.dart';
import '../core/utils/error_handler.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../widgets/books/book_info_card.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/initialization_service.dart';
import '../services/database/database_helper.dart';

/// Écran pour scanner et emprunter un livre
class ScanToBorrowScreen extends StatefulWidget {
  const ScanToBorrowScreen({Key? key}) : super(key: key);

  @override
  State<ScanToBorrowScreen> createState() => _ScanToBorrowScreenState();
}

class _ScanToBorrowScreenState extends State<ScanToBorrowScreen> {
  late final LocalDatabaseService _localDbService;
  
  // Contrôleurs et états
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _borrowerController = TextEditingController();
  
  Book? _scannedBook;
  BookGroup? _bookGroup;
  String? _borrowerName;
  ClassRoom? _selectedClass;
  List<ClassRoom> _allClasses = [];
  List<Student> _filteredStudents = [];
  List<Book> _searchResults = [];
  bool _isProcessing = false;
  bool _isSearching = false;
  bool _showStudentSuggestions = false;
  DynamicColorScheme? _currentColors; // Stocke les couleurs actuelles
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localDbService = context.read<LocalDatabaseService>();
    _loadClasses();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _borrowerController.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await DatabaseHelper().getAllClasses();
      if (mounted) {
        setState(() {
          _allClasses = classes;
        });
      }
    } catch (e, stackTrace) {
      print('Erreur lors du chargement des classes: $e');
      if (mounted) {
        ErrorHandler.showCaughtError(
          context,
          message: 'Erreur lors du chargement des classes',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Filtre les élèves selon le texte saisi
  Future<void> _searchStudents(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredStudents = [];
      });
      return;
    }

    try {
      final allStudents = await DatabaseHelper().getAllStudents();
      final lowerQuery = query.toLowerCase();
      
      final results = allStudents
          .where((student) => 
              student.firstName.toLowerCase().contains(lowerQuery) ||
              student.lastName.toLowerCase().contains(lowerQuery) ||
              student.fullName.toLowerCase().contains(lowerQuery))
          .take(10)
          .toList();

      setState(() {
        _filteredStudents = results;
      });
    } catch (e) {
      print('Erreur lors de la recherche d\'élèves: $e');
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
            body: _scannedBook == null 
                ? _buildSearchOrScanMode(colors)
                : _buildBorrowForm(colors),
          );
        },
      ),
    );
  }

  /// Mode recherche + scanner au démarrage
  Widget _buildSearchOrScanMode(DynamicColorScheme colors) {
    return Column(
      children: [
        // Barre de recherche
        _buildSearchBar(),
        
        // Résultats ou scanner
        Expanded(
          child: _searchController.text.isEmpty
              ? _buildScanner()
              : _buildSearchResults(),
        ),
      ],
    );
  }

  /// Barre de recherche stylisée
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par titre ou scanner...',
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _searchController.text.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        onChanged: _searchBooks,
      ),
    );
  }

  /// Rechercher les livres par titre
  Future<void> _searchBooks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final allBooks = await _localDbService.getAllBooks();
      final lowerQuery = query.toLowerCase();
      
      final results = allBooks
          .where((book) => book.title.toLowerCase().contains(lowerQuery))
          .take(10)
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de recherche: $e')),
        );
      }
    }
  }

  /// Affichage des résultats de recherche
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun livre trouvé',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _buildSearchResultCard(book);
      },
    );
  }

  /// Carte de résultat de recherche
  Widget _buildSearchResultCard(Book book) {
    final isAvailable = book.status == BookStatus.available;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: ListTile(
        title: Text(book.title),
        subtitle: Text(book.author),
        trailing: Chip(
          label: Text(isAvailable ? 'Disponible' : 'Emprunté'),
          backgroundColor: isAvailable ? Colors.green.shade100 : Colors.orange.shade100,
          labelStyle: TextStyle(
            color: isAvailable ? Colors.green.shade700 : Colors.orange.shade700,
          ),
        ),
        enabled: isAvailable,
        onTap: isAvailable
            ? () {
                // Sélectionner le livre depuis la recherche
                _selectBookFromSearch(book);
              }
            : null,
      ),
    );
  }

  /// Sélectionner un livre depuis les résultats de recherche
  Future<void> _selectBookFromSearch(Book book) async {
    // Charger le groupe si disponible
    BookGroup? group;
    if (book.groupId != null && book.groupId!.isNotEmpty) {
      try {
        final groups = await _localDbService.getAllBookGroups();
        group = groups.firstWhere((g) => g.id == book.groupId);
      } catch (e) {
        print('Groupe non trouvé: $e');
      }
    }

    setState(() {
      _scannedBook = book;
      _bookGroup = group;
      _searchController.clear();
      _searchResults = [];
    });
  }

  /// Scanner avec PythonBarcodeScanner
  Widget _buildScanner() {
    return PythonBarcodeScanner(
      onBarcodeDetected: _handleBarcodeScanned,
      captureInterval: const Duration(milliseconds: 300),
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
                  
                  // Champ de recherche d'emprunteur avec autocomplétion
                  StatefulBuilder(
                    builder: (context, setState) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _borrowerController,
                          decoration: InputDecoration(
                            labelText: 'Nom de l\'emprunteur',
                            hintText: 'Saisissez le nom ou prénom',
                            prefixIcon: const Icon(Icons.person),
                            suffixIcon: _borrowerController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _borrowerController.clear();
                                      setState(() {
                                        _filteredStudents = [];
                                        _borrowerName = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _borrowerName = value;
                              if (value.isNotEmpty) {
                                _searchStudents(value);
                              } else {
                                _filteredStudents = [];
                              }
                            });
                          },
                        ),
                        
                        // Suggestions d'élèves
                        if (_filteredStudents.isNotEmpty && _borrowerController.text.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.person,
                                    color: Colors.blue.shade600,
                                  ),
                                  title: Text(student.fullName),
                                  subtitle: student.classId.isEmpty
                                      ? const Text(
                                          'Classe: Non assignée',
                                          style: TextStyle(fontSize: 12, color: Colors.orange),
                                        )
                                      : Text(
                                          'Classe: ${_allClasses.firstWhere((c) => c.id == student.classId, orElse: () => ClassRoom(id: '', name: 'Inconnue')).name}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                  onTap: () {
                                    setState(() {
                                      _borrowerController.text = student.fullName;
                                      _borrowerName = student.fullName;
                                      // Trouver et sélectionner automatiquement la classe de l'élève
                                      if (student.classId.isNotEmpty) {
                                        try {
                                          _selectedClass = _allClasses.firstWhere(
                                            (c) => c.id == student.classId,
                                          );
                                        } catch (e) {
                                          // Classe non trouvée, on garde la sélection actuelle
                                          print('Classe non trouvée pour l\'élève ${student.fullName}');
                                        }
                                      }
                                      _filteredStudents = [];
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
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
          } catch (e, stackTrace) {
            print('Groupe non trouvé pour le livre: $e');
            if (mounted) {
              ErrorHandler.showCaughtError(
                context,
                message: 'Erreur lors de la récupération du groupe',
                error: e,
                stackTrace: stackTrace,
              );
            }
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
    } catch (e, stackTrace) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ErrorHandler.showCaughtError(
          context,
          message: 'Erreur lors du traitement du code-barres',
          error: e,
          stackTrace: stackTrace,
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
    } catch (e, stackTrace) {
      if (mounted) {
        ErrorHandler.showCaughtError(
          context,
          message: 'Erreur lors de la confirmation de l\'emprunt',
          error: e,
          stackTrace: stackTrace,
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
      final initService = context.read<InitializationService>();
      if (initService.isOfflineMode) {
        print('⏸️ Mode hors-ligne actif: synchronisation différée');
        return;
      }
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
      _borrowerController.clear();
      _filteredStudents = [];
      _selectedClass = null;
      _isProcessing = false;
    });
  }
}