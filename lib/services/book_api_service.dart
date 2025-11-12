import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/models.dart';
import '../core/utils/logger.dart';

/// Service pour récupérer les informations des livres via l'API OpenLibrary (gratuite)
class BookApiService {
  static const Duration _timeout = Duration(seconds: 10);
  
  final Logger _logger;
  final Map<String, Book> _cache = {};

  BookApiService() : _logger = Logger('BookApiService');

  /// Recherche un livre par ISBN
  Future<Book?> getBookByIsbn(String isbn) async {
    try {
      // Nettoie l'ISBN
      final cleanIsbn = _cleanIsbn(isbn);
      
      // Validation préalable pour éviter les recherches inutiles
      if (!_isPlausibleIsbn(cleanIsbn)) {
        _logger.info('ISBN non plausible ignoré: $isbn');
        return null;
      }
      
      // Vérifie le cache
      if (_cache.containsKey(cleanIsbn)) {
        _logger.info('Livre trouvé dans le cache pour ISBN: $cleanIsbn');
        return _cache[cleanIsbn];
      }

      _logger.info('Recherche du livre par ISBN: $cleanIsbn');
      
      // Essaie d'abord l'API Books
      Book? book = await _fetchFromBooksApi(cleanIsbn);
      
      if (book != null) {
        _cache[cleanIsbn] = book;
        _logger.info('Livre trouvé: ${book.title} par ${book.author}');
      } else {
        _logger.warning('Aucun livre trouvé pour l\'ISBN: $cleanIsbn');
      }
      
      return book;
    } catch (e) {
      _logger.error('Erreur lors de la recherche par ISBN $isbn', e);
      return null;
    }
  }
  
  /// Vérifie si un ISBN est plausible avant de faire des appels API
  bool _isPlausibleIsbn(String cleanIsbn) {
    // Doit avoir 10 ou 13 caractères
    if (cleanIsbn.length != 10 && cleanIsbn.length != 13) {
      return false;
    }
    
    // ISBN-13 doit commencer par 978 ou 979
    if (cleanIsbn.length == 13 && !cleanIsbn.startsWith('978') && !cleanIsbn.startsWith('979')) {
      return false;
    }
    
    // Doit être principalement numérique (seul X autorisé à la fin pour ISBN-10)
    final pattern = cleanIsbn.length == 10 
        ? RegExp(r'^\d{9}[\dX]$')
        : RegExp(r'^\d{13}$');
    
    return pattern.hasMatch(cleanIsbn);
  }

  /// Recherche un livre sur l'API Books d'OpenLibrary
  Future<Book?> _fetchFromOpenLibrary(String isbn) async {
    final url = 'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&jscmd=data&format=json';

    final response = await http.get(Uri.parse(url)).timeout(_timeout);
    
    if (response.statusCode != 200) {
      return null;
    }
    
    final data = json.decode(response.body);
    _logger.info("data: $data");
    if (data.isEmpty) {
      return null;
    }
    
    final bookData = data['ISBN:$isbn'];
    if (bookData == null) {
      return null;
    }

    return Book.fromOpenLibraryResponse(bookData, isbn);
  }

  /// Recherche un livre sur l'API Books de google api
  Future<Book?> _fetchFromGoogleBooks(String isbn) async {
    final url = "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn";

    final response = await http.get(Uri.parse(url)).timeout(_timeout);

    if (response.statusCode != 200) {
      return null;
    }

    final data = json.decode(response.body);
    if (data['totalItems'] == 0) {
      return null;
    }

    final bookData = data['items'][0]['volumeInfo'];

    return Book.fromGoogleBooksResponse(bookData, isbn);
  }

