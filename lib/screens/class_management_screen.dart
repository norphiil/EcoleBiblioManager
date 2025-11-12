import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/database/database_helper.dart';
import '../services/database/tracked_database_service.dart';
import '../models/models.dart';

/// Écran de gestion des classes scolaires
class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({Key? key}) : super(key: key);

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  late final DatabaseHelper _dbHelper;
  late final TrackedDatabaseService _trackedDb;
  
  List<ClassRoom> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper();
    _trackedDb = TrackedDatabaseService(_dbHelper);
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final classes = await _dbHelper.getAllClasses();
      setState(() {
        _classes = classes;
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Retour',
        ),
        title: const Text('Gestion des classes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _showCreateClassDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Créer une nouvelle classe',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadClasses,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Aucune classe créée',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cliquez sur + pour créer votre première classe',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateClassDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer une classe'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final classRoom = _classes[index];
        return _buildClassCard(classRoom);
      },
    );
  }

  Widget _buildClassCard(ClassRoom classRoom) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.school,
            color: Colors.blue.shade700,
            size: 28,
          ),
        ),
        title: Text(
          classRoom.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditClassDialog(classRoom),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteClass(classRoom),
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateClassDialog() async {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final List<Student> newStudents = [];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Créer une classe'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la classe *',
                    hintText: 'Ex: 6ème A, CM2, Seconde B...',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire';
                    }
                    if (_classes.any((c) => c.name.toLowerCase() == value.trim().toLowerCase())) {
                      return 'Une classe avec ce nom existe déjà';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Élèves',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddStudentDialog(newStudents, (updatedStudents) {
                          setState(() {
                            // Les élèves sont mis à jour directement dans la liste
                          });
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (newStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Aucun élève ajouté',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: newStudents.length,
                      itemBuilder: (context, index) {
                        final student = newStudents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            title: Text('${student.firstName} ${student.lastName}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  newStudents.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _createClass(nameController.text.trim(), newStudents);
    }
  }

  void _showAddStudentDialog(List<Student> students, Function(List<Student>) onUpdate) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un élève'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom *',
                  hintText: 'Ex: Jean',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le prénom est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  hintText: 'Ex: Dupont',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newStudent = Student(
                  id: '${DateTime.now().millisecondsSinceEpoch}-${firstNameController.text.hashCode}',
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  classId: '', // Sera défini à la création de la classe
                );
                students.add(newStudent);
                onUpdate(students);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _createClass(String name, List<Student> students) async {
    try {
      final now = DateTime.now();
      final newClass = ClassRoom(
        id: '${now.millisecondsSinceEpoch}-${name.hashCode}',
        name: name,
        students: students,
      );

      await _trackedDb.addClass(newClass);

      // Ajouter les élèves à la base de données
      for (final student in students) {
        final studentWithClass = student.copyWith(classId: newClass.id);
        await _trackedDb.addStudent(studentWithClass);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Classe "$name" créée avec succès (${students.length} élève(s))'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditClassDialog(ClassRoom classRoom) async {
    final TextEditingController nameController = TextEditingController(text: classRoom.name);
    final formKey = GlobalKey<FormState>();
    final editingStudents = List<Student>.from(classRoom.students);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier la classe'),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la classe *',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le nom est obligatoire';
                    }
                    if (_classes.any((c) => 
                        c.id != classRoom.id && 
                        c.name.toLowerCase() == value.trim().toLowerCase())) {
                      return 'Une classe avec ce nom existe déjà';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Élèves',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddStudentDialog(editingStudents, (updatedStudents) {
                          setState(() {
                            // Les élèves sont mis à jour directement dans la liste
                          });
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (editingStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Aucun élève ajouté',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editingStudents.length,
                      itemBuilder: (context, index) {
                        final student = editingStudents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            dense: true,
                            title: Text('${student.firstName} ${student.lastName}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  editingStudents.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await _updateClass(classRoom, nameController.text.trim(), editingStudents);
    }
  }

  Future<void> _updateClass(ClassRoom classRoom, String newName, List<Student> updatedStudents) async {
    try {
      final updatedClass = classRoom.copyWith(
        name: newName,
        students: updatedStudents,
      );

      await _trackedDb.updateClass(updatedClass);

      // Gérer les changements d'élèves
      // 1. Récupérer les anciens élèves
      final oldStudents = classRoom.students;
      
      // 2. Supprimer les élèves qui ont été supprimés
      for (final oldStudent in oldStudents) {
        if (!updatedStudents.any((s) => s.id == oldStudent.id)) {
          await _trackedDb.deleteStudent(oldStudent.id);
        }
      }
      
      // 3. Ajouter ou mettre à jour les élèves
      for (final student in updatedStudents) {
        if (oldStudents.any((s) => s.id == student.id)) {
          // Élève existant, le mettre à jour avec le bon classId
          final updatedStudent = student.copyWith(classId: classRoom.id);
          await _trackedDb.updateStudent(updatedStudent);
        } else {
          // Nouvel élève, l'ajouter avec le bon classId
          final studentWithClass = student.copyWith(classId: classRoom.id);
          await _trackedDb.addStudent(studentWithClass);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Classe modifiée avec succès (${updatedStudents.length} élève(s))'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteClass(ClassRoom classRoom) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer la classe "${classRoom.name}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteClass(classRoom);
    }
  }

  Future<void> _deleteClass(ClassRoom classRoom) async {
    try {
      // Supprimer tous les élèves de la classe (cascade) - avec tracking
      await _trackedDb.deleteStudentsByClass(classRoom.id);
      
      // Supprimer la classe - avec tracking
      await _trackedDb.deleteClass(classRoom.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Classe "${classRoom.name}" supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
