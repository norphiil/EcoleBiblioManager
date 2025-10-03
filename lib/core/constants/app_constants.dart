import 'package:flutter/material.dart';

/// Constantes de l'application
class AppConstants {
  // Couleurs principales
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color primaryPurple = Color(0xFF9C27B0);
  
  // Couleurs de fond
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF121212);
  
  // Couleurs de statut
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  
  // Espacements
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Rayons des bordures
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  // Tailles d'icônes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  
  // Configuration du scanner
  static const Duration scannerTimeout = Duration(seconds: 30);
  static const int maxScanAttempts = 3;
  
  // Configuration de l'API
  static const Duration apiTimeout = Duration(seconds: 10);
  static const int maxRetryAttempts = 3;
  
  // Configuration des emprunts
  static const Duration defaultLoanDuration = Duration(days: 14);
  static const int maxBooksPerStudent = 3;
  static const int maxBooksPerTeacher = 10;
  
  // Messages
  static const String appName = 'Bibliothèque École';
  static const String noInternetMessage = 'Aucune connexion Internet';
  static const String genericErrorMessage = 'Une erreur s\'est produite';
}

/// Routes de navigation
class AppRoutes {
  static const String home = '/';
  static const String scanToShelve = '/scan-to-shelve';
  static const String scanToBorrow = '/scan-to-borrow';
  static const String bookInfo = '/book-info';
  static const String bookDetails = '/book-details';
  static const String shelveBook = '/shelve-book';
  static const String groupManagement = '/group-management';
  static const String classManagement = '/class-management';
  static const String userManagement = '/user-management';
  static const String settings = '/settings';
}

/// Clés pour les widgets (utile pour les tests)
class AppKeys {
  static const Key homeScreenKey = Key('home_screen');
  static const Key scannerScreenKey = Key('scanner_screen');
  static const Key bookInfoScreenKey = Key('book_info_screen');
  
  // Boutons principaux
  static const Key shelveBookButtonKey = Key('shelve_book_button');
  static const Key borrowBookButtonKey = Key('borrow_book_button');
  static const Key bookInfoButtonKey = Key('book_info_button');
  
  // Scanner
  static const Key barcodeScannerKey = Key('barcode_scanner');
  static const Key manualEntryFieldKey = Key('manual_entry_field');
  static const Key flashToggleKey = Key('flash_toggle');
  
  // Formulaires
  static const Key bookTitleFieldKey = Key('book_title_field');
  static const Key bookAuthorFieldKey = Key('book_author_field');
  static const Key shelfLocationFieldKey = Key('shelf_location_field');
  static const Key borrowerNameFieldKey = Key('borrower_name_field');
}

/// Types d'assets
class AppAssets {
  static const String iconsPath = 'assets/icons/';
  static const String imagesPath = 'assets/images/';
  
  // Icônes
  static const String bookIcon = '${iconsPath}book.svg';
  static const String scanIcon = '${iconsPath}scan.svg';
  static const String shelfIcon = '${iconsPath}shelf.svg';
  static const String userIcon = '${iconsPath}user.svg';
  static const String settingsIcon = '${iconsPath}settings.svg';
}

/// Configuration des animations
class AppAnimations {
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.bounceOut;
  static const Curve elasticCurve = Curves.elasticOut;
}