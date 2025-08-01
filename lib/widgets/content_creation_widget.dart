import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:uuid/uuid.dart';

class ContentCreationWidget extends StatefulWidget {
  final Function(LessonContent) onContentAdded;

  const ContentCreationWidget({
    super.key,
    required this.onContentAdded,
  });

  @override
  State<ContentCreationWidget> createState() => _ContentCreationWidgetState();
}

class _ContentCreationWidgetState extends State<ContentCreationWidget> {
  final _contentController = TextEditingController();
  String _selectedContentType = 'term';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _addContent() {
    if (_contentController.text.trim().isEmpty) return;

    final uuid = const Uuid();
    final now = DateTime.now();
    final contentText = _contentController.text.trim();

    LessonContent content;

    switch (_selectedContentType) {
      case 'term':
        // Simple term creation - split by line for term/definition
        final lines = contentText.split('\n');
        final term = lines.isNotEmpty ? lines[0] : contentText;
        final definition = lines.length > 1 ? lines[1] : 'Definition needed';
        
        content = TermContent(
          id: uuid.v4(),
          lessonId: '', // Will be set when lesson is saved
          order: 0, // Will be set by parent
          term: term,
          definition: definition,
          example: lines.length > 2 ? lines[2] : null,
          createdAt: now,
          updatedAt: now,
        );
        break;

      case 'question':
        // Simple question creation
        content = QuestionContent(
          id: uuid.v4(),
          lessonId: '', // Will be set when lesson is saved
          order: 0, // Will be set by parent
          questionText: contentText,
          options: ['Option A', 'Option B', 'Option C', 'Option D'],
          correctAnswer: 0,
          explanation: 'Explanation needed',
          createdAt: now,
          updatedAt: now,
        );
        break;

      case 'concept':
        content = ConceptContent(
          id: uuid.v4(),
          lessonId: '', // Will be set when lesson is saved
          order: 0, // Will be set by parent
          conceptText: contentText,
          exampleText: null,
          keyPoints: null,
          createdAt: now,
          updatedAt: now,
        );
        break;

      case 'text':
      default:
        content = TextContent(
          id: uuid.v4(),
          lessonId: '', // Will be set when lesson is saved
          order: 0, // Will be set by parent
          text: contentText,
          createdAt: now,
          updatedAt: now,
        );
        break;
    }

    widget.onContentAdded(content);
    _contentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Content',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedContentType,
              decoration: const InputDecoration(
                labelText: 'Content Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'term', child: Text('Term & Definition')),
                DropdownMenuItem(value: 'question', child: Text('Question')),
                DropdownMenuItem(value: 'concept', child: Text('Concept')),
                DropdownMenuItem(value: 'text', child: Text('Text')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedContentType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: _getContentLabel(),
                hintText: _getContentHint(),
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addContent,
              child: const Text('Add Content'),
            ),
          ],
        ),
      ),
    );
  }

  String _getContentLabel() {
    switch (_selectedContentType) {
      case 'term':
        return 'Term Content';
      case 'question':
        return 'Question Text';
      case 'concept':
        return 'Concept Text';
      case 'text':
      default:
        return 'Text Content';
    }
  }

  String _getContentHint() {
    switch (_selectedContentType) {
      case 'term':
        return 'Line 1: Term\nLine 2: Definition\nLine 3: Example (optional)';
      case 'question':
        return 'Enter the question text';
      case 'concept':
        return 'Enter the concept explanation';
      case 'text':
      default:
        return 'Enter any text content';
    }
  }
}
