import 'package:flutter/material.dart';

/// Form component for creating MCQ (Multiple Choice Question) content items
/// 
/// Extracted from LessonBuilderWidget to improve maintainability.
/// Handles question, options, correct answer selection, and explanation.
class McqContentForm extends StatefulWidget {
  final TextEditingController questionController;
  final List<TextEditingController> optionControllers;
  final TextEditingController explanationController;
  final int correctAnswer;
  final Function(int) onCorrectAnswerChanged;
  final VoidCallback onAddQuestion;

  const McqContentForm({
    super.key,
    required this.questionController,
    required this.optionControllers,
    required this.explanationController,
    required this.correctAnswer,
    required this.onCorrectAnswerChanged,
    required this.onAddQuestion,
  });

  @override
  State<McqContentForm> createState() => _McqContentFormState();
}

class _McqContentFormState extends State<McqContentForm> {
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
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.quiz,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create multiple choice questions to test understanding',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Question input
          TextFormField(
            controller: widget.questionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.help_outline),
              hintText: 'Enter your multiple choice question',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a question';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Options section
          Text(
            'Answer Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Option inputs with radio buttons
          ...List.generate(4, (index) {
            final isRequired = index < 2;
            final optionLetter = String.fromCharCode(65 + index); // A, B, C, D
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.correctAnswer == index 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    width: widget.correctAnswer == index ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: widget.correctAnswer == index 
                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
                      : null,
                ),
                child: Row(
                  children: [
                    // Radio button
                    Radio<int>(
                      value: index,
                      groupValue: widget.correctAnswer,
                      onChanged: (value) {
                        if (value != null) {
                          widget.onCorrectAnswerChanged(value);
                        }
                      },
                    ),
                    
                    // Option letter
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.correctAnswer == index 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          optionLetter,
                          style: TextStyle(
                            color: widget.correctAnswer == index 
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Option text field
                    Expanded(
                      child: TextFormField(
                        controller: widget.optionControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Option $optionLetter${isRequired ? ' (required)' : ''}',
                          border: InputBorder.none,
                          hintText: 'Enter answer option',
                        ),
                        validator: isRequired ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Option $optionLetter is required';
                          }
                          return null;
                        } : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          // Correct answer indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Correct Answer: Option ${String.fromCharCode(65 + widget.correctAnswer)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Explanation input
          TextFormField(
            controller: widget.explanationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.info_outline),
              hintText: 'Explain why this is the correct answer',
              alignLabelWithHint: true,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Add button
          ElevatedButton.icon(
            onPressed: () {
              // Validate required fields
              if (widget.questionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Question is required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              // Check if at least 2 options are provided
              final filledOptions = widget.optionControllers
                  .take(2)
                  .where((controller) => controller.text.trim().isNotEmpty)
                  .length;
              
              if (filledOptions < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('At least 2 answer options are required'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              widget.onAddQuestion();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
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
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips for creating good MCQs:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '• Make questions clear and specific\n'
                        '• Avoid "all of the above" or "none of the above"\n'
                        '• Keep options roughly the same length\n'
                        '• Select the correct answer before adding',
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
