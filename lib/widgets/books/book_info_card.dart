import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../core/utils/dynamic_color_scheme.dart';

/// Widget réutilisable pour afficher les informations d'un livre
class BookInfoCard extends StatelessWidget {
  final Book book;
  final bool showGroupInfo;
  final BookGroup? group;

  const BookInfoCard({
    Key? key,
    required this.book,
    this.showGroupInfo = false,
    this.group,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec titre
            Text(
              'Informations du livre',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Divider(height: 24, thickness: 1),
            
            // Section avec image et infos principales
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image de couverture
                if (book.coverImageUrl != null && book.coverImageUrl!.isNotEmpty)
                  Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        book.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderCover(),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 120,
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildPlaceholderCover(),
                  ),
                
                // Informations textuelles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Auteur
                      _buildInfoRow(
                        context,
                        Icons.person,
                        'Auteur',
                        book.author,
                      ),
                      
                      // ISBN
                      _buildInfoRow(
                        context,
                        Icons.qr_code,
                        'ISBN',
                        book.isbn,
                      ),
                      
                      // Éditeur (si disponible)
                      if (book.publisher != null && book.publisher!.isNotEmpty)
                        _buildInfoRow(
                          context,
                          Icons.business,
                          'Éditeur',
                          book.publisher!,
                        ),
                      
                      // Année de publication (si disponible)
                      if (book.publishYear != null)
                        _buildInfoRow(
                          context,
                          Icons.calendar_today,
                          'Année',
                          book.publishYear.toString(),
                        ),
                      
                      // Nombre de pages (si disponible)
                      if (book.pageCount != null && book.pageCount! > 0)
                        _buildInfoRow(
                          context,
                          Icons.description,
                          'Pages',
                          '${book.pageCount} pages',
                        ),

                      if (book.description != null && book.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(
                            maxHeight: 120, // Environ 6 lignes (20px par ligne)
                          ),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              book.description!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            
            // Sujets/Genres (si disponibles)
            if (book.subjects.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Genres',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: book.subjects.take(5).map((subject) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      subject,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            
            // Informations du groupe (si demandé)
            if (showGroupInfo && group != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  // Générer les couleurs dynamiques à partir de la couleur du groupe
                  final groupColors = group!.groupColor != null
                      ? DynamicColorScheme.fromGroupColor(group!.groupColor!)
                      : DynamicColorScheme.fromColor(Colors.blue);
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: groupColors.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: groupColors.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder,
                          color: groupColors.textColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rangé dans: ',
                          style: TextStyle(
                            color: groupColors.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            group!.title,
                            style: TextStyle(
                              color: groupColors.darkerColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            
            // Statut (si pas disponible)
            if (book.status != BookStatus.available) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(book.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(book.status).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(book.status),
                      color: _getStatusColor(book.status),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStatusText(book.status, book.borrowedBy),
                        style: TextStyle(
                          color: _getStatusColor(book.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          Icons.book,
          size: 40,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookStatus status) {
    switch (status) {
      case BookStatus.borrowed:
        return Colors.orange;
      case BookStatus.reserved:
        return Colors.blue;
      case BookStatus.maintenance:
        return Colors.purple;
      case BookStatus.lost:
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(BookStatus status) {
    switch (status) {
      case BookStatus.borrowed:
        return Icons.person;
      case BookStatus.reserved:
        return Icons.bookmark;
      case BookStatus.maintenance:
        return Icons.build;
      case BookStatus.lost:
        return Icons.warning;
      default:
        return Icons.check_circle;
    }
  }

  String _getStatusText(BookStatus status, String? borrowedBy) {
    switch (status) {
      case BookStatus.borrowed:
        return borrowedBy != null 
            ? 'Emprunté par $borrowedBy' 
            : 'Emprunté';
      case BookStatus.reserved:
        return 'Réservé';
      case BookStatus.maintenance:
        return 'En maintenance';
      case BookStatus.lost:
        return 'Perdu';
      default:
        return 'Disponible';
    }
  }
}
