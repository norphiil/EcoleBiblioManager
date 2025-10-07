import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/dynamic_color_scheme.dart';
import '../widgets/scanner/python_barcode_scanner.dart';
import '../widgets/svg_logo_widget.dart';
import '../services/services.dart';
import '../models/models.dart';

/// Écran pour consulter les informations d'un livre
class BookInfoScreen extends StatefulWidget {
  final Book? book;
  
  const BookInfoScreen({Key? key, this.book}) : super(key: key);

  @override
  State<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends State<BookInfoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookApiService _bookApiService = BookApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  Book? _localBook;
  Book? _apiBook;
  bool _isLoading = false;
  String? _errorMessage;
  int _scannerKey = 0; // Clé pour forcer la recréation du scanner
  DynamicColorScheme? _currentColors;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Si un livre est passé en paramètre, charger ses données
    if (widget.book != null) {
      _handleBarcodeScanned(widget.book!.isbn);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      key: AppKeys.bookInfoScreenKey,
      appBar: AppBar(
        title: const Text('Informations livre'),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        bottom: _localBook != null || _apiBook != null 
            ? TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.onTertiary,
                unselectedLabelColor: Theme.of(context).colorScheme.onTertiary.withValues(alpha: 0.7),
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
    
    // Wrap with dynamic theme if we have colors
    if (_currentColors != null) {
      return DynamicThemeProvider(
        colorScheme: _currentColors!,
        child: scaffold,
      );
    }
    
    return scaffold;
  }

  Widget _buildScanner() {
    return PythonBarcodeScanner(
      key: ValueKey(_scannerKey), // Clé pour forcer la recréation
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

    return _buildModernBookLayout(_localBook!, isLocal: true);
  }

  Widget _buildApiBookInfo() {
    if (_apiBook == null) {
      return _buildNoDataMessage(
        'Aucune donnée internet',
        'Impossible de récupérer les informations depuis internet.',
        Icons.cloud_off_outlined,
      );
    }

    return _buildModernBookLayout(_apiBook!, isLocal: false);
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

  /// Layout moderne pour afficher les informations du livre
  Widget _buildModernBookLayout(Book book, {required bool isLocal}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec couverture et informations principales
          _buildBookHeader(book, isLocal: isLocal),
          
          // Section du groupe (si disponible)
          if (isLocal && book.groupId != null)
            _buildGroupSection(book),
          
          // Section des informations détaillées
          _buildDetailedInfoSection(book, isLocal: isLocal),
          
          // Section de l'historique des emprunts (pour données locales)
          if (isLocal)
            FutureBuilder<List<BorrowHistory>>(
              future: DatabaseHelper().getBorrowHistoryForBook(book.isbn),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return _buildBorrowHistorySection(snapshot.data!);
                }
                return const SizedBox.shrink();
              },
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// En-tête avec couverture du livre et titre
  Widget _buildBookHeader(Book book, {required bool isLocal}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Couverture du livre
              _buildBookCover(book),
              
              const SizedBox(width: 20),
              
              // Informations principales
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge de source
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isLocal 
                            ? (_currentColors?.backgroundColor ?? Colors.blue.shade50)
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLocal 
                              ? (_currentColors?.borderColor ?? Colors.blue.shade200)
                              : Colors.purple.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLocal ? Icons.storage : Icons.cloud,
                            size: 14,
                            color: isLocal 
                                ? (_currentColors?.textColor ?? Colors.blue.shade700)
                                : Colors.purple.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLocal ? 'Bibliothèque locale' : 'Internet',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isLocal 
                                  ? (_currentColors?.textColor ?? Colors.blue.shade700)
                                  : Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Titre du livre
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Auteur
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            book.author,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Statut (pour données locales)
                    if (isLocal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: book.status == BookStatus.borrowed
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: book.status == BookStatus.borrowed
                                ? Colors.orange.shade300
                                : Colors.green.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              book.status == BookStatus.borrowed
                                  ? Icons.person
                                  : Icons.check_circle,
                              size: 18,
                              color: book.status == BookStatus.borrowed
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              book.status == BookStatus.borrowed 
                                  ? 'Emprunté' 
                                  : 'Disponible',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: book.status == BookStatus.borrowed
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          // Description du livre si disponible
          if (book.description != null && book.description!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  book.description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Widget pour la couverture du livre
  Widget _buildBookCover(Book book) {
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty
            ? Image.network(
                book.coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderCover();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              )
            : _buildPlaceholderCover(),
      ),
    );
  }

  /// Placeholder pour la couverture du livre
  Widget _buildPlaceholderCover() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Pas de\ncouverture',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// Section du groupe avec logo et titre en gros
  Widget _buildGroupSection(Book book) {
    return FutureBuilder<BookGroup?>(
      future: _getBookGroup(book.groupId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final group = snapshot.data!;
        
        // Générer les couleurs dynamiques à partir de la couleur du groupe
        final groupColors = group.groupColor != null
            ? DynamicColorScheme.fromGroupColor(group.groupColor!)
            : DynamicColorScheme.fromColor(Colors.blue);
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                groupColors.backgroundColor,
                groupColors.backgroundColor.withValues(alpha: 0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: groupColors.borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo du groupe
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SvgLogoWidget(
                        svgData: group.svgData,
                        colorHex: group.groupColor,
                        width: 60,
                        height: 60,
                        fallback: Icon(
                          Icons.category,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Titre et description du groupe
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Groupe de rangement',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: groupColors.textColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: groupColors.darkerColor,
                        height: 1.2,
                      ),
                    ),
                    if (group.description != null && group.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        group.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: groupColors.textColor.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Récupérer les informations du groupe
  Future<BookGroup?> _getBookGroup(String groupId) async {
    try {
      final dbHelper = DatabaseHelper();
      return await dbHelper.getGroup(groupId);
    } catch (e) {
      return null;
    }
  }

  /// Section des informations détaillées
  Widget _buildDetailedInfoSection(Book book, {required bool isLocal}) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de la section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'Informations détaillées',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Contenu de la section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildModernInfoRow(
                  icon: Icons.fingerprint,
                  label: 'ISBN',
                  value: book.isbn,
                ),
                if (book.publisher != null)
                  _buildModernInfoRow(
                    icon: Icons.business,
                    label: 'Éditeur',
                    value: book.publisher!,
                  ),
                if (book.publishYear != null)
                  _buildModernInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Année',
                    value: book.publishYear.toString(),
                  ),
                if (book.publishPlace != null)
                  _buildModernInfoRow(
                    icon: Icons.location_on,
                    label: 'Lieu de publication',
                    value: book.publishPlace!,
                  ),
                if (book.pageCount != null)
                  _buildModernInfoRow(
                    icon: Icons.auto_stories,
                    label: 'Pages',
                    value: book.pageCount.toString(),
                  ),
                if (book.subjects.isNotEmpty)
                  _buildModernInfoRow(
                    icon: Icons.category_outlined,
                    label: 'Sujets',
                    value: book.subjects.take(5).join(', '),
                    isMultiLine: true,
                  ),
                  
                // Informations d'emprunt en cours
                if (isLocal && book.borrowedBy != null) ...[
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Emprunt en cours',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildModernInfoRow(
                    icon: Icons.person_outline,
                    label: 'Emprunté par',
                    value: book.borrowedBy!,
                    valueColor: Colors.orange.shade700,
                  ),
                  if (book.borrowerClassName != null)
                    _buildModernInfoRow(
                      icon: Icons.school,
                      label: 'Classe',
                      value: book.borrowerClassName!,
                      valueColor: Colors.orange.shade700,
                    ),
                  if (book.borrowedDate != null)
                    _buildModernInfoRow(
                      icon: Icons.access_time,
                      label: 'Date d\'emprunt',
                      value: '${book.borrowedDate!.day}/${book.borrowedDate!.month}/${book.borrowedDate!.year} à ${book.borrowedDate!.hour.toString().padLeft(2, '0')}:${book.borrowedDate!.minute.toString().padLeft(2, '0')}',
                      valueColor: Colors.orange.shade700,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ligne d'information moderne
  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isMultiLine = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                if (book.borrowerClassName != null)
                  _buildInfoRow('Classe', book.borrowerClassName!),
                if (book.borrowedDate != null)
                  _buildInfoRow('Date d\'emprunt', 
                      '${book.borrowedDate!.day}/${book.borrowedDate!.month}/${book.borrowedDate!.year} à ${book.borrowedDate!.hour.toString().padLeft(2, '0')}:${book.borrowedDate!.minute.toString().padLeft(2, '0')}'),
              ]),
            ],
            
            // Historique des emprunts (seulement pour les données locales)
            if (isLocal) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              FutureBuilder<List<BorrowHistory>>(
                future: DatabaseHelper().getBorrowHistoryForBook(book.isbn),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return _buildBorrowHistorySection(snapshot.data!);
                  }
                  return const SizedBox.shrink();
                },
              ),
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

  Widget _buildBorrowHistorySection(List<BorrowHistory> history) {
    // Trier par date d'emprunt décroissante (plus récent en premier)
    final sortedHistory = List<BorrowHistory>.from(history)
      ..sort((a, b) => b.borrowedAt.compareTo(a.borrowedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des emprunts (${sortedHistory.length})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.paddingSmall),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedHistory.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
            itemBuilder: (context, index) {
              final borrowRecord = sortedHistory[index];
              return _buildBorrowHistoryItem(borrowRecord);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBorrowHistoryItem(BorrowHistory borrowRecord) {
    final borrowedDateStr = '${borrowRecord.borrowedAt.day}/${borrowRecord.borrowedAt.month}/${borrowRecord.borrowedAt.year} à ${borrowRecord.borrowedAt.hour.toString().padLeft(2, '0')}:${borrowRecord.borrowedAt.minute.toString().padLeft(2, '0')}';
    final returnedDateStr = borrowRecord.returnedAt != null
        ? '${borrowRecord.returnedAt!.day}/${borrowRecord.returnedAt!.month}/${borrowRecord.returnedAt!.year} à ${borrowRecord.returnedAt!.hour.toString().padLeft(2, '0')}:${borrowRecord.returnedAt!.minute.toString().padLeft(2, '0')}'
        : 'En cours';
    
    final isCurrentlyBorrowed = borrowRecord.isCurrentlyBorrowed;
    
    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: isCurrentlyBorrowed 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  borrowRecord.borrowerName,
                  style: TextStyle(
                    fontWeight: isCurrentlyBorrowed ? FontWeight.bold : FontWeight.normal,
                    color: isCurrentlyBorrowed 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (borrowRecord.className != null) ...[
                Icon(
                  Icons.school,
                  size: 14,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  borrowRecord.className!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Emprunté le $borrowedDateStr',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                isCurrentlyBorrowed ? Icons.schedule : Icons.check_circle,
                size: 12,
                color: isCurrentlyBorrowed 
                    ? AppConstants.warningColor
                    : AppConstants.successColor,
              ),
              const SizedBox(width: 4),
              Text(
                isCurrentlyBorrowed ? 'En cours' : 'Retourné le $returnedDateStr',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isCurrentlyBorrowed 
                      ? AppConstants.warningColor
                      : AppConstants.successColor,
                  fontWeight: isCurrentlyBorrowed ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
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
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
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
        return AppConstants.successColor.withValues(alpha: 0.2);
      case BookStatus.borrowed:
        return AppConstants.warningColor.withValues(alpha: 0.2);
      case BookStatus.reserved:
        return AppConstants.infoColor.withValues(alpha: 0.2);
      case BookStatus.maintenance:
      case BookStatus.lost:
        return AppConstants.errorColor.withValues(alpha: 0.2);
    }
  }

  Future<void> _handleBarcodeScanned(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _localBook = null;
      _apiBook = null;
      _currentColors = null;
    });

    try {
      // Recherche simultanée dans les deux sources
      final futures = await Future.wait([
        _searchLocalBook(code),
        _bookApiService.getBookByIsbn(code),
      ]);

      final localBook = futures[0];
      final apiBook = futures[1];
      
      // Load group color if book has a group
      DynamicColorScheme? colors;
      if (localBook != null && localBook.groupId != null) {
        try {
          final group = await _dbHelper.getGroup(localBook.groupId!);
          if (group?.groupColor != null) {
            colors = DynamicColorScheme.fromGroupColor(group!.groupColor!);
          }
        } catch (e) {
          print('Error loading group color: $e');
        }
      }

      setState(() {
        _localBook = localBook;
        _apiBook = apiBook;
        _currentColors = colors;
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
    try {
      final dbHelper = DatabaseHelper();
      final books = await dbHelper.searchBooks('isbn', isbn);
      return books.isNotEmpty ? books.first : null;
    } catch (e) {
      print('Erreur lors de la recherche locale: $e');
      return null;
    }
  }

  void _scanAnother() {
    setState(() {
      _localBook = null;
      _apiBook = null;
      _errorMessage = null;
      _currentColors = null;
      _isLoading = false; // S'assurer que loading est bien à false
      _scannerKey++; // Changer la clé pour forcer la recréation du scanner
    });
  }
}