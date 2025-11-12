import 'dart:async';
import 'package:logger/logger.dart';
import '../../models/models.dart';
import '../google_sheets/google_sheets_service.dart';
import 'database_helper.dart';

/// Service de synchronisation intelligente entre la base locale et Google Sheets
class SyncService {
  final DatabaseHelper _dbHelper;
  final GoogleSheetsService _sheetsService;
  final Logger _logger = Logger();
  
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _periodicSyncTimer;
  
  // Snapshot de la BDD avant la sync (pour ne pas être perturbé par les modifications)
  List<Book>? _booksSnapshot;
  List<BookGroup>? _groupsSnapshot;
  List<ClassRoom>? _classesSnapshot;
  List<Student>? _studentsSnapshot;

  SyncService(this._dbHelper, this._sheetsService);

  /// Indique si une synchronisation est en cours
  bool get isSyncing => _isSyncing;

  /// Date de la dernière synchronisation
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Démarre la synchronisation périodique en arrière-plan
  void startPeriodicSync({Duration interval = const Duration(minutes: 1)}) {
    _logger.i('🔄 Démarrage de la synchronisation périodique (${interval.inMinutes} min)');
    
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(interval, (_) async {
      if (!_isSyncing) {
        await syncAll();
      } else {
        _logger.w('⏭️  Synchronisation ignorée : une sync est déjà en cours');
      }
    });
  }

