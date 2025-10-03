import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

/// Widget pour afficher un logo SVG avec une couleur personnalisée
class SvgLogoWidget extends StatelessWidget {
  final String? svgData; // Base64 encoded SVG
  final String? colorHex; // Format: #RRGGBB
  final double? width;
  final double? height;
  final Widget? fallback;

  const SvgLogoWidget({
    super.key,
    required this.svgData,
    this.colorHex,
    this.width,
    this.height,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    // Si pas de données SVG, afficher le fallback
    if (svgData == null || svgData!.isEmpty) {
      return fallback ??
          Icon(
            Icons.image_not_supported,
            size: width ?? height ?? 50,
            color: Colors.grey,
          );
    }

    try {
      // Décoder le SVG depuis base64
      final svgString = utf8.decode(base64Decode(svgData!));

      // Parser la couleur
      Color? color;
      if (colorHex != null && colorHex!.isNotEmpty) {
        final colorString = colorHex!.replaceAll('#', '');
        color = Color(int.parse('FF$colorString', radix: 16));
      }

      // Afficher le SVG avec la couleur
      return SvgPicture.string(
        svgString,
        width: width,
        height: height,
        colorFilter: color != null
            ? ColorFilter.mode(color, BlendMode.srcIn)
            : null,
        placeholderBuilder: (BuildContext context) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    } catch (e) {
      print('Erreur lors du décodage du SVG: $e');
      return fallback ??
          Icon(
            Icons.error_outline,
            size: width ?? height ?? 50,
            color: Colors.red,
          );
    }
  }
}