  /// Recherche un livre sur l'API SRU de la BNF (Bibliothèque Nationale de France)
  Future<Book?> _fetchFromBNF(String isbn) async {
    try {
      final url = 'https://catalogue.bnf.fr/api/SRU?version=1.2&operation=searchRetrieve&query=bib.isbn%20adj%20%22$isbn%22&recordSchema=dublincore';
      
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      
      if (response.statusCode != 200) {
        _logger.warning('BNF API retourned status code: ${response.statusCode}');
        return null;
      }
      
      final document = XmlDocument.parse(response.body);
      
      // Cherche le nombre de résultats
      final numberOfRecords = document.findAllElements('srw:numberOfRecords').firstOrNull?.innerText;
      if (numberOfRecords == null || numberOfRecords == '0') {
        _logger.info('Aucun résultat trouvé sur la BNF pour ISBN: $isbn');
        return null;
      }
      
      // Cherche le premier enregistrement
      final record = document.findAllElements('srw:record').firstOrNull;
      if (record == null) {
        return null;
      }
      
      final recordData = record.findAllElements('oai_dc:dc').firstOrNull;
      if (recordData == null) {
        return null;
      }
      
      // Extraction des métadonnées Dublin Core
      final title = recordData.findAllElements('dc:title').firstOrNull?.innerText ?? '';
      final creators = recordData.findAllElements('dc:creator').map((e) => e.innerText).toList();
      final author = creators.isNotEmpty ? creators.first : 'Auteur inconnu';
      final publisher = recordData.findAllElements('dc:publisher').firstOrNull?.innerText;
      final dateStr = recordData.findAllElements('dc:date').firstOrNull?.innerText;
      int? publishYear = dateStr != null ? int.tryParse(dateStr) : null;
      final description = recordData.findAllElements('dc:description').firstOrNull?.innerText;
      
      // Extraction des langues
      final languages = recordData.findAllElements('dc:language').map((e) => e.innerText).toList();
      
      _logger.info('Livre trouvé sur BNF: $title par $author');
      
      return Book(
        isbn: isbn,
        title: title,
        author: author,
        description: description,
        publisher: publisher,
        publishYear: publishYear,
        subjects: languages,
      );
    } catch (e) {
      _logger.warning('Erreur BNF API pour ISBN $isbn', e);
      return null;
    }
  }

  Future<Book?> _fetchFromBooksApi(String isbn) async {
    try {
      Book? book1 = await _fetchFromGoogleBooks(isbn);
      Book? book2 = await _fetchFromOpenLibrary(isbn);
      Book? book3 = await _fetchFromBNF(isbn);
      
      _logger.info("book1: $book1");
      _logger.info("book2: $book2");
      _logger.info("book3: $book3");
      
      // Concatène les livres de manière sécurisée
      Book? book;
      
      // Première concaténation
      if (book1 != null || book2 != null) {
        book = Book.concat(book1, book2);
      } else {
        book = null;
      }
      
      // Deuxième concaténation
      if (book != null || book3 != null) {
        book = Book.concat(book, book3);
      }
      
      _logger.info("book: ${book?.toJson()}");
      return book;
    } catch (e) {
      _logger.warning('Erreur Books API pour ISBN $isbn', e);
      return null;
    }
  }

  /// Nettoie un ISBN (retire les tirets et espaces)
  String _cleanIsbn(String isbn) {
    return isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
  }

  /// Valide un ISBN-10
  bool _isValidIsbn10(String isbn) {
    if (isbn.length != 10) return false;
    
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (10 - i);
    }
    
    final lastChar = isbn[9];
    final checkDigit = lastChar == 'X' ? 10 : int.tryParse(lastChar);
    if (checkDigit == null) return false;
    
    return (sum + checkDigit) % 11 == 0;
  }

  /// Valide un ISBN-13
  bool _isValidIsbn13(String isbn) {
    if (isbn.length != 13) return false;
    
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      sum += digit * (i.isEven ? 1 : 3);
    }
    
    final checkDigit = int.tryParse(isbn[12]);
    if (checkDigit == null) return false;
    
    final calculatedCheckDigit = (10 - (sum % 10)) % 10;
    return checkDigit == calculatedCheckDigit;
  }

  /// Valide un ISBN (10 ou 13 chiffres)
  bool isValidIsbn(String isbn) {
    final clean = _cleanIsbn(isbn);
    return _isValidIsbn10(clean) || _isValidIsbn13(clean);
  }

  /// Vide le cache
  void clearCache() {
    _cache.clear();
    _logger.info('Cache vidé');
  }

  /// Récupère la taille du cache
  int getCacheSize() => _cache.length;
}

/// Exception spécifique à l'API des livres
class BookApiException extends AppException {
  const BookApiException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}