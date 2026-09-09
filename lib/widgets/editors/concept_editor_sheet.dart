import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/concept.dart';

/// Bottom sheet for creating/editing a concept
class ConceptEditorSheet extends StatefulWidget {
  final Concept? concept;
  final String userId;
  final String lessonId;
  final void Function(Concept concept) onSave;

  const ConceptEditorSheet({
    super.key,
    this.concept,
    required this.userId,
    required this.lessonId,
    required this.onSave,
  });

  @override
  State<ConceptEditorSheet> createState() => _ConceptEditorSheetState();

  /// Show the concept editor as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    Concept? concept,
    required String userId,
    required String lessonId,
    required void Function(Concept concept) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ConceptEditorSheet(
        concept: concept,
        userId: userId,
        lessonId: lessonId,
        onSave: onSave,
      ),
    );
  }
}

class _ConceptEditorSheetState extends State<ConceptEditorSheet> {
  late final TextEditingController _conceptTextController;
  late final TextEditingController _exampleController;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.concept != null;

  @override
  void initState() {
    super.initState();
    _conceptTextController =
        TextEditingController(text: widget.concept?.conceptText ?? '');
    _exampleController =
        TextEditingController(text: widget.concept?.exampleText ?? '');
  }

  @override
  void dispose() {
    _conceptTextController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final concept = Concept(
      id: widget.concept?.id ?? const Uuid().v4(),
      lessonId: widget.lessonId,
      conceptText: _conceptTextController.text.trim(),
      exampleText: _exampleController.text.trim().isEmpty
          ? null
          : _exampleController.text.trim(),
      createdBy: widget.concept?.createdBy ?? widget.userId,
      createdAt: widget.concept?.createdAt ?? DateTime.now(),
    );

    widget.onSave(concept);
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
                    Icons.lightbulb_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Concept' : 'Add Concept',
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

              // Concept text field
              TextFormField(
                controller: _conceptTextController,
                decoration: const InputDecoration(
                  labelText: 'Concept',
                  hintText: 'Explain the concept',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Concept text is required';
                  }
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Example field (optional)
              TextFormField(
                controller: _exampleController,
                decoration: const InputDecoration(
                  labelText: 'Example (optional)',
                  hintText: 'Provide an example',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
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
