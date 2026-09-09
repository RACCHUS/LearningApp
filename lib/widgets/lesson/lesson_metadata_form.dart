import 'package:flutter/material.dart';

/// Form component for lesson metadata (title, description, t                      onFieldSubmitted: (_) => widget.onAddTag(),gs)
/// 
/// Extracted from LessonBuilderWidget to improve maintainability
/// and follow single responsibility principle.
class LessonMetadataForm extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController tagController;
  final List<String> tags;
  final VoidCallback onAddTag;
  final Function(String) onRemoveTag;

  const LessonMetadataForm({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.tagController,
    required this.tags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  State<LessonMetadataForm> createState() => _LessonMetadataFormState();
}

class _LessonMetadataFormState extends State<LessonMetadataForm> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lesson Details',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Title field
            TextFormField(
              controller: widget.titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                hintText: 'Enter a descriptive title for your lesson',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a lesson title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters long';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Description field
            TextFormField(
              controller: widget.descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
                hintText: 'Describe what students will learn in this lesson',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Tags section
            Text(
              'Tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            // Tag input row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add Tag',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                      hintText: 'e.g., Math, Beginner, Algebra',
                    ),
                    onFieldSubmitted: (_) => widget.onAddTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.onAddTag,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Tags display
            if (widget.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => widget.onRemoveTag(tag),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
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
                      'Add tags to help categorize and search for this lesson',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
