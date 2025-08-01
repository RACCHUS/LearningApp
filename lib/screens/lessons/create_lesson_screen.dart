import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/local_lesson.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';

// Simple text content model
class TextContent extends LessonContent {
  @override
  final String id;
  @override
  final String createdBy;
  final String text;

  TextContent({
    required this.id,
    required this.text,
    required this.createdBy,
  });

  @override
  String get type => 'text';

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'text': text,
        'created_by': createdBy,
      };
}

class CreateLessonScreen extends ConsumerStatefulWidget {
  const CreateLessonScreen({super.key});

  @override
  ConsumerState<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends ConsumerState<CreateLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _contentController = TextEditingController();
  final List<LessonContent> _lessonContents = [];
  bool _isSaving = false;
  
  // Content type selection
  String _selectedContentType = 'text';
  final List<Map<String, dynamic>> _contentTypes = [
    {'value': 'text', 'label': 'Text', 'icon': Icons.text_fields},
    {'value': 'term', 'label': 'Term', 'icon': Icons.notes},
    {'value': 'concept', 'label': 'Concept', 'icon': Icons.lightbulb_outline},
    {'value': 'mcq', 'label': 'MCQ', 'icon': Icons.quiz},
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  Future<void> _importFromJson() async {
    try {
      // For web, we'll use a file picker dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import JSON'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste your JSON content:'),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Paste JSON content here',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final json = jsonDecode(_contentController.text) as Map<String, dynamic>;
                  Navigator.pop(context, json);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid JSON format')),
                  );
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (result != null) {
        _handleImportedJson(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import: $e')),
        );
      }
    }
  }
  
  void _handleImportedJson(Map<String, dynamic> json) {
    try {
      // Clear existing content
      _lessonContents.clear();
      
      // Parse lesson data
      if (json['lesson'] != null) {
        final lessonData = json['lesson'] as Map<String, dynamic>;
        _titleController.text = lessonData['title']?.toString() ?? '';
        _descriptionController.text = lessonData['description']?.toString() ?? '';
        _tagsController.text = (lessonData['tags'] as List<dynamic>?)?.join(', ') ?? '';
      }
      
      // Parse content
      if (json['content'] is List) {
        final contentList = json['content'] as List;
        for (var item in contentList) {
          final contentMap = item as Map<String, dynamic>;
          final type = contentMap['type'] as String? ?? '';
          
          switch (type) {
            case 'term':
              _lessonContents.add(TermContent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                term: contentMap['term']?.toString() ?? '',
                definition: contentMap['definition']?.toString() ?? '',
                example: contentMap['example']?.toString(),
                createdBy: 'current_user',
              ));
              break;
            case 'concept':
              // Handle concept content as text for now
              _lessonContents.add(TextContent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: '${contentMap['title']?.toString() ?? 'Concept'}: ${contentMap['description']?.toString() ?? ''}',
                createdBy: 'current_user',
              ));
              break;
            case 'mcq':
              // Handle MCQ as text for now
              final options = List<String>.from(contentMap['options'] ?? []);
              final correctIndex = contentMap['correctIndex'] as int? ?? 0;
              final question = contentMap['question']?.toString() ?? 'Question';
              _lessonContents.add(TextContent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                text: 'Q: $question\n' 
                    'Options:\n' 
                    '${options.asMap().entries.map((e) => '${e.key + 1}. ${e.value}${e.key == correctIndex ? ' (Correct)' : ''}').join('\n')}\n'
                    '${contentMap['explanation'] != null ? 'Explanation: ${contentMap['explanation']}' : ''}',
                createdBy: 'current_user',
              ));
              break;
            default:
              // Handle plain text content
              if (contentMap['text'] != null) {
                _lessonContents.add(TextContent(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  text: contentMap['text'].toString(),
                  createdBy: 'current_user',
                ));
              }
              break;
          }
        }
        
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing JSON: $e')),
        );
      }
    }
  }
  
  void _addContent() {
    if (_contentController.text.trim().isEmpty) return;
    
    final content = TextContent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: _contentController.text,
      createdBy: 'current_user',
    );
    
    setState(() {
      _lessonContents.add(content);
      _contentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Lesson'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import JSON',
            onPressed: _importFromJson,
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                _saveLesson();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Lesson Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: const OutlineInputBorder(),
                  hintText: 'e.g., flutter, programming, beginner',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('About Tags'),
                          content: const Text(
                            'Add relevant tags to help others find your lesson. '
                            'Separate multiple tags with commas.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Lesson Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Content type selector
              DropdownButtonFormField<String>(
                value: _selectedContentType,
                decoration: const InputDecoration(
                  labelText: 'Content Type',
                  border: OutlineInputBorder(),
                ),
                items: _contentTypes.map<DropdownMenuItem<String>>((type) => DropdownMenuItem<String>(
                  value: type['value'] as String,
                  child: Row(
                    children: [
                      Icon(type['icon'] as IconData, size: 20),
                      const SizedBox(width: 8),
                      Text(type['label'] as String),
                    ],
                  ),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedContentType = value ?? 'text';
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Content input field
              TextField(
                controller: _contentController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Content',
                  hintText: _selectedContentType == 'text' 
                      ? 'Enter your content here...' 
                      : _selectedContentType == 'term' 
                          ? 'Term: Definition\nExample: Flutter: Google\'s UI toolkit for building natively compiled applications' 
                          : _selectedContentType == 'concept' 
                              ? 'Title: Description' 
                              : 'Question\n- Option 1\n- Option 2\n...\nCorrect: 1\nExplanation: ...',
                  border: const OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Add Content button
              ElevatedButton.icon(
                onPressed: _addContent,
                icon: const Icon(Icons.add),
                label: const Text('Add Content'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              // Content list
              if (_lessonContents.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Current Content',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._lessonContents.map((content) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      content is TextContent 
                          ? content.text
                          : 'Content',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(content.runtimeType.toString().replaceAll('Content', '')),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _lessonContents.remove(content);
                        });
                      },
                    ),
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _saveLesson() async {
    if (_lessonContents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one content item')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      // Convert content to a format suitable for saving
      final contentMaps = _lessonContents.map((content) {
        if (content is TextContent) {
          return {
            'type': 'text',
            'text': content.text,
          };
        } else if (content is TermContent) {
          return {
            'type': 'term',
            'term': content.term,
            'definition': content.definition,
            'example': content.example,
          };
        }
        return {'type': 'text', 'text': content.toString()};
      }).toList();
      
      if (currentUser == null) {
        // Create and save local lesson
        final localLesson = LocalLesson(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
          content: contentMaps,
          isLocal: true,
          createdAt: DateTime.now(),
        );
        
        try {
          await LocalLessonService.saveLesson(localLesson);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lesson saved locally. Sign in to sync across devices.'),
              ),
            );
            context.pop();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save lesson locally: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } else {
        // Save to backend
        final lessonRepo = ref.read(lessonCreationProvider);
        
        await lessonRepo.createLesson(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
          createdBy: currentUser.id,
          content: contentMaps,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lesson saved successfully!')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save lesson: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
