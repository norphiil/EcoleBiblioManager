import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Helper pour générer des variantes de couleurs dynamiquement
class DynamicColorScheme {
  final Color primaryColor;
  final Color darkerColor;
  final Color lighterColor;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  DynamicColorScheme._({
    required this.primaryColor,
    required this.darkerColor,
    required this.lighterColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
  });

  /// Crée un schéma de couleurs dynamique à partir d'une couleur de groupe
  factory DynamicColorScheme.fromGroupColor(String? colorHex) {
    // Si pas de couleur, utiliser le bleu par défaut
    if (colorHex == null || colorHex.isEmpty) {
      return DynamicColorScheme.fromColor(const Color(0xFF2196F3));
    }

    try {
      // Parser la couleur hexadécimale
      final colorString = colorHex.replaceAll('#', '');
      final color = Color(int.parse('FF$colorString', radix: 16));
      return DynamicColorScheme.fromColor(color);
    } catch (e) {
      // En cas d'erreur, utiliser le bleu par défaut
      return DynamicColorScheme.fromColor(const Color(0xFF2196F3));
    }
  }

  /// Crée un schéma de couleurs dynamique à partir d'une couleur Flutter
  factory DynamicColorScheme.fromColor(Color color) {
    return DynamicColorScheme._(
      primaryColor: color,
      darkerColor: _darken(color, 0.15), // 15% plus foncé
      lighterColor: _lighten(color, 0.85), // 85% plus clair
      textColor: _darken(color, 0.2), // 20% plus foncé pour le texte
      backgroundColor: _lighten(color, 0.95), // 95% plus clair pour le fond
      borderColor: _lighten(color, 0.7), // 70% plus clair pour les bordures
      shadowColor: color.withValues(alpha: 0.25), // 25% d'opacité pour l'ombre
    );
  }

  /// Assombrit une couleur par un facteur (0.0 à 1.0)
  static Color _darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness(math.max(0, hsl.lightness - amount));

    return hslDark.toColor();
  }

  /// Éclaircit une couleur par un facteur (0.0 à 1.0)
  static Color _lighten(Color color, double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness(math.min(1, amount));

    return hslLight.toColor();
  }

  /// Détermine si la couleur est claire ou foncée
  bool get isLight {
    final luminance = primaryColor.computeLuminance();
    return luminance > 0.5;
  }

  /// Couleur de texte sur la couleur primaire (blanc ou noir)
  Color get onPrimaryColor {
    return isLight ? Colors.black87 : Colors.white;
  }

  /// Crée une ColorScheme Material compatible
  ColorScheme toMaterialColorScheme({required Brightness brightness}) {
    return ColorScheme(
      brightness: brightness,
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      primaryContainer: lighterColor,
      onPrimaryContainer: darkerColor,
      secondary: darkerColor,
      onSecondary: Colors.white,
      error: Colors.red.shade700,
      onError: Colors.white,
      surface: brightness == Brightness.light ? Colors.white : Colors.grey.shade900,
      onSurface: brightness == Brightness.light ? Colors.black87 : Colors.white,
    );
  }
}

/// Extension pour faciliter l'utilisation des couleurs dynamiques
extension ColorHelper on Color {
  /// Assombrit la couleur
  Color darken([double amount = 0.15]) {
    return DynamicColorScheme._darken(this, amount);
  }

  /// Éclaircit la couleur
  Color lighten([double amount = 0.15]) {
    return DynamicColorScheme._lighten(this, amount);
  }

  /// Convertit en string hexadécimal
  String toHexString() {
    return '#${value.toRadixString(16).substring(2).toUpperCase()}';
  }
}

/// Widget qui fournit un thème dynamique basé sur la couleur du groupe
class DynamicThemeProvider extends InheritedWidget {
  final DynamicColorScheme colorScheme;

  const DynamicThemeProvider({
    super.key,
    required this.colorScheme,
    required super.child,
  });

  static DynamicColorScheme? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DynamicThemeProvider>()
        ?.colorScheme;
  }

  @override
  bool updateShouldNotify(DynamicThemeProvider oldWidget) {
    return colorScheme.primaryColor != oldWidget.colorScheme.primaryColor;
  }
}

/// Extension pour accéder facilement aux couleurs dynamiques depuis le contexte
extension DynamicColorContext on BuildContext {
  DynamicColorScheme get dynamicColors {
    return DynamicThemeProvider.of(this) ??
        DynamicColorScheme.fromColor(const Color(0xFF2196F3));
  }
}