  /// Arrête la synchronisation périodique
  void stopPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _logger.i('⏸️  Synchronisation périodique arrêtée');
  }

  /// Synchronise toutes les données (livres + groupes)
  Future<void> syncAll() async {
    if (_isSyncing) {
      _logger.w('⏭️  Sync déjà en cours, ignorée');
      return;
    }

    _isSyncing = true;
    _logger.i('🔄 ========== DÉBUT DE LA SYNCHRONISATION ==========');

    try {
      // 1. Créer un snapshot de la BDD actuelle
      await _createSnapshot();
      
      // 2. Synchroniser les classes d'abord
      await _syncClasses();
      
      // 3. Synchroniser les élèves (car ils dépendent des classes)
      await _syncStudents();
      
      // 4. Synchroniser les groupes (car les livres y font référence)
      await _syncGroups();
      
      // 5. Synchroniser les livres
      await _syncBooks();
      
      // 4. Enregistrer la date de dernière sync
      _lastSyncTime = DateTime.now();
      await _dbHelper.setLastSyncTime(_lastSyncTime!);
      
      _logger.i('✅ ========== SYNCHRONISATION TERMINÉE ==========');
    } catch (e, stackTrace) {
      _logger.e('❌ Erreur lors de la synchronisation', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      _isSyncing = false;
      _booksSnapshot = null;
      _groupsSnapshot = null;
      _classesSnapshot = null;
      _studentsSnapshot = null;
    }
  }

  /// Crée un snapshot de la BDD avant la synchronisation
  Future<void> _createSnapshot() async {
    _logger.i('📸 Création du snapshot de la base de données');
    _booksSnapshot = await _dbHelper.getAllBooks();
    _groupsSnapshot = await _dbHelper.getAllGroups();
    _classesSnapshot = await _dbHelper.getAllClasses();
    _studentsSnapshot = await _dbHelper.getAllStudents();
    _logger.i('📸 Snapshot créé : ${_booksSnapshot!.length} livres, ${_groupsSnapshot!.length} groupes, ${_classesSnapshot!.length} classes, ${_studentsSnapshot!.length} élèves');
  }

  /// Synchronise les classes de manière bidirectionnelle
  Future<void> _syncClasses() async {
    _logger.i('🏫 ========== SYNCHRONISATION DES CLASSES ==========');
    
    // Récupérer les classes de Google Sheets
    final remoteClasses = await _sheetsService.getAllClasses();
    _logger.i('☁️  ${remoteClasses.length} classes sur Google Sheets');
    
    // Récupérer les classes locales (depuis le snapshot)
    final localClasses = _classesSnapshot ?? [];
    _logger.i('💾 ${localClasses.length} classes en local');
    
    // Créer des maps pour accès rapide
    final remoteClassesMap = {for (var c in remoteClasses) c.id: c};
    final localClassesMap = {for (var c in localClasses) c.id: c};
    
    // 1. Classes présentes en remote mais pas en local → Ajouter en local
    for (final remoteClass in remoteClasses) {
      if (!localClassesMap.containsKey(remoteClass.id)) {
        _logger.i('⬇️  Ajout de la classe remote "${remoteClass.name}" en local');
        await _dbHelper.addClass(remoteClass);
      }
    }
    
    // 2. Classes présentes en local mais pas en remote → Ajouter en remote
    for (final localClass in localClasses) {
      if (!remoteClassesMap.containsKey(localClass.id)) {
        _logger.i('⬆️  Ajout de la classe locale "${localClass.name}" sur Google Sheets');
        await _sheetsService.addClass(localClass);
      }
    }
    
    // 3. Classes présentes des deux côtés → Synchroniser les modifications
    for (final localClass in localClasses) {
      final remoteClass = remoteClassesMap[localClass.id];
      if (remoteClass != null && localClass.name != remoteClass.name) {
        _logger.i('🔄 Mise à jour de la classe "${localClass.name}" sur Google Sheets');
        await _sheetsService.updateClass(localClass);
      }
    }
    
    _logger.i('✅ Synchronisation des classes terminée');
  }

  /// Synchronise les élèves de manière bidirectionnelle
  Future<void> _syncStudents() async {
    _logger.i('👨‍🎓 ========== SYNCHRONISATION DES ÉLÈVES ==========');
    
    // Récupérer les élèves de Google Sheets
    final remoteStudents = await _sheetsService.getAllStudents();
    _logger.i('☁️  ${remoteStudents.length} élèves sur Google Sheets');
    
    // Récupérer les élèves locaux (depuis le snapshot)
    final localStudents = _studentsSnapshot ?? [];
    _logger.i('💾 ${localStudents.length} élèves en local');
    
    // Créer des maps pour accès rapide
    final remoteStudentsMap = {for (var s in remoteStudents) s.id: s};
    final localStudentsMap = {for (var s in localStudents) s.id: s};
    
    // 1. Élèves présents en remote mais pas en local → Ajouter en local
    for (final remoteStudent in remoteStudents) {
      if (!localStudentsMap.containsKey(remoteStudent.id)) {
        _logger.i('⬇️  Ajout de l\'élève remote "${remoteStudent.fullName}" en local');
        await _dbHelper.addStudent(remoteStudent);
      }
    }
    
    // 2. Élèves présents en local mais pas en remote → Ajouter en remote
    for (final localStudent in localStudents) {
      if (!remoteStudentsMap.containsKey(localStudent.id)) {
        _logger.i('⬆️  Ajout de l\'élève local "${localStudent.fullName}" sur Google Sheets');
        await _sheetsService.addStudent(localStudent);
      }
    }
    
    // 3. Élèves présents des deux côtés → Synchroniser les modifications
    for (final localStudent in localStudents) {
      final remoteStudent = remoteStudentsMap[localStudent.id];
      if (remoteStudent != null) {
        // Vérifier si l'élève local a été modifié
        if (localStudent.firstName != remoteStudent.firstName ||
            localStudent.lastName != remoteStudent.lastName ||
            localStudent.classId != remoteStudent.classId) {
          _logger.i('🔄 Mise à jour de l\'élève "${localStudent.fullName}" sur Google Sheets');
          await _sheetsService.updateStudent(localStudent);
        }
      }
    }
    
    _logger.i('✅ Synchronisation des élèves terminée');
  }

  /// Synchronise les groupes de manière bidirectionnelle
  Future<void> _syncGroups() async {
    _logger.i('📚 ========== SYNCHRONISATION DES GROUPES ==========');
    
    // Récupérer les groupes de Google Sheets
    final remoteGroups = await _sheetsService.getAllBookGroups();
    _logger.i('☁️  ${remoteGroups.length} groupes sur Google Sheets');
    
    // Récupérer les groupes locaux (depuis le snapshot)
    final localGroups = _groupsSnapshot ?? [];
    _logger.i('💾 ${localGroups.length} groupes en local');
    
    // Créer des maps pour accès rapide
    final remoteGroupsMap = {for (var g in remoteGroups) g.id: g};
    final localGroupsMap = {for (var g in localGroups) g.id: g};
    
    // 1. Groupes présents en remote mais pas en local → Ajouter en local
    for (final remoteGroup in remoteGroups) {
      if (!localGroupsMap.containsKey(remoteGroup.id)) {
        _logger.i('⬇️  Ajout du groupe remote "${remoteGroup.title}" en local');
        await _dbHelper.insertGroup(remoteGroup);
        await _dbHelper.markGroupAsSynced(remoteGroup.id);
      }
    }
    
    // 2. Groupes présents en local mais pas en remote → Ajouter en remote
    for (final localGroup in localGroups) {
      if (!remoteGroupsMap.containsKey(localGroup.id)) {
        _logger.i('⬆️  Ajout du groupe local "${localGroup.title}" sur Google Sheets');
        await _sheetsService.addBookGroup(localGroup);
        await _dbHelper.markGroupAsSynced(localGroup.id);
      }
    }
    
    // 3. Groupes présents des deux côtés → Synchroniser les modifications
    final pendingGroups = await _dbHelper.getPendingGroups();
    for (final localGroup in pendingGroups) {
      if (remoteGroupsMap.containsKey(localGroup.id)) {
        _logger.i('🔄 Mise à jour du groupe "${localGroup.title}" sur Google Sheets');
        await _sheetsService.updateBookGroup(localGroup);
        await _dbHelper.markGroupAsSynced(localGroup.id);
      }
    }
    
    _logger.i('✅ Synchronisation des groupes terminée');
  }

  /// Synchronise les livres de manière bidirectionnelle
  Future<void> _syncBooks() async {
    _logger.i('📖 ========== SYNCHRONISATION DES LIVRES ==========');
    
    // Récupérer les livres de Google Sheets
    final remoteBooks = await _sheetsService.getAllBooks();
    _logger.i('☁️  ${remoteBooks.length} livres sur Google Sheets');
    
    // Récupérer les livres locaux (depuis le snapshot)
    final localBooks = _booksSnapshot ?? [];
    _logger.i('💾 ${localBooks.length} livres en local');
    
    // Créer des maps pour accès rapide
    final remoteBooksMap = {for (var b in remoteBooks) b.isbn: b};
    final localBooksMap = {for (var b in localBooks) b.isbn: b};
    
    // 1. Livres présents en remote mais pas en local → Ajouter en local
    for (final remoteBook in remoteBooks) {
      if (!localBooksMap.containsKey(remoteBook.isbn)) {
        _logger.i('⬇️  Ajout du livre remote "${remoteBook.title}" en local');
        await _dbHelper.insertBook(remoteBook);
        await _dbHelper.markBookAsSynced(remoteBook.isbn);
      }
    }
    
    // 2. Livres présents en local mais pas en remote → Ajouter en remote
    for (final localBook in localBooks) {
      if (!remoteBooksMap.containsKey(localBook.isbn)) {
        _logger.i('⬆️  Ajout du livre local "${localBook.title}" sur Google Sheets');
        await _sheetsService.addBook(localBook);
        await _dbHelper.markBookAsSynced(localBook.isbn);
      }
    }
    
    // 3. Livres présents des deux côtés → Gérer les conflits intelligemment
    await _syncConflictingBooks(localBooks, remoteBooks);
    
    // 4. Synchroniser les livres modifiés localement
    final pendingBooks = await _dbHelper.getPendingBooks();
    for (final localBook in pendingBooks) {
      if (remoteBooksMap.containsKey(localBook.isbn)) {
        _logger.i('🔄 Mise à jour du livre "${localBook.title}" sur Google Sheets');
        await _sheetsService.updateBook(localBook);
        await _dbHelper.markBookAsSynced(localBook.isbn);
      }
    }
    
    _logger.i('✅ Synchronisation des livres terminée');
  }

  /// Gère les conflits pour les livres présents des deux côtés
  Future<void> _syncConflictingBooks(List<Book> localBooks, List<Book> remoteBooks) async {
    _logger.i('⚔️  Gestion des conflits de livres');
    
    final remoteBooksMap = {for (var b in remoteBooks) b.isbn: b};
    
    for (final localBook in localBooks) {
      final remoteBook = remoteBooksMap[localBook.isbn];
      if (remoteBook == null) continue;
      
      // Comparer les dates de modification
      final localModified = localBook.lastModified ?? DateTime(2000);
      final remoteModified = remoteBook.lastModified ?? DateTime(2000);
      
      if (remoteModified.isAfter(localModified)) {
        // La version remote est plus récente → Mettre à jour en local
        if (_hasBookChanged(localBook, remoteBook)) {
          _logger.i('⬇️  Mise à jour locale du livre "${remoteBook.title}" (remote plus récent)');
          await _dbHelper.updateBook(remoteBook);
          await _dbHelper.markBookAsSynced(remoteBook.isbn);
        }
      } else if (localModified.isAfter(remoteModified)) {
        // La version locale est plus récente → Mettre à jour en remote
        if (_hasBookChanged(localBook, remoteBook)) {
          _logger.i('⬆️  Mise à jour remote du livre "${localBook.title}" (local plus récent)');
          await _sheetsService.updateBook(localBook);
          await _dbHelper.markBookAsSynced(localBook.isbn);
        }
      }
      // Si les dates sont identiques, pas de modification à faire
    }
  }

  /// Vérifie si deux livres sont différents
  bool _hasBookChanged(Book book1, Book book2) {
    return book1.title != book2.title ||
        book1.author != book2.author ||
        book1.groupId != book2.groupId ||
        book1.status != book2.status ||
        book1.borrowedBy != book2.borrowedBy;
  }

  /// Synchronisation initiale (au démarrage de l'app)
  Future<void> initialSync() async {
    _logger.i('🚀 Synchronisation initiale au démarrage');
    
    // Vérifier si c'est vraiment la première sync
    final lastSync = await _dbHelper.getLastSyncTime();
    if (lastSync == null) {
      _logger.i('🆕 Première synchronisation - Import complet depuis Google Sheets');
      await _fullSyncFromRemote();
    } else {
      _logger.i('🔄 Synchronisation normale (dernière sync: $lastSync)');
      await syncAll();
    }
  }

  /// Synchronisation complète depuis Google Sheets (première fois)
  Future<void> _fullSyncFromRemote() async {
    _logger.i('📥 Import complet depuis Google Sheets');
    
    try {
      // Vider la base locale
      await _dbHelper.clearAllData();
      
      // Importer toutes les classes
      final remoteClasses = await _sheetsService.getAllClasses();
      _logger.i('📥 Import de ${remoteClasses.length} classes');
      for (final classRoom in remoteClasses) {
        await _dbHelper.addClass(classRoom);
      }
      
      // Importer tous les élèves
      final remoteStudents = await _sheetsService.getAllStudents();
      _logger.i('📥 Import de ${remoteStudents.length} élèves');
      for (final student in remoteStudents) {
        await _dbHelper.addStudent(student);
      }
      
      // Importer tous les groupes
      final remoteGroups = await _sheetsService.getAllBookGroups();
      _logger.i('📥 Import de ${remoteGroups.length} groupes');
      for (final group in remoteGroups) {
        await _dbHelper.insertGroup(group);
        await _dbHelper.markGroupAsSynced(group.id);
      }
      
      // Importer tous les livres
      final remoteBooks = await _sheetsService.getAllBooks();
      _logger.i('📥 Import de ${remoteBooks.length} livres');
      for (final book in remoteBooks) {
        await _dbHelper.insertBook(book);
        await _dbHelper.markBookAsSynced(book.isbn);
      }
      
      // Enregistrer la date de sync
      _lastSyncTime = DateTime.now();
      await _dbHelper.setLastSyncTime(_lastSyncTime!);
      
      _logger.i('✅ Import complet terminé');
    } catch (e, stackTrace) {
      _logger.e('❌ Erreur lors de l\'import complet', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Force une synchronisation immédiate
  Future<void> forceSyncNow() async {
    _logger.i('⚡ Synchronisation forcée');
    await syncAll();
  }

  /// Nettoie les ressources
  void dispose() {
    stopPeriodicSync();
  }
}
