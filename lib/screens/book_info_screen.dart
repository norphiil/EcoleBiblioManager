import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../services/services.dart';
import '../models/models.dart';

/// Écran pour consulter les informations d'un livre
class BookInfoScreen extends StatefulWidget {
  const BookInfoScreen({Key? key}) : super(key: key);

  @override
  State<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookApiService _bookApiService = BookApiService();
  
  Book? _localBook;
  Book? _apiBook;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AppKeys.bookInfoScreenKey,
      appBar: AppBar(
        title: const Text('Informations livre'),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        bottom: _localBook != null || _apiBook != null 
            ? TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.onTertiary,
                unselectedLabelColor: Theme.of(context).colorScheme.onTertiary.withOpacity(0.7),
                indicatorColor: Theme.of(context).colorScheme.onTertiary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.storage),
                    text: 'Base locale',
                  ),
                  Tab(
                    icon: Icon(Icons.cloud),
                    text: 'Données internet',
                  ),
                ],
              )
            : null,
      ),
      body: _localBook == null && _apiBook == null 
          ? _buildScanner() 
          : _buildBookInfoTabs(),
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

  Widget _buildBookInfoTabs() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppConstants.paddingMedium),
            Text('Recherche des informations...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_errorMessage != null) ...[
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
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
                IconButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLocalBookInfo(),
              _buildApiBookInfo(),
            ],
          ),
        ),
        
        // Boutons d'action
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildLocalBookInfo() {
    if (_localBook == null) {
      return _buildNoDataMessage(
        'Aucune donnée locale',
        'Ce livre n\'est pas encore enregistré dans la bibliothèque.',
        Icons.storage_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: _buildBookCard(_localBook!, isLocal: true),
    );
  }

  Widget _buildApiBookInfo() {
    if (_apiBook == null) {
      return _buildNoDataMessage(
        'Aucune donnée internet',
        'Impossible de récupérer les informations depuis internet.',
        Icons.cloud_off_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: _buildBookCard(_apiBook!, isLocal: false),
    );
  }

  Widget _buildNoDataMessage(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book, {required bool isLocal}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec type de source
            Row(
              children: [
                Icon(
                  isLocal ? Icons.storage : Icons.cloud,
                  color: isLocal 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Text(
                  isLocal ? 'Données locales' : 'Données internet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isLocal 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const Spacer(),
                if (isLocal)
                  Chip(
                    label: Text(
                      book.status.toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(book.status),
                  ),
              ],
            ),
            
            const Divider(),
            
            // Informations principales
            _buildInfoSection('Informations générales', [
              _buildInfoRow('Titre', book.title),
              _buildInfoRow('Auteur', book.author),
              _buildInfoRow('ISBN', book.isbn),
              if (book.publisher != null) 
                _buildInfoRow('Éditeur', book.publisher!),
              if (book.publishYear != null)
                _buildInfoRow('Année de publication', book.publishYear!.toString()),
              if (book.subjects.isNotEmpty)
                _buildInfoRow('Sujets', book.subjects.take(3).join(', ')),
              if (book.pageCount != null)
                _buildInfoRow('Pages', book.pageCount.toString()),
            ]),
            
            // Informations de groupe (seulement pour les données locales)
            if (isLocal && book.groupId != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              _buildInfoSection('Groupe', [
                _buildInfoRow('ID du groupe', book.groupId!),
              ]),
            ],
            
            // Informations d'emprunt (seulement pour les données locales)
            if (isLocal && book.borrowedBy != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              _buildInfoSection('Emprunt en cours', [
                _buildInfoRow('Emprunté par', book.borrowedBy!),
                if (book.borrowedDate != null)
                  _buildInfoRow('Date d\'emprunt', 
                      '${book.borrowedDate!.day}/${book.borrowedDate!.month}/${book.borrowedDate!.year}'),
                if (book.dueDate != null)
                  _buildInfoRow('Date de retour', 
                      '${book.dueDate!.day}/${book.dueDate!.month}/${book.dueDate!.year}'),
              ]),
            ],
            
            // Informations supplémentaires
            if (book.publishPlace != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              _buildInfoSection('Informations détaillées', [
                _buildInfoRow('Lieu de publication', book.publishPlace!),
                if (book.subjects.length > 3)
                  Text(
                    'Sujets: ${book.subjects.join(', ')}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _scanAnother,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un autre'),
            ),
          ),
          const SizedBox(width: AppConstants.paddingSmall),
          Expanded(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Accueil'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookStatus status) {
    switch (status) {
      case BookStatus.available:
        return AppConstants.successColor.withOpacity(0.2);
      case BookStatus.borrowed:
        return AppConstants.warningColor.withOpacity(0.2);
      case BookStatus.reserved:
        return AppConstants.infoColor.withOpacity(0.2);
      case BookStatus.maintenance:
      case BookStatus.lost:
        return AppConstants.errorColor.withOpacity(0.2);
    }
  }

  Future<void> _handleBarcodeScanned(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _localBook = null;
      _apiBook = null;
    });

    try {
      // Recherche simultanée dans les deux sources
      final futures = await Future.wait([
        _searchLocalBook(code),
        _bookApiService.getBookByIsbn(code),
      ]);

      setState(() {
        _localBook = futures[0];
        _apiBook = futures[1];
        _isLoading = false;
      });

      if (_localBook == null && _apiBook == null) {
        setState(() {
          _errorMessage = 'Aucune information trouvée pour ce livre';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la recherche: $e';
        _isLoading = false;
      });
    }
  }

  Future<Book?> _searchLocalBook(String isbn) async {
    // TODO: Implémenter la recherche dans la base locale
    // Pour l'instant, retourne null (pas de données locales)
    return null;
  }

  void _scanAnother() {
    setState(() {
      _localBook = null;
      _apiBook = null;
      _errorMessage = null;
    });
  }
}