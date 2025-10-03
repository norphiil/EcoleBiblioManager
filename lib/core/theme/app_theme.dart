import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Thème principal de l'application pour les écoles
class AppTheme {
  // Couleurs principales adaptées aux enfants
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppConstants.primaryBlue,
    onPrimary: Colors.white,
    secondary: AppConstants.primaryGreen,
    onSecondary: Colors.white,
    tertiary: AppConstants.primaryOrange,
    onTertiary: Colors.white,
    error: AppConstants.errorColor,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1C1B1F),
    outline: Color(0xFF79747E),
    surfaceContainerHighest: Color(0xFFE6E0E9),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF003258),
    secondary: Color(0xFF81C784),
    onSecondary: Color(0xFF003912),
    tertiary: Color(0xFFFFB74D),
    onTertiary: Color(0xFF4A2800),
    error: Color(0xFFEF5350),
    onError: Color(0xFF601410),
    surface: AppConstants.darkBackground,
    onSurface: Color(0xFFE6E1E5),
    outline: Color(0xFF938F99),
    surfaceContainerHighest: Color(0xFF49454F),
  );

  /// Thème clair optimisé pour les écoles
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      fontFamily: 'Roboto',
      
      // Configuration de l'AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.black26,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      // Configuration des boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          elevation: 3,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          side: BorderSide(color: _lightColorScheme.primary, width: 2),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Configuration des cartes
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      
      // Configuration des champs de texte
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: _lightColorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: _lightColorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppConstants.paddingMedium),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      
      // Configuration des ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppConstants.radiusSmall)),
        ),
      ),
      
      // Configuration des Chip
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey[100],
        selectedColor: _lightColorScheme.primaryContainer,
        labelStyle: const TextStyle(fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      
      // Configuration des Drawer
      drawerTheme: const DrawerThemeData(
        elevation: 8,
        shadowColor: Colors.black26,
      ),
      
      // Configuration des SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey[800],
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Configuration des Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 6,
        shape: CircleBorder(),
      ),
    );
  }

  /// Thème sombre (optionnel)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      fontFamily: 'Roboto',
      
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          elevation: 3,
        ),
      ),
      
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          borderSide: BorderSide(color: _darkColorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(AppConstants.paddingMedium),
      ),
    );
  }
}

/// Extensions pour faciliter l'utilisation des couleurs de statut
extension StatusColors on ColorScheme {
  Color get success => AppConstants.successColor;
  Color get warning => AppConstants.warningColor;
  Color get info => AppConstants.infoColor;
}

/// Extensions pour les espacements
extension AppSpacing on EdgeInsets {
  static const EdgeInsets small = EdgeInsets.all(AppConstants.paddingSmall);
  static const EdgeInsets medium = EdgeInsets.all(AppConstants.paddingMedium);
  static const EdgeInsets large = EdgeInsets.all(AppConstants.paddingLarge);
  static const EdgeInsets xLarge = EdgeInsets.all(AppConstants.paddingXLarge);
  
  static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(horizontal: AppConstants.paddingSmall);
  static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(horizontal: AppConstants.paddingMedium);
  static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(horizontal: AppConstants.paddingLarge);
  
  static const EdgeInsets verticalSmall = EdgeInsets.symmetric(vertical: AppConstants.paddingSmall);
  static const EdgeInsets verticalMedium = EdgeInsets.symmetric(vertical: AppConstants.paddingMedium);
  static const EdgeInsets verticalLarge = EdgeInsets.symmetric(vertical: AppConstants.paddingLarge);
}