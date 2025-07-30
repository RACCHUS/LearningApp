import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final double iconSize;
  final double spacing;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconSize = 64,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: iconSize,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              SizedBox(height: spacing),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (message.isNotEmpty) ...{
                SizedBox(height: spacing / 2),
                Text(
                  message,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              },
              if (action != null) ...{
                SizedBox(height: spacing * 1.5),
                action!,
              },
            ],
          ),
        ),
      ),
    );
  }
}
