import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/logger.dart';

/// Client HTTP simple pour appeler Google Apps Script
class GoogleSheetsApiClient {
  final String scriptUrl;
  final Logger _logger = Logger('ApiClient');

  GoogleSheetsApiClient(this.scriptUrl);

  /// Appelle l'API avec un payload JSON
  Future<Map<String, dynamic>> call(Map<String, dynamic> payload) async {
    final startTime = DateTime.now();
    
    try {
      _logger.info('API call: ${payload['action']}');
      _logger.info('Envoi de la requête POST...');
      
      // Google Apps Script retourne toujours un 302 redirect pour les POST
      // On doit suivre manuellement la redirection car le package http ne préserve pas
      // le body POST lors des redirections automatiques
      
      // 1. Première requête POST (va retourner 302)
      final client = http.Client();
      
      try {
        var response = await client.post(
          Uri.parse(scriptUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        ).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw Exception('Timeout: Google Apps Script met trop de temps à répondre (>60s)');
          },
        );

        final elapsed = DateTime.now().difference(startTime).inSeconds;
        _logger.info('Status initial: ${response.statusCode} (${elapsed}s)');

        // 2. Si on reçoit une redirection (comportement normal de Google Apps Script)
        if (response.statusCode == 302 || response.statusCode == 307) {
          _logger.info('Redirection 302 détectée (normal pour Google Apps Script)');
          
          // Récupérer l'URL de redirection depuis le header Location
          final redirectUrl = response.headers['location'];
          
          if (redirectUrl == null || redirectUrl.isEmpty) {
            throw Exception('Redirection 302 sans URL de destination');
          }
          
          _logger.info('Suivi de la redirection vers: ${redirectUrl.substring(0, redirectUrl.length > 100 ? 100 : redirectUrl.length)}...');
          
          // 3. Suivre la redirection avec GET (l'URL redirigée n'accepte que GET)
          // Le script a déjà reçu les données du POST initial
          response = await client.get(
            Uri.parse(redirectUrl),
            headers: {
              'Accept': 'application/json',
            },
          ).timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw Exception('Timeout sur l\'URL redirigée (>60s)');
            },
          );
          
          final elapsedRedirect = DateTime.now().difference(startTime).inSeconds;
          _logger.info('Status après redirection: ${response.statusCode} (${elapsedRedirect}s)');
        }

        // Gestion des erreurs HTTP
        if (response.statusCode == 405) {
          _logger.error('HTTP 405 - Méthode non autorisée');
          _logger.error('Vérifiez: "Exécuter en tant que" = "Moi" et "Accès" = "Tous"');
          throw 'Déploiement Google Apps Script mal configuré (405)';
        }

        if (response.statusCode != 200) {
          final bodyPreview = response.body.length > 500 
              ? response.body.substring(0, 500) 
              : response.body;
          _logger.error('Body: $bodyPreview');
          throw 'HTTP ${response.statusCode}';
        }

        // Parser la réponse JSON
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data.containsKey('error')) {
          throw data['error'];
        }

        _logger.info('✓ Succès');
        return data;
        
      } finally {
        client.close();
      }
      
    } catch (e) {
      _logger.error('Erreur API', e);
      rethrow;
    }
  }

  /// Test de connexion GET
  Future<void> testConnection() async {
    try {
      _logger.info('Test connexion: $scriptUrl');
      _logger.info('⏳ Attente de la réponse (max 30s)...');
      
      final response = await http.get(Uri.parse(scriptUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.error('Timeout après 30s sur test de connexion');
          throw Exception('Timeout: Impossible de joindre Google Apps Script (>30s)');
        },
      );

      if (response.statusCode == 200) {
        _logger.info('✓ Connexion OK');
        return;
      }
      
      throw 'Erreur HTTP: ${response.statusCode}';
    } catch (e) {
      _logger.error('✗ Connexion échouée', e);
      rethrow;
    }
  }
}
