import 'dart:io';
import 'dart:typed_data';
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/utils/logger.dart';

/// Service pour générer et gérer les codes-barres
class BarcodeService {
  final Logger _logger = Logger('BarcodeService');
  
  /// Génère un code-barres ISBN à partir d'un ISBN
  Future<String?> generateBarcodeSvg(String isbn) async {
    try {
      // Nettoie l'ISBN
      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
      
      // Valide que c'est un ISBN valide (10 ou 13 caractères, numérique)
      if ((cleanIsbn.length != 10 && cleanIsbn.length != 13) || !RegExp(r'^\d+$').hasMatch(cleanIsbn)) {
        _logger.error('ISBN invalide pour le code-barres: $isbn');
        return null;
      }
      
      // Pour les ISBN-10, convertit en ISBN-13
      String barcodeIsbn = cleanIsbn;
      if (cleanIsbn.length == 10) {
        barcodeIsbn = _convertIsbn10ToIsbn13(cleanIsbn);
      }
      
      _logger.info('Génération du code-barres ISBN pour: $barcodeIsbn');
      
      // Génère le code-barres ISBN en SVG (sans afficher le texte ISBN)
      final bc = Barcode.isbn(drawIsbn: false);
      final svgString = bc.toSvg(
        barcodeIsbn,
        width: 400,
        height: 150,
        fontHeight: 14,
      );
      
      _logger.info('Code-barres ISBN SVG généré avec succès pour: $barcodeIsbn');
      return svgString;
    } catch (e) {
      _logger.error('Erreur lors de la génération du code-barres SVG', e);
      return null;
    }
  }
  
  /// Génère une image PNG du code-barres en utilisant le SVG
  Future<Uint8List?> generateBarcodeImage(String isbn) async {
    try {
      final svgString = await generateBarcodeSvg(isbn);
      
      if (svgString == null) {
        return null;
      }
      
      _logger.info('SVG généré avec succès');
      
      // Convertit le SVG en bytes pour pouvoir le sauvegarder
      return Uint8List.fromList(svgString.codeUnits);
    } catch (e) {
      _logger.error('Erreur lors de la génération de l\'image', e);
      return null;
    }
  }
  
  /// Convertit un ISBN-10 en ISBN-13
  String _convertIsbn10ToIsbn13(String isbn10) {
    // Ajoute le préfixe 978
    String isbn13 = '978${isbn10.substring(0, 9)}';
    
    // Calcule la clé de contrôle
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(isbn13[i]);
      sum += digit * (i.isEven ? 1 : 3);
    }
    
    final checkDigit = (10 - (sum % 10)) % 10;
    isbn13 += checkDigit.toString();
    
    return isbn13;
  }
  
  /// Génère le code-barres et propose le téléchargement
  Future<bool> generateAndDownloadBarcode(String isbn, BuildContext context) async {
    try {
      _logger.info('Génération du code-barres ISBN pour: $isbn');
      
      // Génère le SVG du code-barres
      final svgString = await generateBarcodeSvg(isbn);
      
      if (svgString == null) {
        _showErrorDialog(context, 'Erreur', 'Impossible de générer le code-barres ISBN.');
        return false;
      }
      
      // Demande à l'utilisateur où télécharger le fichier
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Télécharger le code-barres ISBN',
        fileName: 'codebar_isbn_${isbn.replaceAll(RegExp(r'[^0-9]'), '')}.svg',
        type: FileType.custom,
        allowedExtensions: ['svg'],
      );
      
      if (result == null) {
        _logger.info('Téléchargement annulé par l\'utilisateur');
        return false;
      }
      
      // Écrit le fichier SVG
      final file = File(result);
      await file.writeAsString(svgString);
      
      _logger.info('Code-barres ISBN téléchargé avec succès: $result');
      _showSuccessDialog(
        context, 
        'Succès', 
        'Code-barres ISBN généré et téléchargé!\n\n'
      );
      
      return true;
    } catch (e) {
      _logger.error('Erreur lors du téléchargement du code-barres', e);
      _showErrorDialog(context, 'Erreur', 'Erreur lors du téléchargement: $e');
      return false;
    }
  }
  
  /// Affiche une boîte de dialogue d'erreur
  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Affiche une boîte de dialogue de succès
  void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
