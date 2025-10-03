import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../core/constants/app_constants.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/svg_logo_widget.dart';

/// Écran de gestion des groupes de livres
class GroupsManagementScreen extends StatefulWidget {
  const GroupsManagementScreen({super.key});

  @override
  State<GroupsManagementScreen> createState() => _GroupsManagementScreenState();
}

class _GroupsManagementScreenState extends State<GroupsManagementScreen> {
  late final LocalDatabaseService _localDbService;
  
  List<BookGroup> _groups = [];
  List<Book> _allBooks = [];
  bool _isLoading = true;
  bool _isSaving = false; // Indicateur pour les opérations de sauvegarde
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _localDbService = context.read<LocalDatabaseService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _localDbService.getAllBookGroups(),
        _localDbService.getAllBooks(),
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
          child: SvgLogoWidget(
            svgData: group.svgData,
            colorHex: group.groupColor,
            width: 40,
            height: 40,
            fallback: Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
          ),
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
      await _localDbService.addBookGroup(group);
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
      await _localDbService.updateBookGroup(group);
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
          borrowerClassName: book.borrowerClassName,
          borrowedDate: book.borrowedDate,
        );
        await _localDbService.updateBook(updatedBook);
      }
      
      // Puis supprimer le groupe
      await _localDbService.deleteBookGroup(group.id);
      
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
  
  List<String> _selectedKeywords = [];
  String? _svgData; // Base64 encoded SVG
  Color _groupColor = Colors.blue; // Couleur par défaut

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _titleController.text = widget.group!.title;
      _descriptionController.text = widget.group!.description ?? '';
      _selectedKeywords = List.from(widget.group!.keywords);
      _svgData = widget.group!.svgData;
      
      // Parser la couleur depuis le format hex
      if (widget.group!.groupColor != null) {
        final colorString = widget.group!.groupColor!.replaceAll('#', '');
        _groupColor = Color(int.parse('FF$colorString', radix: 16));
      }
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
                _buildSvgLogoSection(),
                const SizedBox(height: AppConstants.paddingMedium),
                _buildColorPickerSection(),
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

  Widget _buildSvgLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo SVG',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        // Aperçu du logo avec la couleur
        if (_svgData != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: SvgLogoWidget(
                    svgData: _svgData,
                    colorHex: '#${_groupColor.red.toRadixString(16).padLeft(2, '0')}'
                        '${_groupColor.green.toRadixString(16).padLeft(2, '0')}'
                        '${_groupColor.blue.toRadixString(16).padLeft(2, '0')}',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Boutons d'action
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _svgData != null ? 'Logo SVG chargé ✓' : 'Aucun logo SVG',
                  style: TextStyle(
                    color: _svgData != null ? Colors.green : Colors.grey,
                    fontWeight: _svgData != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickSvgFile,
              icon: const Icon(Icons.file_upload),
              label: Text(_svgData != null ? 'Changer' : 'Choisir SVG'),
            ),
            if (_svgData != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Supprimer le logo',
                onPressed: () {
                  setState(() {
                    _svgData = null;
                  });
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildColorPickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Couleur du groupe',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _groupColor,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showColorPicker,
              icon: const Icon(Icons.palette),
              label: const Text('Choisir la couleur'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickSvgFile() async {
    try {
      print('🎨 Ouverture du file picker SVG...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg'],
      );

      if (result != null && result.files.single.path != null) {
        print('📁 Fichier sélectionné: ${result.files.single.path}');
        // Lire le fichier SVG depuis le path (Windows compatible)
        final file = File(result.files.single.path!);
        final svgString = await file.readAsString();
        print('📄 Contenu SVG lu: ${svgString.length} caractères');
        final base64Svg = base64Encode(utf8.encode(svgString));
        print('🔐 Base64 encodé: ${base64Svg.length} caractères');
        
        setState(() {
          _svgData = base64Svg;
          print('✅ _svgData mis à jour dans setState');
        });
        
        print('📊 État actuel - _svgData: ${_svgData != null ? "${_svgData!.length} chars" : "null"}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logo SVG chargé avec succès')),
          );
        }
      } else {
        print('❌ Aucun fichier sélectionné ou path null');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement du SVG: $e')),
        );
      }
    }
  }

  void _showColorPicker() {
    print('🎨 Ouverture du color picker, couleur actuelle: $_groupColor');
    Color tempColor = _groupColor;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Text('Choisir une couleur'),
                  const Spacer(),
                  // Aperçu du logo avec la couleur en temps réel
                  if (_svgData != null)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: SvgLogoWidget(
                          svgData: _svgData,
                          colorHex: '#${tempColor.red.toRadixString(16).padLeft(2, '0')}'
                              '${tempColor.green.toRadixString(16).padLeft(2, '0')}'
                              '${tempColor.blue.toRadixString(16).padLeft(2, '0')}',
                          width: 35,
                          height: 35,
                        ),
                      ),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: tempColor,
                  onColorChanged: (Color color) {
                    print('🎨 Couleur changée: $color');
                    setDialogState(() {
                      tempColor = color;
                    });
                  },
                  pickerAreaHeightPercent: 0.8,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _groupColor = tempColor;
                      print('✅ _groupColor mis à jour: $_groupColor');
                    });
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
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
                  label: Text(
                    keyword,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
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
                      label: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedKeywords.add(keyword);
                        });
                      },
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
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

    print('💾 _saveGroup appelé');
    print('📊 État actuel:');
    print('  - _svgData: ${_svgData != null ? "${_svgData!.length} chars" : "null"}');
    print('  - _groupColor: $_groupColor');

    // Convertir la couleur en format hex (#RRGGBB)
    final colorHex = '#${_groupColor.red.toRadixString(16).padLeft(2, '0')}'
        '${_groupColor.green.toRadixString(16).padLeft(2, '0')}'
        '${_groupColor.blue.toRadixString(16).padLeft(2, '0')}';
    print('  - colorHex: $colorHex');

    final group = BookGroup(
      id: widget.group?.id ?? _generateUuid(),
      title: _titleController.text.trim(),
      key: _titleController.text.trim().toLowerCase().replaceAll(' ', '_'),
      logoPath: null, // Plus utilisé, on garde SVG uniquement
      keywords: _selectedKeywords,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      svgData: _svgData,
      groupColor: colorHex,
    );

    print('💾 BookGroup créé:');
    print('  - svgData: ${group.svgData != null ? "${group.svgData!.length} chars" : "null"}');
    print('  - groupColor: ${group.groupColor}');
    print('💾 GroupFormDialog - Appel onSave pour: ${group.title} (ID: ${group.id})');
    widget.onSave(group);
    Navigator.of(context).pop();
  }
}