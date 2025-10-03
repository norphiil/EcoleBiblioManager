import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Carte d'action réutilisable pour le menu principal
class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const ActionCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: enabled ? 4 : 1,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
            gradient: enabled 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.8),
                      color,
                    ],
                  )
                : null,
            color: enabled ? null : Colors.grey[300],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                decoration: BoxDecoration(
                  color: enabled 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppConstants.iconSizeLarge,
                  color: enabled ? Colors.white : Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: AppConstants.paddingMedium),
              
              // Titre
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: enabled ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: AppConstants.paddingSmall),
              
              // Sous-titre
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: enabled 
                      ? Colors.white.withOpacity(0.9)
                      : Colors.grey[500],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Variante compacte de la carte d'action pour les listes
class CompactActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final Widget? trailing;

  const CompactActionCard({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.color,
    required this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall / 2,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color?.withOpacity(0.1) ?? 
                           Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            icon,
            color: color ?? Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Widget d'action flottante personnalisée
class FloatingActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final bool extended;

  const FloatingActionCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.extended = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (extended) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      tooltip: label,
      child: Icon(icon),
    );
  }
}