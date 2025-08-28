import 'package:flutter/material.dart';

/// Form component for creating term content items
/// 
/// Extracted from LessonBuilderWidget to improve maintainability.
/// Handles term, definition, and optional example input.
class TermContentForm extends StatelessWidget {
  final TextEditingController termController;
  final TextEditingController definitionController;
  final TextEditingController exampleController;
  final VoidCallback onAddTerm;

  const TermContentForm({
    super.key,
    required this.termController,
    required this.definitionController,
    required this.exampleController,
    required this.onAddTerm,
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
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.book,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create flashcard-style terms with definitions and examples',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Term input
          TextFormField(
            controller: termController,
            decoration: const InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
              hintText: 'Enter the term or concept name',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a term';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Definition input
          TextFormField(
            controller: definitionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Definition',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description_outlined),
              hintText: 'Provide a clear, concise definition',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a definition';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Example input (optional)
          TextFormField(
            controller: exampleController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Example (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lightbulb_outline),
              hintText: 'Add an example to help explain the term',
              alignLabelWithHint: true,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Add button
          ElevatedButton.icon(
            onPressed: () {
              // Validate required fields
              if (termController.text.trim().isEmpty || 
                  definitionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Term and definition are required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              onAddTerm();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Term'),
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips for creating good terms:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Keep terms concise and specific\n'
                        '• Write clear, easy-to-understand definitions\n'
                        '• Add examples to illustrate complex concepts',
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
