import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../../widgets/debug_error_dialog.dart';

/// Gestionnaire global des erreurs avec support du mode DEBUG
class ErrorHandler {
  /// Affiche une erreur de manière appropriée selon le mode DEBUG
  /// 
  /// Si DEBUG=true dans .env, affiche une popup détaillée avec l'erreur complète
  /// Sinon, affiche une simple SnackBar
  static void showError(
    BuildContext context, {
    required String message,
    String? details,
    StackTrace? stackTrace,
    VoidCallback? onGoHome,
  }) {
    // Construire le message d'erreur détaillé
    final errorDetails = StringBuffer();
    errorDetails.writeln('Message: $message');
    
    if (details != null && details.isNotEmpty) {
      errorDetails.writeln('\nDétails: $details');
    }
    
    if (stackTrace != null) {
      errorDetails.writeln('\nStack Trace:');
      errorDetails.writeln(stackTrace.toString());
    }

    // Si mode DEBUG activé, afficher la popup détaillée
    if (AppConstants.isDebugMode) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DebugErrorDialog(
          errorDetails: errorDetails.toString(),
          onGoHome: onGoHome ?? () => context.go('/'),
        ),
      );
    } else {
      // Mode production : simple SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
          action: onGoHome != null
              ? SnackBarAction(
                  label: 'Accueil',
                  textColor: Colors.white,
                  onPressed: onGoHome,
                )
              : null,
        ),
      );
    }
  }

  /// Affiche une erreur capturée dans un catch
  static void showCaughtError(
    BuildContext context, {
    required String message,
    required Object error,
    StackTrace? stackTrace,
    VoidCallback? onGoHome,
  }) {
    showError(
      context,
      message: message,
      details: error.toString(),
      stackTrace: stackTrace,
      onGoHome: onGoHome,
    );
  }
}
