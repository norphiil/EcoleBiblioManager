import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/log_service.dart';
import 'package:path/path.dart' as path;

/// Écran de visualisation et gestion des logs de l'application
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final LogService _logService = LogService();
  String _logContent = 'Chargement des logs...';
  List<File> _logFiles = [];
  String? _selectedLogFilePath; // Utiliser le chemin au lieu de l'instance File
  bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Charge les logs depuis le fichier
  Future<void> _loadLogs() async {
    try {
      // Charger la liste des fichiers de log
      final logFiles = await _logService.getAllLogFiles();
      
      // Obtenir le fichier de log actuel
      final currentLogPath = _logService.getLogFilePath();
      File? selectedFile;
      
      if (currentLogPath != null) {
        // Chercher le fichier actuel dans la liste (comparaison par chemin)
        selectedFile = logFiles.firstWhere(
          (file) => file.path == currentLogPath,
          orElse: () => logFiles.isNotEmpty ? logFiles.first : File(currentLogPath),
        );
      } else if (logFiles.isNotEmpty) {
        selectedFile = logFiles.first;
      }
      
      setState(() {
        _logFiles = logFiles;
        _selectedLogFilePath = selectedFile?.path;
      });

      // Charger le contenu du log sélectionné
      await _loadSelectedLog();
    } catch (e) {
      setState(() {
        _logContent = 'Erreur lors du chargement des logs: $e';
      });
    }
  }

  /// Charge le contenu du fichier de log sélectionné
  Future<void> _loadSelectedLog() async {
    if (_selectedLogFilePath == null) {
      setState(() {
        _logContent = 'Aucun fichier de log disponible.\n\nLes logs seront créés au prochain démarrage de l\'application.';
      });
      return;
    }

    final selectedFile = File(_selectedLogFilePath!);
    if (!await selectedFile.exists()) {
      setState(() {
        _logContent = 'Le fichier de log n\'existe plus.';
      });
      return;
    }

    try {
      final content = await selectedFile.readAsString();
      setState(() {
        _logContent = content.isNotEmpty 
            ? content 
            : 'Le fichier de log est vide.';
      });

      // Auto-scroll vers le bas si activé
      if (_autoScroll && _scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      setState(() {
        _logContent = 'Erreur lecture du fichier: $e';
      });
    }
  }

  /// Copie les logs dans le presse-papier
  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _logContent));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs copiés dans le presse-papier'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Ouvre le dossier contenant les logs
  Future<void> _openLogsFolder() async {
    if (_selectedLogFilePath != null) {
      final folderPath = path.dirname(_selectedLogFilePath!);
      try {
        if (Platform.isWindows) {
          await Process.run('explorer', [folderPath]);
        } else if (Platform.isMacOS) {
          await Process.run('open', [folderPath]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [folderPath]);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossible d\'ouvrir le dossier: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  /// Supprime les anciens logs
  Future<void> _cleanOldLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
          'Supprimer tous les anciens fichiers de logs ?\n\n'
          'Les 10 fichiers les plus récents seront conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _logService.cleanOldLogs();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anciens logs supprimés'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// Sélectionne un fichier de log différent
  void _selectLogFile(String filePath) {
    setState(() {
      _selectedLogFilePath = filePath;
    });
    _loadSelectedLog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de l\'application'),
        actions: [
          // Auto-scroll toggle
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.unfold_more),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Désactiver auto-scroll' : 'Activer auto-scroll',
          ),
          // Rafraîchir
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Rafraîchir',
          ),
          // Copier
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'Copier les logs',
          ),
          // Ouvrir dossier
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openLogsFolder,
            tooltip: 'Ouvrir le dossier des logs',
          ),
          // Options
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clean') {
                _cleanOldLogs();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clean',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Nettoyer anciens logs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de fichiers de log
          if (_logFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  const Icon(Icons.description, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedLogFilePath,
                      items: _logFiles.map((file) {
                        final fileName = path.basename(file.path);
                        final fileSize = file.lengthSync();
                        final fileSizeKB = (fileSize / 1024).toStringAsFixed(1);
                        return DropdownMenuItem(
                          value: file.path,
                          child: Text(
                            '$fileName ($fileSizeKB KB)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (filePath) {
                        if (filePath != null) {
                          _selectLogFile(filePath);
                        }
                      },
                    ),
                  ),
                  Text(
                    '${_logFiles.length} fichier(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          
          // Contenu des logs
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _logContent,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 12,
                  color: Colors.greenAccent,
                  height: 1.4,
                ),
                scrollPhysics: const AlwaysScrollableScrollPhysics(),
              ),
            ),
          ),
          
          // Barre d'informations
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[300],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedLogFilePath != null 
                        ? 'Fichier: ${path.basename(_selectedLogFilePath!)}'
                        : 'Aucun fichier sélectionné',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                if (_autoScroll)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Auto-scroll activé',
                      style: TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
