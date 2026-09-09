import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/term.dart';

/// Bottom sheet for creating/editing a term (flashcard)
class TermEditorSheet extends StatefulWidget {
  final Term? term;
  final String userId;
  final void Function(Term term) onSave;

  const TermEditorSheet({
    super.key,
    this.term,
    required this.userId,
    required this.onSave,
  });

  /// Show the term editor as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    Term? term,
    required String userId,
    required void Function(Term term) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TermEditorSheet(
        term: term,
        userId: userId,
        onSave: onSave,
      ),
    );
  }

  @override
  State<TermEditorSheet> createState() => _TermEditorSheetState();
}

class _TermEditorSheetState extends State<TermEditorSheet> {
  late final TextEditingController _termController;
  late final TextEditingController _definitionController;
  late final TextEditingController _exampleController;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.term != null;

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController(text: widget.term?.term ?? '');
    _definitionController =
        TextEditingController(text: widget.term?.definition ?? '');
    _exampleController =
        TextEditingController(text: widget.term?.example ?? '');
  }

  @override
  void dispose() {
    _termController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final term = Term(
      id: widget.term?.id ?? const Uuid().v4(),
      term: _termController.text.trim(),
      definition: _definitionController.text.trim(),
      example: _exampleController.text.trim().isEmpty
          ? null
          : _exampleController.text.trim(),
      createdBy: widget.term?.createdBy ?? widget.userId,
    );

    widget.onSave(term);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.style_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Flashcard' : 'Add Flashcard',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Term field
              TextFormField(
                controller: _termController,
                decoration: const InputDecoration(
                  labelText: 'Term',
                  hintText: 'Enter the term or word',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Term is required';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Definition field
              TextFormField(
                controller: _definitionController,
                decoration: const InputDecoration(
                  labelText: 'Definition',
                  hintText: 'Enter the definition',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Definition is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Example field (optional)
              TextFormField(
                controller: _exampleController,
                decoration: const InputDecoration(
                  labelText: 'Example (optional)',
                  hintText: 'Enter an example sentence',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: Text(isEditing ? 'Update' : 'Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
