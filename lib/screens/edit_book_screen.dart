import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Écran pour modifier manuellement les informations d'un livre
class EditBookScreen extends StatefulWidget {
  final Book book;
  
  const EditBookScreen({
    Key? key,
    required this.book,
  }) : super(key: key);

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  late final LocalDatabaseService _localDbService;
  
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _publisherController;
  late TextEditingController _publishYearController;
  late TextEditingController _publishPlaceController;
  late TextEditingController _pageCountController;
  late TextEditingController _coverImageUrlController;
  late TextEditingController _subjectsController;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _publisherController = TextEditingController(text: widget.book.publisher ?? '');
    _publishYearController = TextEditingController(
      text: widget.book.publishYear?.toString() ?? '',
    );
    _publishPlaceController = TextEditingController(text: widget.book.publishPlace ?? '');
    _pageCountController = TextEditingController(
      text: widget.book.pageCount?.toString() ?? '',
    );
    _coverImageUrlController = TextEditingController(text: widget.book.coverImageUrl ?? '');
    _subjectsController = TextEditingController(
      text: widget.book.subjects.join(', '),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localDbService = context.read<LocalDatabaseService>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _publishYearController.dispose();
    _publishPlaceController.dispose();
    _pageCountController.dispose();
    _coverImageUrlController.dispose();
    _subjectsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le livre'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Enregistrer',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ISBN (non modifiable)
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ISBN (non modifiable)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.book.isbn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Titre
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                hintText: 'Titre du livre',
                prefixIcon: Icon(Icons.book),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le titre est obligatoire';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Auteur
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Auteur *',
                hintText: 'Nom de l\'auteur',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'L\'auteur est obligatoire';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Éditeur
            TextFormField(
              controller: _publisherController,
              decoration: const InputDecoration(
                labelText: 'Éditeur',
                hintText: 'Nom de l\'éditeur',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Année de publication et lieu
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _publishYearController,
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      hintText: '2024',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final year = int.tryParse(value);
                        if (year == null || year < 1000 || year > 2100) {
                          return 'Année invalide';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _publishPlaceController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu',
                      hintText: 'Paris',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Nombre de pages
            TextFormField(
              controller: _pageCountController,
              decoration: const InputDecoration(
                labelText: 'Nombre de pages',
                hintText: '350',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final pages = int.tryParse(value);
                  if (pages == null || pages <= 0) {
                    return 'Nombre invalide';
                  }
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // URL de la couverture
            TextFormField(
              controller: _coverImageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de la couverture',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.image),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // Genres/Sujets
            TextFormField(
              controller: _subjectsController,
              decoration: const InputDecoration(
                labelText: 'Genres/Sujets',
                hintText: 'Science-fiction, Aventure, Roman...',
                helperText: 'Séparez les genres par des virgules',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 32),
            
            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Créer un livre mis à jour avec les nouvelles valeurs
      final updatedBook = Book(
        isbn: widget.book.isbn,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        publisher: _publisherController.text.trim().isEmpty 
            ? null 
            : _publisherController.text.trim(),
        publishYear: _publishYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_publishYearController.text.trim()),
        publishPlace: _publishPlaceController.text.trim().isEmpty
            ? null
            : _publishPlaceController.text.trim(),
        pageCount: _pageCountController.text.trim().isEmpty
            ? null
            : int.tryParse(_pageCountController.text.trim()),
        coverImageUrl: _coverImageUrlController.text.trim().isEmpty
            ? null
            : _coverImageUrlController.text.trim(),
        subjects: _subjectsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        groupId: widget.book.groupId,
        status: widget.book.status,
        borrowedBy: widget.book.borrowedBy,
        borrowerClassName: widget.book.borrowerClassName,
        borrowedDate: widget.book.borrowedDate,
      );

      // Mettre à jour dans la base de données
      await _localDbService.updateBook(updatedBook);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Livre mis à jour avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Retourner avec le livre mis à jour
        Navigator.of(context).pop(updatedBook);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
