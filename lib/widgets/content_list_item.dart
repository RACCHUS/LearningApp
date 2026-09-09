import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';

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
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_getIconForContentType()),
        ),
        title: _buildTitle(),
        subtitle: _buildSubtitle(),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return switch (content) {
      TermContent termContent => Text(
          termContent.term,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      QuestionContent questionContent => Text(
          questionContent.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ConceptContent conceptContent => Text(
          conceptContent.conceptText.split('\n').first,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      _ => const Text('Unknown content type'),
    };
  }

  Widget _buildSubtitle() {
    return switch (content) {
      TermContent termContent => Text(
          termContent.definition,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      QuestionContent questionContent => Text(
          '${questionContent.options.length} options',
          style: const TextStyle(fontSize: 12),
        ),
      ConceptContent conceptContent => Text(
          conceptContent.keyPoints?.join(', ') ?? 'No key points',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      _ => const Text('Unknown content type'),
    };
  }

  IconData _getIconForContentType() {
    return switch (content) {
      TermContent() => Icons.library_books,
      QuestionContent() => Icons.quiz,
      ConceptContent() => Icons.lightbulb,
      _ => Icons.help,
    };
  }
}
