import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';

class QuestionContentWidget extends StatefulWidget {
  final QuestionContent? initialContent;
  final Function(QuestionContent) onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const QuestionContentWidget({
    super.key,
    this.initialContent,
    required this.onSave,
    this.onCancel,
    this.onDelete,
  });

  @override
  State<QuestionContentWidget> createState() => _QuestionContentWidgetState();
}

class _QuestionContentWidgetState extends State<QuestionContentWidget> {
  late final TextEditingController _questionController;
  late final List<TextEditingController> _optionControllers;
  late final TextEditingController _explanationController;
  late int _correctAnswerIndex;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(
      text: widget.initialContent?.questionText ?? '',
    );
    
    _explanationController = TextEditingController(
      text: widget.initialContent?.explanation ?? '',
    );
    
    _correctAnswerIndex = widget.initialContent?.correctAnswer ?? 0;
    
    // Initialize options
    _optionControllers = [];
    if (widget.initialContent != null) {
      for (var option in widget.initialContent!.options) {
        _optionControllers.add(TextEditingController(text: option));
      }
    } else {
      // Start with 2 empty options for new questions
      _optionControllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    // Don't allow removing if only 2 options remain
    if (_optionControllers.length <= 2) return;
    
    setState(() {
      _optionControllers.removeAt(index);
      // Adjust correct answer index if needed
      if (_correctAnswerIndex >= index) {
        _correctAnswerIndex = _correctAnswerIndex > 0 ? _correctAnswerIndex - 1 : 0;
      }
    });
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least 2 options')),
        );
        return;
      }

      widget.onSave(
        QuestionContent(
          id: widget.initialContent?.id ?? '',
          questionText: _questionController.text,
          options: options,
          correctAnswer: _correctAnswerIndex,
          explanation: _explanationController.text.isNotEmpty
              ? _explanationController.text
              : null,
          createdBy: widget.initialContent?.createdBy ?? '',
          orderIndex: widget.initialContent?.orderIndex ?? 0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialContent != null;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
                hintText: 'Enter the question',
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a question';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Radio<int>(
                      value: index,
                      groupValue: _correctAnswerIndex,
                      onChanged: (value) {
                        setState(() {
                          _correctAnswerIndex = value!;
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          border: const OutlineInputBorder(),
                          suffixIcon: _optionControllers.length > 2
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _removeOption(index),
                                )
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: const Text('Add Option'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanationController,
              decoration: const InputDecoration(
                labelText: 'Explanation (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Explain why this is the correct answer',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isEditing && widget.onCancel != null)
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('CANCEL'),
                  ),
                if (isEditing && widget.onDelete != null)
                  TextButton(
                    onPressed: widget.onDelete,
                    child: const Text(
                      'DELETE',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSave,
                  child: Text(isEditing ? 'UPDATE' : 'ADD'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
