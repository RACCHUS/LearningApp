import 'package:flutter/material.dart';

/// Content type enumeration for the list tile
enum ContentItemType {
  term,
  question,
  concept,
}

/// A reusable list tile for displaying content items (terms, questions, concepts)
/// with drag handle, edit, and delete functionality
class ContentListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ContentItemType type;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int index;

  const ContentListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.type,
    required this.onEdit,
    required this.onDelete,
    required this.index,
  });

  IconData get _typeIcon {
    switch (type) {
      case ContentItemType.term:
        return Icons.style_outlined;
      case ContentItemType.question:
        return Icons.quiz_outlined;
      case ContentItemType.concept:
        return Icons.lightbulb_outline;
    }
  }

  Color _typeColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case ContentItemType.term:
        return colorScheme.primary;
      case ContentItemType.question:
        return colorScheme.secondary;
      case ContentItemType.concept:
        return colorScheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _typeColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _typeIcon,
                color: _typeColor(context),
                size: 20,
              ),
            ),
          ],
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              color: theme.colorScheme.error,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// An empty state widget for when there are no content items
class EmptyContentState extends StatelessWidget {
  final ContentItemType type;
  final VoidCallback onAdd;

  const EmptyContentState({
    super.key,
    required this.type,
    required this.onAdd,
  });

  String get _typeLabel {
    switch (type) {
      case ContentItemType.term:
        return 'flashcards';
      case ContentItemType.question:
        return 'questions';
      case ContentItemType.concept:
        return 'concepts';
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case ContentItemType.term:
        return Icons.style_outlined;
      case ContentItemType.question:
        return Icons.quiz_outlined;
      case ContentItemType.concept:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _typeIcon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No $_typeLabel yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first item',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('Add ${type.name}'),
            ),
          ],
        ),
      ),
    );
  }
}
