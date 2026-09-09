import 'package:flutter/material.dart';

/// Form component for creating concept content items
/// 
/// Extracted from LessonBuilderWidget to improve maintainability.
/// Handles concept title, description, and optional key points.
class ConceptContentForm extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController keyPointsController;
  final VoidCallback onAddConcept;

  const ConceptContentForm({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.keyPointsController,
    required this.onAddConcept,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create comprehensive concept explanations with key points',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Concept title input
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Concept Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
              hintText: 'Enter the main concept or topic name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a concept title';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Concept description input
          TextFormField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined),
              hintText: 'Provide a detailed explanation of the concept',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Key points input
          TextFormField(
            controller: keyPointsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Key Points (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.format_list_bulleted),
              hintText: 'Enter key points, one per line:\n• First important point\n• Second important point\n• Third important point',
              alignLabelWithHint: true,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Key points helper
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_list_bulleted,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Key Points Format:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Write each key point on a separate line. You can use:\n'
                        '• Bullet points (•)\n'
                        '• Numbers (1., 2., 3.)\n'
                        '• Hyphens (-)\n'
                        '• Or just plain text',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Add button
          ElevatedButton.icon(
            onPressed: () {
              // Validate required fields
              if (titleController.text.trim().isEmpty || 
                  descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Title and description are required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              onAddConcept();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Concept'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Helper text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips for creating good concepts:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Use clear, descriptive titles\n'
                        '• Explain concepts thoroughly but concisely\n'
                        '• Break down complex ideas into key points\n'
                        '• Include relevant examples in the description',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
