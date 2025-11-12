import 'base_model.dart';

/// Modèle pour représenter un groupe de livres (catégorie de rangement)
class BookGroup extends Synchronizable {
  String id;
  String title;
  String key; // Clé unique sans caractères spéciaux, sans espaces, en majuscules
  String? logoPath; // Chemin vers l'image/logo du groupe (deprecated, utiliser svgData)
  String? svgData; // Données SVG encodées en base64
  String? groupColor; // Couleur du groupe en format hexadécimal (ex: "#FF5733")
  List<String> keywords; // Mots-clés pour l'association automatique
  String? description;
  
  // Métadonnées
  DateTime? lastModified;
  bool _isDirty;
  Map<String, dynamic> _changes = {};

  BookGroup({
    required this.id,
    required this.title,
    required this.key,
    this.logoPath,
    this.svgData,
    this.groupColor,
    this.keywords = const [],
    this.description,
    this.lastModified,
  }) : _isDirty = false;

  /// Génère une clé unique à partir du titre
  static String generateKey(String title) {
    return title
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceAll(' ', '');
  }

  /// Constructeur avec génération automatique de la clé
  factory BookGroup.withAutoKey({
    required String id,
    required String title,
    String? logoPath,
    String? svgData,
    String? groupColor,
    List<String> keywords = const [],
    String? description,
    DateTime? lastModified,
  }) {
    return BookGroup(
      id: id,
      title: title,
      key: generateKey(title),
      logoPath: logoPath,
      svgData: svgData,
      groupColor: groupColor,
      keywords: keywords,
      description: description,
      lastModified: lastModified,
    );
  }

  /// Constructeur depuis les données Google Sheets
  factory BookGroup.fromSheetRow(List<dynamic> row) {
    return BookGroup(
      id: row.isNotEmpty ? row[0]?.toString() ?? '' : '',
      title: row.length > 1 ? row[1]?.toString() ?? '' : '',
      key: row.length > 2 ? row[2]?.toString() ?? '' : '',
      logoPath: row.length > 3 && row[3]?.toString().isNotEmpty == true ? row[3].toString() : null,
      svgData: row.length > 4 && row[4]?.toString().isNotEmpty == true ? row[4].toString() : null,
      groupColor: row.length > 5 && row[5]?.toString().isNotEmpty == true ? row[5].toString() : null,
      keywords: row.length > 6 && row[6]?.toString().isNotEmpty == true 
          ? row[6].toString().split(';').map((e) => e.trim()).toList() 
          : [],
      description: row.length > 7 && row[7]?.toString().isNotEmpty == true ? row[7].toString() : null,
      lastModified: row.length > 8 && row[8]?.toString().isNotEmpty == true 
          ? DateTime.tryParse(row[8].toString()) 
          : null,
    );
  }

  /// Calcule le score de correspondance avec les genres d'un livre
  int calculateMatchScore(List<String> bookSubjects) {
    if (bookSubjects.isEmpty || keywords.isEmpty) return 0;
    
    int score = 0;
    for (String subject in bookSubjects) {
      for (String keyword in keywords) {
        if (subject.toLowerCase().contains(keyword.toLowerCase()) ||
            keyword.toLowerCase().contains(subject.toLowerCase())) {
          score++;
        }
      }
    }
    return score;
  }

  /// Vérifie si ce groupe correspond aux sujets d'un livre
  bool matches(List<String> bookSubjects) {
    return calculateMatchScore(bookSubjects) > 0;
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'key': key,
      'logoPath': logoPath,
      'svgData': svgData,
      'groupColor': groupColor,
      'keywords': keywords,
      'description': description,
      'lastModified': lastModified?.toIso8601String(),
    };
  }

  /// Convertit en ligne pour Google Sheets
  List<dynamic> toSheetRow() {
    return [
      id,
      title,
      key,
      logoPath ?? '',
      svgData ?? '',
      groupColor ?? '',
      keywords.join(';'),
      description ?? '',
      lastModified?.toIso8601String() ?? DateTime.now().toIso8601String(),
    ];
  }

  /// Constructeur depuis Supabase JSON
  factory BookGroup.fromSupabaseJson(Map<String, dynamic> json) {
    return BookGroup(
      id: json['key'] as String, // Supabase utilise 'key' comme PK
      title: json['title'] as String,
      key: json['key'] as String,
      logoPath: null, // Pas utilisé dans Supabase
      svgData: null, // Pas utilisé dans Supabase
      groupColor: json['color'] as String?,
      keywords: [], // Pas stocké dans Supabase pour simplifier
      description: null,
      lastModified: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convertit en JSON pour Supabase
  Map<String, dynamic> toSupabaseJson() {
    return {
      'key': key,
      'title': title,
      'color': groupColor ?? '#2196F3',
    };
  }

  @override
  String getId() => id;

  @override
  DateTime? getLastModified() => lastModified;

  @override
  void setLastModified(DateTime dateTime) {
    lastModified = dateTime;
    markAsDirty();
  }

  @override
  bool get isDirty => _isDirty;

  @override
  void markAsSynced() {
    _isDirty = false;
    _changes.clear();
  }

  @override
  void markAsDirty() {
    _isDirty = true;
  }

  @override
  Map<String, dynamic> getChanges() => Map.from(_changes);

  /// Copie le groupe avec de nouvelles valeurs
  BookGroup copyWith({
    String? id,
    String? title,
    String? key,
    String? logoPath,
    String? svgData,
    String? groupColor,
    List<String>? keywords,
    String? description,
  }) {
    return BookGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      key: key ?? this.key,
      logoPath: logoPath ?? this.logoPath,
      svgData: svgData ?? this.svgData,
      groupColor: groupColor ?? this.groupColor,
      keywords: keywords ?? this.keywords,
      description: description ?? this.description,
      lastModified: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookGroup && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Exception spécifique aux groupes de livres
class BookGroupException extends AppException {
  const BookGroupException(String message, {String? code, dynamic originalException})
      : super(message, code: code, originalException: originalException);
}