import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../core/constants/app_constants.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Écran de gestion des groupes de livres
class GroupsManagementScreen extends StatefulWidget {
  const GroupsManagementScreen({super.key});

  @override
  State<GroupsManagementScreen> createState() => _GroupsManagementScreenState();
}

class _GroupsManagementScreenState extends State<GroupsManagementScreen> {
  late final GoogleSheetsService _sheetsService;
  
  List<BookGroup> _groups = [];
  List<Book> _allBooks = [];
  bool _isLoading = true;
  bool _isSaving = false; // Indicateur pour les opérations de sauvegarde
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sheetsService = context.read<GoogleSheetsService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _sheetsService.getAllBookGroups(),
        _sheetsService.getAllBooks(),
      ]);

      setState(() {
        _groups = results[0] as List<BookGroup>;
        _allBooks = results[1] as List<Book>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
              tooltip: 'Retour',
            ),
            title: const Text('Gestion des groupes'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            actions: [
              IconButton(
                onPressed: _isSaving ? null : _showCreateGroupDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Créer un nouveau groupe',
              ),
            ],
          ),
          body: _buildBody(),
          floatingActionButton: _isSaving ? null : FloatingActionButton(
            onPressed: _showCreateGroupDialog,
            child: const Icon(Icons.add),
            tooltip: 'Créer un nouveau groupe',
          ),
        ),
        // Overlay de chargement pendant les opérations
        if (_isSaving)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(AppConstants.paddingLarge),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppConstants.paddingMedium),
                      Text(
                        'Opération en cours...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppConstants.paddingMedium),
            Text('Chargement des groupes...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Aucun groupe créé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Créez votre premier groupe pour organiser vos livres',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ElevatedButton.icon(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer un groupe'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          return _buildGroupCard(_groups[index]);
        },
      ),
    );
  }

  Widget _buildGroupCard(BookGroup group) {
    final booksInGroup = _allBooks.where((book) => book.groupId == group.id).length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: group.logoPath != null
              ? ClipOval(
                  child: Image.network(
                    group.logoPath!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
                  ),
                )
              : Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          group.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description != null) ...[
              Text(group.description!),
              const SizedBox(height: 4),
            ],
            Text('$booksInGroup livre(s) • ${group.keywords.length} mot(s)-clé(s)'),
            if (group.keywords.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: group.keywords.take(3).map((keyword) => Chip(
                  label: Text(
                    keyword,
                    style: const TextStyle(fontSize: 12),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleGroupAction(action, group),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Modifier'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'books',
              child: ListTile(
                leading: Icon(Icons.library_books),
                title: Text('Voir les livres'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () => _showEditGroupDialog(group),
      ),
    );
  }

  void _handleGroupAction(String action, BookGroup group) {
    switch (action) {
      case 'edit':
        _showEditGroupDialog(group);
        break;
      case 'books':
        _showGroupBooksDialog(group);
        break;
      case 'delete':
        _confirmDeleteGroup(group);
        break;
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        onSave: (group) => _createGroup(group),
        suggestedKeywords: _getSuggestedKeywords(),
      ),
    );
  }

  void _showEditGroupDialog(BookGroup group) {
    final booksInGroup = _allBooks.where((book) => book.groupId == group.id).toList();
    
    showDialog(
      context: context,
      builder: (context) => GroupFormDialog(
        group: group,
        onSave: (updatedGroup) => _updateGroup(updatedGroup),
        suggestedKeywords: _getSuggestedKeywordsForGroup(booksInGroup),
        booksInGroup: booksInGroup,
      ),
    );
  }

  void _showGroupBooksDialog(BookGroup group) {
    final booksInGroup = _allBooks.where((book) => book.groupId == group.id).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Livres du groupe "${group.title}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: booksInGroup.isEmpty
              ? const Text('Aucun livre dans ce groupe')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: booksInGroup.length,
                  itemBuilder: (context, index) {
                    final book = booksInGroup[index];
                    return ListTile(
                      leading: const Icon(Icons.book),
                      title: Text(book.title),
                      subtitle: Text(book.author),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BookGroup group) {
    final booksInGroup = _allBooks.where((book) => book.groupId == group.id).length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le groupe "${group.title}" ?\n\n'
          '${booksInGroup > 0 ? '$booksInGroup livre(s) seront dissocié(s) du groupe.' : 'Aucun livre n\'est associé à ce groupe.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroup(group);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  bool _isCreating = false;
  
  Future<void> _createGroup(BookGroup group) async {
    print('🔵 _createGroup appelé pour: ${group.title} (ID: ${group.id})');
    
    if (_isCreating) {
      print('⚠️ Appel bloqué - création déjà en cours');
      return; // Empêcher les doubles clics
    }
    
    setState(() {
      _isCreating = true;
      _isSaving = true;
    });
    
    print('📤 Envoi de la requête addBookGroup...');
    
    try {
      await _sheetsService.addBookGroup(group);
      print('✅ Groupe créé avec succès');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Groupe "${group.title}" créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      print('❌ Erreur lors de la création: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      print('🔓 Réinitialisation du flag _isCreating');
      
      if (mounted) {
        setState(() {
          _isCreating = false;
          _isSaving = false;
        });
      }
    }
  }

  bool _isUpdating = false;
  
  Future<void> _updateGroup(BookGroup group) async {
    if (_isUpdating) return; // Empêcher les doubles clics
    
    setState(() {
      _isUpdating = true;
      _isSaving = true;
    });
    
    try {
      await _sheetsService.updateBookGroup(group);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Groupe "${group.title}" mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _isSaving = false;
        });
      }
    }
  }

  bool _isDeleting = false;
  
  Future<void> _deleteGroup(BookGroup group) async {
    if (_isDeleting) return; // Empêcher les doubles clics
    
    setState(() {
      _isDeleting = true;
      _isSaving = true;
    });
    
    try {
      // D'abord, dissocier tous les livres du groupe
      final booksToUpdate = _allBooks.where((book) => book.groupId == group.id);
      for (final book in booksToUpdate) {
        final updatedBook = Book(
          isbn: book.isbn,
          title: book.title,
          author: book.author,
          publisher: book.publisher,
          publishYear: book.publishYear,
          publishPlace: book.publishPlace,
          subjects: book.subjects,
          pageCount: book.pageCount,
          coverImageUrl: book.coverImageUrl,
          groupId: null, // Supprimer l'association
          status: book.status,
          borrowedBy: book.borrowedBy,
          borrowedDate: book.borrowedDate,
          dueDate: book.dueDate,
        );
        await _sheetsService.updateBook(updatedBook);
      }
      
      // Puis supprimer le groupe
      await _sheetsService.deleteBookGroup(group.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Groupe "${group.title}" supprimé'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _isSaving = false;
        });
      }
    }
  }

  List<String> _getSuggestedKeywords() {
    final allSubjects = <String>{};
    for (final book in _allBooks) {
      allSubjects.addAll(book.subjects);
    }
    return allSubjects.toList()..sort();
  }

  List<String> _getSuggestedKeywordsForGroup(List<Book> booksInGroup) {
    final allSubjects = <String>{};
    for (final book in booksInGroup) {
      allSubjects.addAll(book.subjects);
    }
    return allSubjects.toList()..sort();
  }
}

