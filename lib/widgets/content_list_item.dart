import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';

class ContentListItem extends StatelessWidget {
  final LessonContent content;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContentListItem({
    super.key,
    required this.content,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Delete',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildTitle() {
    return switch (content) {
      TermContent() => Text(
          content.term,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      QuestionContent() => Text(
          content.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ConceptContent() => Text(
          content.conceptText.split('\n').first,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      _ => const Text('Unknown content type'),
    };
  }

  Widget _buildSubtitle() {
    return switch (content) {
      TermContent() => Text(
          content.definition,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      QuestionContent() => Text(
          '${content.options.length} options',
          style: const TextStyle(fontSize: 12),
        ),
      ConceptContent() => Text(
          content.keyPoints?.join(', ') ?? 'No key points',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
