import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/utils/lesson_json_validator.dart';

class LessonJsonImportWidget extends StatefulWidget {
  final Function(String) onImport;

  const LessonJsonImportWidget({
    super.key,
    required this.onImport,
  });

  @override
  State<LessonJsonImportWidget> createState() => _LessonJsonImportWidgetState();
}

class _LessonJsonImportWidgetState extends State<LessonJsonImportWidget> {
  final _jsonController = TextEditingController();
  String? _validationError;
  List<String>? _validationWarnings;
  Map<String, dynamic>? _parsedJson;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  void _validateJson() {
    final jsonText = _jsonController.text.trim();
    
    if (jsonText.isEmpty) {
      setState(() {
        _validationError = null;
        _validationWarnings = null;
        _parsedJson = null;
      });
      return;
    }

    try {
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      
      // Use the validator
      final validationResult = LessonJsonValidator.validate(parsed);
      
      if (!validationResult.isValid) {
        setState(() {
          _validationError = validationResult.errors.join('\n');
          _validationWarnings = validationResult.warnings;
          _parsedJson = null;
        });
        return;
      }

      setState(() {
        _validationError = null;
        _validationWarnings = validationResult.warnings;
        _parsedJson = parsed;
      });
    } catch (e) {
      setState(() {
        _validationError = 'Invalid JSON format: $e';
        _validationWarnings = null;
        _parsedJson = null;
      });
    }
  }

  Future<void> _loadSampleJson() async {
    try {
      final sampleJson = await rootBundle.loadString('sample_lesson.json');
      _jsonController.text = sampleJson;
      _validateJson();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sample: $e')),
      );
    }
  }

  void _formatJson() {
    if (_parsedJson != null) {
      const encoder = JsonEncoder.withIndent('  ');
      _jsonController.text = encoder.convert(_parsedJson);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Lesson from JSON',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste or type your lesson JSON below. Use the sample button to see the expected format.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadSampleJson,
                        icon: const Icon(Icons.file_copy),
                        label: const Text('Load Sample'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _parsedJson != null ? _formatJson : null,
                        icon: const Icon(Icons.format_align_left),
                        label: const Text('Format'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _parsedJson != null && _validationError == null
                            ? () => widget.onImport(_jsonController.text)
                            : null,
                        icon: const Icon(Icons.upload),
                        label: const Text('Import Lesson'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // JSON input area
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Lesson JSON',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (_validationError == null && _parsedJson != null)
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Valid JSON',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Error display
                    if (_validationError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Warnings display
                    if (_validationWarnings != null && _validationWarnings!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Text(
                                  'Warnings:',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._validationWarnings!.map((warning) => 
                              Padding(
                                padding: const EdgeInsets.only(left: 32, bottom: 4),
                                child: Text(
                                  '• $warning',
                                  style: const TextStyle(color: Colors.orange),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // JSON text field
                    Expanded(
                      child: TextField(
                        controller: _jsonController,
                        onChanged: (_) => _validateJson(),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Paste your lesson JSON here...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Preview section
          if (_parsedJson != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _buildPreview(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_parsedJson == null) return const SizedBox.shrink();

    final lesson = _parsedJson!['lesson'] as Map<String, dynamic>;
    final content = _parsedJson!['content'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lesson['title'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        if (lesson['description'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(lesson['description'] as String),
          ),
        if (lesson['tags'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: (lesson['tags'] as List)
                  .map((tag) => Chip(
                        label: Text(tag as String),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Content: ${content.length} items',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...content.take(3).map((item) {
          final itemMap = item as Map<String, dynamic>;
          final type = itemMap['type'] as String;
          String title = '';
          
          switch (type) {
            case 'term':
              title = itemMap['term'] as String? ?? 'Term';
              break;
            case 'mcq':
              title = itemMap['question'] as String? ?? 'Question';
              break;
            case 'concept':
              title = itemMap['title'] as String? ?? 'Concept';
              break;
            default:
              title = 'Content Item';
          }
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  _getIconForType(type),
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text('$type: $title'),
              ],
            ),
          );
        }).toList(),
        if (content.length > 3)
          Text('... and ${content.length - 3} more items'),
      ],
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
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.help;
    }
  }
}
