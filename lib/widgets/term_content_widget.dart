import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';

class TermContentWidget extends StatefulWidget {
  final TermContent? initialContent;
  final Function(TermContent) onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const TermContentWidget({
    super.key,
    this.initialContent,
    required this.onSave,
    this.onCancel,
    this.onDelete,
  });

  @override
  State<TermContentWidget> createState() => _TermContentWidgetState();
}

class _TermContentWidgetState extends State<TermContentWidget> {
  late final TextEditingController _termController;
  late final TextEditingController _definitionController;
  late final TextEditingController _exampleController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController(text: widget.initialContent?.term ?? '');
    _definitionController = TextEditingController(
      text: widget.initialContent?.definition ?? '',
    );
    _exampleController = TextEditingController(
      text: widget.initialContent?.example ?? '',
    );
  }

  @override
  void dispose() {
    _termController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave(
        TermContent(
          id: widget.initialContent?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          lessonId: '', // Will be set by parent
          order: 0, // Will be set by parent
          term: _termController.text,
          definition: _definitionController.text,
          example: _exampleController.text.isNotEmpty
              ? _exampleController.text
              : null,
          createdAt: widget.initialContent?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialContent != null;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _termController,
            decoration: const InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(),
              hintText: 'Enter the term',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a term';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _definitionController,
            decoration: const InputDecoration(
              labelText: 'Definition',
              border: OutlineInputBorder(),
              hintText: 'Enter the definition',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a definition';
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
              hintText: 'Enter an example usage',
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
    );
  }
}
