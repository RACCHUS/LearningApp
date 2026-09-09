import 'package:flutter/material.dart';

/// Component for displaying and managing lesson content items
/// 
/// Extracted from LessonBuilderWidget to improve maintainability.
/// Shows a reorderable list of content items with delete functionality.
class ContentPreviewList extends StatelessWidget {
  final List<Map<String, dynamic>> contentItems;
  final Function(int, int) onReorder;
  final Function(int) onRemoveItem;
  final VoidCallback onCreateLesson;
  final bool canCreateLesson;

  const ContentPreviewList({
    super.key,
    required this.contentItems,
    required this.onReorder,
    required this.onRemoveItem,
    required this.onCreateLesson,
    this.canCreateLesson = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Content items list
        if (contentItems.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.list,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Content Items',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${contentItems.length}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Drag to reorder • Tap delete to remove',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    height: 250,
                    child: ReorderableListView.builder(
                      itemCount: contentItems.length,
                      onReorder: onReorder,
                      itemBuilder: (context, index) {
                        final item = contentItems[index];
                        return _buildContentItemTile(context, item, index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
        
        // Create lesson button
        FilledButton.icon(
          onPressed: canCreateLesson ? onCreateLesson : null,
          icon: const Icon(Icons.create),
          label: Text(contentItems.isEmpty 
              ? 'Add content to create lesson' 
              : 'Create Lesson'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: canCreateLesson 
                ? null 
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        
        if (contentItems.isEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No content items yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the tabs above to add terms, questions, or concepts to your lesson',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContentItemTile(BuildContext context, Map<String, dynamic> item, int index) {
    final type = item['type'] as String;
    String title = '';
    String subtitle = '';
    
    switch (type) {
      case 'term':
        title = item['term'] as String;
        subtitle = item['definition'] as String;
        break;
      case 'mcq':
        title = item['question'] as String;
        final options = item['options'] as List;
        subtitle = '${options.length} options • Correct: ${String.fromCharCode(65 + (item['correctIndex'] as int))}';
        break;
      case 'concept':
        title = item['title'] as String;
        subtitle = item['description'] as String;
        break;
    }

    return Card(
      key: ValueKey(item['id']),
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getColorForType(context, type),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconForType(type),
            color: _getIconColorForType(context, type),
            size: 20,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getColorForType(context, type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getTypeLabel(type),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getIconColorForType(context, type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.drag_handle, color: Colors.grey),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red[400],
              onPressed: () => _showDeleteConfirmation(context, index, title),
              tooltip: 'Delete item',
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int index, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content Item'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRemoveItem(index);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'term':
        return Icons.book;
      case 'mcq':
        return Icons.quiz;
      case 'concept':
        return Icons.lightbulb;
      default:
        return Icons.help;
    }
  }

  Color _getColorForType(BuildContext context, String type) {
    switch (type) {
      case 'term':
        return Theme.of(context).colorScheme.primaryContainer;
      case 'mcq':
        return Theme.of(context).colorScheme.secondaryContainer;
      case 'concept':
        return Theme.of(context).colorScheme.tertiaryContainer;
      default:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
  }

  Color _getIconColorForType(BuildContext context, String type) {
    switch (type) {
      case 'term':
        return Theme.of(context).colorScheme.onPrimaryContainer;
      case 'mcq':
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case 'concept':
        return Theme.of(context).colorScheme.onTertiaryContainer;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'term':
        return 'TERM';
      case 'mcq':
        return 'MCQ';
      case 'concept':
        return 'CONCEPT';
      default:
        return 'UNKNOWN';
    }
  }
}
