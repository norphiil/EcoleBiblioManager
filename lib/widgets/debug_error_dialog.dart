import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebugErrorDialog extends StatelessWidget {
  final String errorDetails;
  final VoidCallback? onGoHome;

  const DebugErrorDialog({
    Key? key,
    required this.errorDetails,
    this.onGoHome,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Erreur (DEBUG)'),
      content: SingleChildScrollView(
        child: SelectableText(
          errorDetails,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: errorDetails));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur copiée dans le presse-papier')),
            );
          },
          child: const Text('Copier'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (onGoHome != null) onGoHome!();
          },
          child: const Text('Accueil'),
        ),
      ],
    );
  }
}