/// Dialog pour créer/modifier un groupe
class GroupFormDialog extends StatefulWidget {
  final BookGroup? group;
  final Function(BookGroup) onSave;
  final List<String> suggestedKeywords;
  final List<Book>? booksInGroup;

  const GroupFormDialog({
    super.key,
    this.group,
    required this.onSave,
    required this.suggestedKeywords,
    this.booksInGroup,
  });

  @override
  State<GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<GroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoPathController = TextEditingController();
  
  List<String> _selectedKeywords = [];

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _titleController.text = widget.group!.title;
      _descriptionController.text = widget.group!.description ?? '';
      _logoPathController.text = widget.group!.logoPath ?? '';
      _selectedKeywords = List.from(widget.group!.keywords);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.group == null ? 'Nouveau groupe' : 'Modifier le groupe'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du groupe *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom du groupe est obligatoire';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                TextFormField(
                  controller: _logoPathController,
                  decoration: const InputDecoration(
                    labelText: 'URL de l\'image/logo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                _buildKeywordsSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saveGroup,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _buildKeywordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mots-clés',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        // Mots-clés sélectionnés
        if (_selectedKeywords.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            children: _selectedKeywords.map((keyword) => Chip(
              label: Text(keyword),
              onDeleted: () {
                setState(() {
                  _selectedKeywords.remove(keyword);
                });
              },
            )).toList(),
          ),
          const SizedBox(height: 8),
        ],
        
        // Suggestions depuis les livres du groupe
        if (widget.booksInGroup != null && widget.booksInGroup!.isNotEmpty) ...[
          Text(
            'Suggestions depuis les livres du groupe:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: widget.suggestedKeywords
                .where((keyword) => !_selectedKeywords.contains(keyword))
                .take(10)
                .map((keyword) => ActionChip(
                  label: Text(keyword, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _selectedKeywords.add(keyword);
                    });
                  },
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                )).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Toutes les suggestions disponibles
        if (widget.suggestedKeywords.isNotEmpty) ...[
          Text(
            'Autres mots-clés disponibles:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 4,
                children: widget.suggestedKeywords
                    .where((keyword) => !_selectedKeywords.contains(keyword))
                    .map((keyword) => ActionChip(
                      label: Text(keyword, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _selectedKeywords.add(keyword);
                        });
                      },
                    )).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _generateUuid() {
    final random = Random();
    return '${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(999999)}';
  }

  void _saveGroup() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final group = BookGroup(
      id: widget.group?.id ?? _generateUuid(),
      title: _titleController.text.trim(),
      key: _titleController.text.trim().toLowerCase().replaceAll(' ', '_'),
      logoPath: _logoPathController.text.trim().isEmpty ? null : _logoPathController.text.trim(),
      keywords: _selectedKeywords,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    );

    print('💾 GroupFormDialog - Appel onSave pour: ${group.title} (ID: ${group.id})');
    widget.onSave(group);
    Navigator.of(context).pop();
  }
}