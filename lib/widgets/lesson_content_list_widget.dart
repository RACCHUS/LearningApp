import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';

class LessonContentListWidget extends StatelessWidget {
  final List<LessonContent> contents;
  final Function(int) onRemoveContent;

  const LessonContentListWidget({
    super.key,
    required this.contents,
    required this.onRemoveContent,
  });

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No content added yet. Use the form above to add content.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson Content (${contents.length} items)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contents.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final content = contents[index];
                return _buildContentItem(context, content, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentItem(BuildContext context, LessonContent content, int index) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(_getIconForContent(content)),
      ),
      title: _buildContentTitle(content),
      subtitle: _buildContentSubtitle(content),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => onRemoveContent(index),
      ),
    );
  }

  Widget _buildContentTitle(LessonContent content) {
    return switch (content) {
      TermContent termContent => Text(
          termContent.term,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      QuestionContent questionContent => Text(
          questionContent.questionText,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ConceptContent conceptContent => Text(
          conceptContent.conceptText.split('\n').first,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      TextContent textContent => Text(
          textContent.text.split('\n').first,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      _ => const Text('Unknown content type'),
    };
  }

  Widget _buildContentSubtitle(LessonContent content) {
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
          conceptContent.exampleText ?? 'No example provided',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      TextContent() => Text(
          'Text content',
          style: const TextStyle(fontSize: 12),
        ),
      _ => const Text('Unknown content type'),
    };
  }

  IconData _getIconForContent(LessonContent content) {
    return switch (content) {
      TermContent() => Icons.library_books,
      QuestionContent() => Icons.quiz,
      ConceptContent() => Icons.lightbulb,
      TextContent() => Icons.text_fields,
      _ => Icons.help,
    };
  }
}
