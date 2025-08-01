import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/lesson_creation_provider.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/widgets/content_management_panel.dart';
import 'package:learning_pwa/widgets/tag_input_field.dart';

class AddLessonScreen extends ConsumerStatefulWidget {
  const AddLessonScreen({super.key});

  @override
  ConsumerState<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends ConsumerState<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  File? _jsonFile;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickJsonFile() async {
    // TODO: Implement file picker functionality
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File picker not implemented yet')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(lessonCreationProvider.notifier);
    final state = ref.read(lessonCreationProvider);
    
    // Validate content
    if (state.content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one content item')),
        );
      }
      return;
    }

    notifier.setLoading(true);

    try {
      final lessonService = LessonService();
      final userId = ref.read(authProvider) is AuthSuccess 
          ? (ref.read(authProvider) as AuthSuccess).user.id 
          : 'guest';
      
      if (_jsonFile != null) {
        // Import from JSON file
        final jsonString = await _jsonFile!.readAsString();
        final lesson = await lessonService.importLessonFromJson(
          jsonString,
          userId,
        );
        if (mounted) {
          Navigator.of(context).pop(lesson);
        }
      } else {
        // Create lesson manually
        final lesson = await lessonService.addLesson(
          _titleController.text,
          _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null,
          userId,
        );
        
        // Add lesson content
        await lessonService.addLessonContent(lesson.id, state.content);
        
        if (mounted) {
          Navigator.of(context).pop(lesson);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating lesson: $e')),
        );
      }
    } finally {
      notifier.setLoading(false);
      notifier.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lessonCreationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Lesson'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: state.isLoading ? null : _submit,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // JSON Import Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import from JSON',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _jsonFile?.path.split('/').last ?? 'No file selected',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickJsonFile,
                            child: const Text('Choose File'),
                          ),
                        ],
                      ),
                      if (_jsonFile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: Importing a JSON file will override manual inputs',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'OR',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              // Manual Entry Section
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
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Tags Input
              TagInputField(
                tags: state.tags,
                onTagAdded: (tag) => ref
                    .read(lessonCreationProvider.notifier)
                    .addTag(tag),
                onTagRemoved: (tag) => ref
                    .read(lessonCreationProvider.notifier)
                    .removeTag(tag),
              ),
              const SizedBox(height: 24),
              // Content Management Section
              Text(
                'Lesson Content',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              // Content Management Panel
              Expanded(
                child: ContentManagementPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
