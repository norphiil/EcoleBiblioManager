import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/database/database_helper.dart';
import '../widgets/books/book_info_card.dart';
import '../widgets/svg_logo_widget.dart';
import 'edit_book_screen.dart';

class ShelveBookScreen extends StatefulWidget {
  final String? scannedIsbn;
  
  const ShelveBookScreen({
    Key? key,
    this.scannedIsbn,
  }) : super(key: key);

  @override
  State<ShelveBookScreen> createState() => _ShelveBookScreenState();
}

class _ShelveBookScreenState extends State<ShelveBookScreen> {
  late final BookApiService _bookApiService;
  late final LocalDatabaseService _localDbService;
  
  Book? _scannedBook;
  BookGroup? _selectedGroup;
  List<BookGroup> _suggestedGroups = [];
  List<BookGroup> _allGroups = [];
  bool _isLoading = true;
  bool _isBookInDatabase = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Les services seront initialisés dans didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialiser les services depuis le context
    _bookApiService = context.read<BookApiService>();
    _localDbService = context.read<LocalDatabaseService>();
    
    if (widget.scannedIsbn != null) {
      _handleScannedBook(widget.scannedIsbn!);
    }
  }

  Future<void> _handleScannedBook(String isbn) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Vérifier si le livre existe déjà dans la base de données locale
      final results = await _localDbService.searchBooks('isbn', isbn);
      final existingBook = results.isNotEmpty ? results.first : null;
      
      if (existingBook != null) {
        // Livre déjà en base
        print('📖 Livre trouvé en base: ${existingBook.title}');
        print('🏷️  GroupId du livre: ${existingBook.groupId}');
        
        setState(() {
          _scannedBook = existingBook;
          _isBookInDatabase = true;
        });
        
        if (existingBook.groupId != null && existingBook.groupId!.isNotEmpty) {
          // Livre avec groupe assigné → ALLER DIRECTEMENT À LA PAGE DE CONFIRMATION
          print('🔍 Recherche du groupe avec ID: ${existingBook.groupId}');
          final groups = await _localDbService.getAllBookGroups();
          print('📚 Nombre de groupes chargés: ${groups.length}');
          
          try {
            final group = groups.firstWhere((g) => g.id == existingBook.groupId);
            print('✅ Groupe trouvé: ${group.title}');
            setState(() {
              _selectedGroup = group;
              _allGroups = groups; // Stocker tous les groupes pour permettre la modification
              _isLoading = false; // Afficher directement la page de confirmation
            });
            return; // Sortir pour afficher la confirmation immédiatement
          } catch (e) {
            print('❌ Groupe non trouvé pour ID: ${existingBook.groupId}');
            // Groupe non trouvé, charger tous les groupes pour sélection
            setState(() {
              _allGroups = groups;
            });
          }
        } else {
          print('⚠️  Livre sans groupe assigné, affichage de la sélection');
          // Livre sans groupe - charger les groupes pour sélection
          await _loadGroupsAndSuggest();
        }
      } else {
        // Livre pas en base, récupérer les infos depuis l'API
        final bookInfo = await _bookApiService.getBookByIsbn(isbn);
        if (bookInfo != null) {
          setState(() {
            _scannedBook = bookInfo;
            _isBookInDatabase = false;
          });
          
          // Charger les groupes et suggérer les meilleurs matchs
          await _loadGroupsAndSuggest();
        } else {
          setState(() {
            _errorMessage = 'Livre non trouvé dans la base de données';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la recherche du livre: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGroupsAndSuggest() async {
    try {
      final groups = await _localDbService.getAllBookGroups();
      setState(() {
        _allGroups = groups;
      });

      if (_scannedBook != null && _scannedBook!.subjects.isNotEmpty) {
        // Calculer les scores de correspondance pour chaque groupe
        final groupScores = <BookGroup, int>{};
        for (final group in groups) {
          final score = group.calculateMatchScore(_scannedBook!.subjects);
          if (score > 0) {
            groupScores[group] = score;
          }
        }

        // Trier par score décroissant
        final sortedGroups = groupScores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        setState(() {
          _suggestedGroups = sortedGroups.map((e) => e.key).toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des groupes: $e';
      });
    }
  }

  Future<void> _editBookInfo() async {
    if (_scannedBook == null) return;

    final result = await Navigator.of(context).push<Book>(
      MaterialPageRoute(
        builder: (context) => EditBookScreen(book: _scannedBook!),
      ),
    );

    // Si le livre a été mis à jour, actualiser l'affichage
    if (result != null && mounted) {
      setState(() {
        _scannedBook = result;
      });
    }
  }

  Future<void> _confirmShelving() async {
    if (_scannedBook == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String groupName = _selectedGroup?.title ?? 'Aucun groupe';
      bool wasBookBorrowed = _scannedBook!.status == BookStatus.borrowed;
      
      // Si le livre était emprunté, marquer le dernier emprunt comme retourné
      if (wasBookBorrowed) {
        await _returnBorrowedBook();
      }
      
      if (!_isBookInDatabase) {
        // Ajouter le livre à la base de données
        if (_selectedGroup != null) {
          _scannedBook!.assignToGroup(_selectedGroup!.id);
        }
        await _localDbService.addBook(_scannedBook!);
      } else {
        // Mettre à jour le groupe si changé
        if (_selectedGroup != null) {
          _scannedBook!.assignToGroup(_selectedGroup!.id);
          await _localDbService.updateBook(_scannedBook!);
        }
      }

      // Afficher un message de confirmation
      if (mounted) {
        String message;
        if (wasBookBorrowed) {
          message = '✅ Livre "${_scannedBook!.title}" retourné et rangé dans "$groupName"';
        } else {
          message = '✅ Livre "${_scannedBook!.title}" ${_isBookInDatabase ? 'mis à jour' : 'ajouté au groupe "$groupName"'}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Retourner à l'écran d'accueil
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de l\'enregistrement: $e';
        _isLoading = false;
      });
    }
  }

  /// Marque le livre comme retourné et met à jour l'historique
  Future<void> _returnBorrowedBook() async {
    if (_scannedBook == null) return;

    try {
      // Mettre à jour l'historique local avec la date de retour
      await DatabaseHelper().markLastBorrowAsReturned(_scannedBook!.isbn);
      
      // Marquer le livre comme retourné (met à jour le statut)
      _scannedBook!.returnBook();
      await _localDbService.updateBook(_scannedBook!);
      
      // Synchroniser avec Google Sheets en arrière-plan
      _syncReturnToSheets();
      
      print('✅ Livre retourné: ${_scannedBook!.title}');
    } catch (e) {
      print('⚠️ Erreur lors du retour du livre: $e');
      // Ne pas bloquer le processus de rangement en cas d'erreur
    }
  }

  /// Synchronise le retour avec Google Sheets (en arrière-plan)
  Future<void> _syncReturnToSheets() async {
    if (_scannedBook == null) return;

    try {
      final sheetsService = context.read<GoogleSheetsService>();
      
      // Récupérer le dernier emprunt pour cet ISBN
      final historyList = await DatabaseHelper().getBorrowHistoryForBook(_scannedBook!.isbn);
      if (historyList.isNotEmpty) {
        // Trier par date d'emprunt décroissante pour obtenir le dernier
        historyList.sort((a, b) => b.borrowedAt.compareTo(a.borrowedAt));
        final latestBorrow = historyList.first;
        
        // Mettre à jour dans Google Sheets
        await sheetsService.updateBorrowHistory(latestBorrow);
        print('✅ Retour synchronisé avec Google Sheets');
      }
    } catch (e) {
      print('⚠️ Erreur de synchronisation du retour avec Google Sheets: $e');
      // Ne pas bloquer l'utilisateur
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranger un livre'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_scannedBook != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editBookInfo,
              tooltip: 'Modifier les informations',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }

    if (_scannedBook == null) {
      return const Center(
        child: Text('Aucun livre scanné'),
      );
    }

    // Si un groupe est sélectionné, afficher la confirmation
    if (_selectedGroup != null) {
      return _buildShelvingConfirmation();
    }

    // Sinon, afficher la sélection de groupe
    return _buildGroupSelection();
  }

  Widget _buildGroupSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookInfoCard(
            book: _scannedBook!,
            showGroupInfo: false,
          ),
          const SizedBox(height: 24),
          Text(
            'Sélectionnez un groupe pour ce livre:',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_suggestedGroups.isNotEmpty) ...[
            Text(
              'Suggestions (basées sur les genres):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._suggestedGroups.map((group) => _buildGroupTile(group, true)),
            const SizedBox(height: 20),
          ],
          Text(
            'Tous les groupes:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._allGroups
              .where((group) => !_suggestedGroups.contains(group))
              .map((group) => _buildGroupTile(group, false)),
          const SizedBox(height: 24),
          // Bouton de validation
          if (_selectedGroup != null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Passer à l'écran de confirmation avec le groupe sélectionné
                  setState(() {
                    // Le setState mettra à jour l'affichage pour montrer _buildShelvingConfirmation
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.check_circle, size: 28),
                label: Text('Confirmer - Ranger dans "${_selectedGroup!.title}"'),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildShelvingConfirmation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BookInfoCard(
            book: _scannedBook!,
            showGroupInfo: true,
            group: _selectedGroup,
          ),
          const SizedBox(height: 32),
          
          // Message principal
          Text(
            _isBookInDatabase 
                ? 'Ce livre appartient au groupe:' 
                : 'Ranger dans la catégorie:',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Affichage du groupe avec grosse icône
          _buildGroupDisplay(_selectedGroup!),
          
          // Bouton "Modifier le groupe" (petit, discret)
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              // Charger tous les groupes si pas déjà chargés
              if (_allGroups.isEmpty) {
                await _loadGroupsAndSuggest();
              }
              
              setState(() {
                // Retour à la sélection de groupe
                _selectedGroup = null;
              });
            },
            icon: const Icon(Icons.edit, size: 18),
            label: Text(_isBookInDatabase ? 'Modifier le groupe' : 'Choisir un autre groupe'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Bouton principal selon le contexte
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _confirmShelving,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBookInDatabase 
                    ? Colors.blue.shade600 
                    : Colors.green.shade600,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isBookInDatabase ? Icons.arrow_forward : Icons.check_circle,
                size: 28,
              ),
              label: Text(_isBookInDatabase ? 'Ranger' : 'Enregistrer et ranger'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(BookGroup group, bool isSuggested) {
    final isSelected = _selectedGroup?.id == group.id;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? Colors.blue.shade600 
              : isSuggested 
                  ? Colors.green.shade300
                  : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: () => setState(() => _selectedGroup = group),
        leading: _buildGroupLogo(group),
        title: Text(
          group.title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.blue.shade700 : null,
          ),
        ),
        subtitle: group.keywords.isNotEmpty
            ? Text(
                'Mots-clés: ${group.keywords.take(3).join(', ')}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Colors.blue.shade600)
            : isSuggested
                ? Icon(Icons.star, color: Colors.amber.shade600, size: 20)
                : null,
      ),
    );
  }

  Widget _buildGroupDisplay(BookGroup group) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grosse icône du groupe
            _buildGroupLogo(group, size: 120),
            const SizedBox(height: 24),
            
            // Nom du groupe en gros
            Text(
              group.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (group.description != null) ...[
              const SizedBox(height: 12),
              Text(
                group.description!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Mots-clés du groupe
            if (group.keywords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: group.keywords.take(5).map((keyword) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      keyword,
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupLogo(BookGroup group, {double size = 40}) {
    // Afficher le logo SVG si disponible
    if (group.svgData != null && group.svgData!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 8),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 8),
          child: SvgLogoWidget(
            svgData: group.svgData!,
            colorHex: group.groupColor,
            width: size,
            height: size,
          ),
        ),
      );
    }
    return _buildDefaultLogo(group, size);
  }

  Widget _buildDefaultLogo(BookGroup group, double size) {
    // Utiliser la couleur du groupe si disponible, sinon un gradient par défaut
    final hasCustomColor = group.groupColor != null && group.groupColor!.isNotEmpty;
    final customColor = hasCustomColor
        ? Color(int.parse(group.groupColor!.replaceFirst('#', '0xFF')))
        : null;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: customColor != null
              ? [
                  customColor.withOpacity(0.7),
                  customColor,
                ]
              : [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 8),
      ),
      child: Icon(
        Icons.category,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}