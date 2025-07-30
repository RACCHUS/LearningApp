import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_content.dart';

class ConceptContentWidget extends StatefulWidget {
  final ConceptContent? initialContent;
  final Function(ConceptContent) onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const ConceptContentWidget({
    super.key,
    this.initialContent,
    required this.onSave,
    this.onCancel,
    this.onDelete,
  });

  @override
  State<ConceptContentWidget> createState() => _ConceptContentWidgetState();
}

class _ConceptContentWidgetState extends State<ConceptContentWidget> {
  late final TextEditingController _conceptController;
  late final TextEditingController _exampleController;
  final List<TextEditingController> _keyPointControllers = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _conceptController = TextEditingController(
      text: widget.initialContent?.conceptText ?? '',
    );
    _exampleController = TextEditingController(
      text: widget.initialContent?.exampleText ?? '',
    );

    // Initialize key points
    if (widget.initialContent?.keyPoints != null) {
      for (var point in widget.initialContent!.keyPoints!) {
        _keyPointControllers.add(TextEditingController(text: point));
      }
    } else {
      // Start with one empty key point
      _keyPointControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _conceptController.dispose();
    _exampleController.dispose();
    for (var controller in _keyPointControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addKeyPoint() {
    setState(() {
      _keyPointControllers.add(TextEditingController());
    });
  }

  void _removeKeyPoint(int index) {
    // Don't allow removing if only one key point remains
    if (_keyPointControllers.length <= 1) return;
    
    setState(() {
      _keyPointControllers.removeAt(index).dispose();
    });
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final keyPoints = _keyPointControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      if (keyPoints.isEmpty) {
        keyPoints.add('Key point'); // Ensure at least one key point
      }

      widget.onSave(
        ConceptContent(
          id: widget.initialContent?.id ?? '',
          conceptText: _conceptController.text,
          exampleText: _exampleController.text.isNotEmpty
              ? _exampleController.text
              : null,
          keyPoints: keyPoints.isNotEmpty ? keyPoints : null,
          createdBy: widget.initialContent?.createdBy ?? '',
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
              controller: _conceptController,
              decoration: const InputDecoration(
                labelText: 'Concept',
                border: OutlineInputBorder(),
                hintText: 'Enter the concept or explanation',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the concept';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _exampleController,
              decoration: const InputDecoration(
                labelText: 'Example (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Provide an example',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Key Points:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate(_keyPointControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _keyPointControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Key point ${index + 1}',
                          border: const OutlineInputBorder(),
                          suffixIcon: _keyPointControllers.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _removeKeyPoint(index),
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
              onPressed: _addKeyPoint,
              icon: const Icon(Icons.add),
              label: const Text('Add Key Point'),
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
