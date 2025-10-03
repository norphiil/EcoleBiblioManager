import 'database/database_helper.dart';
import 'google_sheets/google_sheets_service.dart';

/// Service pour synchroniser toute la base locale avec Google Sheets
class FullSyncService {
  final DatabaseHelper _dbHelper;
  final GoogleSheetsService _sheetsService;

  FullSyncService(this._dbHelper, this._sheetsService);

  /// Synchronise toutes les données locales vers Google Sheets
  Future<SyncResult> syncAllToSheets({
    Function(String)? onProgress,
  }) async {
    final result = SyncResult();
    
    try {
      // 1. Synchroniser les groupes de livres
      onProgress?.call('Synchronisation des groupes de livres...');
      final groupsResult = await _syncBookGroups();
      result.groupsSynced = groupsResult.success;
      result.groupsErrors = groupsResult.errors;
      
      // 2. Synchroniser les classes
      onProgress?.call('Synchronisation des classes...');
      final classesResult = await _syncClasses();
      result.classesSynced = classesResult.success;
      result.classesErrors = classesResult.errors;
      
      // 3. Synchroniser les livres
      onProgress?.call('Synchronisation des livres...');
      final booksResult = await _syncBooks();
      result.booksSynced = booksResult.success;
      result.booksErrors = booksResult.errors;
      
      // 4. Synchroniser l'historique des emprunts
      onProgress?.call('Synchronisation de l\'historique...');
      final historyResult = await _syncBorrowHistory();
      result.historySynced = historyResult.success;
      result.historyErrors = historyResult.errors;
      
      onProgress?.call('Synchronisation terminée !');
      result.success = true;
      
    } catch (e) {
      result.success = false;
      result.generalError = e.toString();
    }
    
    return result;
  }

  /// Synchronise les groupes de livres
  Future<_SyncItemResult> _syncBookGroups() async {
    final result = _SyncItemResult();
    
    try {
      final localGroups = await _dbHelper.getAllGroups();
      
      for (final group in localGroups) {
        try {
          // Vérifier si existe dans Sheets
          final sheetsGroups = await _sheetsService.searchBookGroups('id', group.id);
          
          if (sheetsGroups.isEmpty) {
            // Ajouter
            await _sheetsService.addBookGroup(group);
            result.success++;
          } else {
            // Mettre à jour
            await _sheetsService.updateBookGroup(group);
            result.success++;
          }
        } catch (e) {
          result.errors.add('Groupe ${group.title}: $e');
        }
      }
    } catch (e) {
      result.errors.add('Erreur globale groupes: $e');
    }
    
    return result;
  }

  /// Synchronise les classes
  Future<_SyncItemResult> _syncClasses() async {
    final result = _SyncItemResult();
    
    try {
      final localClasses = await _dbHelper.getAllClasses();
      
      for (final classRoom in localClasses) {
        try {
          // Vérifier si existe dans Sheets
          final sheetsClasses = await _sheetsService.searchClasses('id', classRoom.id);
          
          if (sheetsClasses.isEmpty) {
            // Ajouter
            await _sheetsService.addClass(classRoom);
            result.success++;
          } else {
            // Mettre à jour
            await _sheetsService.updateClass(classRoom);
            result.success++;
          }
        } catch (e) {
          result.errors.add('Classe ${classRoom.name}: $e');
        }
      }
    } catch (e) {
      result.errors.add('Erreur globale classes: $e');
    }
    
    return result;
  }

  /// Synchronise les livres
  Future<_SyncItemResult> _syncBooks() async {
    final result = _SyncItemResult();
    
    try {
      final localBooks = await _dbHelper.getAllBooks();
      
      for (final book in localBooks) {
        try {
          // Vérifier si existe dans Sheets
          final sheetsBooks = await _sheetsService.searchBooks('isbn', book.isbn);
          
          if (sheetsBooks.isEmpty) {
            // Ajouter
            await _sheetsService.addBook(book);
            result.success++;
          } else {
            // Mettre à jour
            await _sheetsService.updateBook(book);
            result.success++;
          }
        } catch (e) {
          result.errors.add('Livre ${book.title}: $e');
        }
      }
    } catch (e) {
      result.errors.add('Erreur globale livres: $e');
    }
    
    return result;
  }

  /// Synchronise l'historique des emprunts
  Future<_SyncItemResult> _syncBorrowHistory() async {
    final result = _SyncItemResult();
    
    try {
      final localHistory = await _dbHelper.getAllBorrowHistory();
      
      for (final history in localHistory) {
        try {
          // Vérifier si existe dans Sheets (utiliser l'ID qui ne peut pas être null)
          final historyId = history.id ?? '';
          if (historyId.isEmpty) continue; // Ignorer si pas d'ID
          
          final sheetsHistory = await _sheetsService.searchBorrowHistory('id', historyId);
          
          if (sheetsHistory.isEmpty) {
            // Ajouter
            await _sheetsService.addBorrowHistory(history);
            result.success++;
          } else {
            // Mettre à jour
            await _sheetsService.updateBorrowHistory(history);
            result.success++;
          }
        } catch (e) {
          result.errors.add('Historique ${history.id}: $e');
        }
      }
    } catch (e) {
      result.errors.add('Erreur globale historique: $e');
    }
    
    return result;
  }
}

/// Résultat de la synchronisation complète
class SyncResult {
  bool success = false;
  String? generalError;
  
  int booksSynced = 0;
  List<String> booksErrors = [];
  
  int groupsSynced = 0;
  List<String> groupsErrors = [];
  
  int classesSynced = 0;
  List<String> classesErrors = [];
  
  int historySynced = 0;
  List<String> historyErrors = [];
  
  int get totalSynced => booksSynced + groupsSynced + classesSynced + historySynced;
  int get totalErrors => booksErrors.length + groupsErrors.length + classesErrors.length + historyErrors.length;
  
  bool get hasErrors => totalErrors > 0 || generalError != null;
}

/// Résultat de synchronisation d'un type d'élément
class _SyncItemResult {
  int success = 0;
  List<String> errors = [];
}
