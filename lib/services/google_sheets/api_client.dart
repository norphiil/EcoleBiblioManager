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
      
      // Google Apps Script peut faire des redirections, on utilise un client personnalisé
      final client = http.Client();
      
      try {
        _logger.info('Envoi de la requête POST...');
        var response = await client.post(
          Uri.parse(scriptUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: json.encode(payload),
        ).timeout(
          const Duration(seconds: 60), // Augmenté à 60 secondes
          onTimeout: () {
            _logger.error('Timeout après 60s sur POST');
            throw Exception('Timeout: Google Apps Script met trop de temps à répondre (>60s)');
          },
        );

        final elapsed = DateTime.now().difference(startTime).inSeconds;
        _logger.info('Status: ${response.statusCode} (${elapsed}s)');

        // Si redirection, on réessaie avec GET sur l'URL originale
        if (response.statusCode == 302 || response.statusCode == 307) {
          _logger.info('Redirection détectée, tentative avec GET sur URL originale...');
          
          // Construire l'URL avec les paramètres en GET
          final queryParams = {
            'action': payload['action']?.toString() ?? '',
          };
          
          // Ajouter le paramètre sheet si présent
          if (payload.containsKey('sheet') && payload['sheet'] != null) {
            queryParams['sheet'] = payload['sheet'].toString();
          }
          
          // Ajouter les params si présent
          if (payload.containsKey('params') && payload['params'] != null) {
            queryParams['params'] = json.encode(payload['params']);
          }
          
          final uri = Uri.parse(scriptUrl).replace(queryParameters: queryParams);
          _logger.info('GET URL: $uri');
          
          response = await client.get(uri).timeout(
            const Duration(seconds: 60), // Augmenté à 60 secondes
            onTimeout: () {
              _logger.error('Timeout après 60s sur GET');
              throw Exception('Timeout: Google Apps Script met trop de temps à répondre (>60s)');
            },
          );
          
          final elapsedGet = DateTime.now().difference(startTime).inSeconds;
          _logger.info('Status après GET: ${response.statusCode} (${elapsedGet}s)');
        }

        if (response.statusCode == 405) {
          _logger.error('HTTP 405 - Méthode non autorisée');
          _logger.error('Vérifiez: "Exécuter en tant que" = "Moi" (pas "Utilisateur")');
          throw 'Déploiement Google Apps Script mal configuré (405)';
        }

        if (response.statusCode != 200) {
          _logger.error('Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
          throw 'HTTP ${response.statusCode}';
        }

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
