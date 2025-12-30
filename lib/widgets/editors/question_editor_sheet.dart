import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/question.dart';

/// Question types supported
enum QuestionType {
  multipleChoice('multiple_choice', 'Multiple Choice'),
  trueFalse('true_false', 'True/False'),
  fillInBlank('fill_in_blank', 'Fill in Blank');

  final String value;
  final String displayName;
  const QuestionType(this.value, this.displayName);

  static QuestionType fromValue(String value) {
    return QuestionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => QuestionType.multipleChoice,
    );
  }
}

/// Bottom sheet for creating/editing a question
class QuestionEditorSheet extends StatefulWidget {
  final Question? question;
  final String userId;
  final void Function(Question question) onSave;

  const QuestionEditorSheet({
    super.key,
    this.question,
    required this.userId,
    required this.onSave,
  });

  @override
  State<QuestionEditorSheet> createState() => _QuestionEditorSheetState();

  /// Show the question editor as a modal bottom sheet
  static Future<void> show({
    required BuildContext context,
    Question? question,
    required String userId,
    required void Function(Question question) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => QuestionEditorSheet(
        question: question,
        userId: userId,
        onSave: onSave,
      ),
    );
  }
}

class _QuestionEditorSheetState extends State<QuestionEditorSheet> {
  late final TextEditingController _questionController;
  late final TextEditingController _explanationController;
  late QuestionType _questionType;
  late List<TextEditingController> _optionControllers;
  late int _correctAnswer;
  final _formKey = GlobalKey<FormState>();

  bool get isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    _questionController =
        TextEditingController(text: widget.question?.questionText ?? '');
    _explanationController =
        TextEditingController(text: widget.question?.explanation ?? '');
    _questionType =
        QuestionType.fromValue(widget.question?.type ?? 'multiple_choice');
    _correctAnswer = widget.question?.correctAnswer ?? 0;

    // Initialize option controllers
    if (widget.question != null && widget.question!.options.isNotEmpty) {
      _optionControllers = widget.question!.options
          .map((o) => TextEditingController(text: o))
          .toList();
    } else {
      _initDefaultOptions();
    }
  }

  void _initDefaultOptions() {
    switch (_questionType) {
      case QuestionType.multipleChoice:
        _optionControllers = List.generate(
          4,
          (i) => TextEditingController(),
        );
        break;
      case QuestionType.trueFalse:
        _optionControllers = [
          TextEditingController(text: 'True'),
          TextEditingController(text: 'False'),
        ];
        break;
      case QuestionType.fillInBlank:
        _optionControllers = [TextEditingController()];
        break;
    }
    _correctAnswer = 0;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTypeChanged(QuestionType? type) {
    if (type == null || type == _questionType) return;
    setState(() {
      _questionType = type;
      for (final controller in _optionControllers) {
        controller.dispose();
      }
      _initDefaultOptions();
    });
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      if (_correctAnswer >= _optionControllers.length) {
        _correctAnswer = _optionControllers.length - 1;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final options = _optionControllers.map((c) => c.text.trim()).toList();

    final question = Question(
      id: widget.question?.id ?? const Uuid().v4(),
      questionText: _questionController.text.trim(),
      options: options,
      correctAnswer: _correctAnswer,
      type: _questionType.value,
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
      createdBy: widget.question?.createdBy ?? widget.userId,
      createdAt: widget.question?.createdAt ?? DateTime.now(),
    );

    widget.onSave(question);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEditing ? 'Edit Question' : 'Add Question',
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
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question type dropdown
                      DropdownButtonFormField<QuestionType>(
                        value: _questionType,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          border: OutlineInputBorder(),
                        ),
                        items: QuestionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                        onChanged: _onTypeChanged,
                      ),
                      const SizedBox(height: 16),

                      // Question text
                      TextFormField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          labelText: 'Question',
                          hintText: 'Enter your question',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Question is required';
                          }
                          return null;
                        },
                        autofocus: true,
                      ),
                      const SizedBox(height: 24),

                      // Options section
                      if (_questionType != QuestionType.fillInBlank) ...[
                        Text(
                          'Answer Options',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the radio button to select the correct answer',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_optionControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: index,
                                  groupValue: _correctAnswer,
                                  onChanged: (value) {
                                    setState(() => _correctAnswer = value!);
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Option ${String.fromCharCode(65 + index)}',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    enabled:
                                        _questionType != QuestionType.trueFalse,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (_questionType ==
                                        QuestionType.multipleChoice &&
                                    _optionControllers.length > 2)
                                  IconButton(
                                    onPressed: () => _removeOption(index),
                                    icon: const Icon(Icons.remove_circle_outline),
                                    color: theme.colorScheme.error,
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (_questionType == QuestionType.multipleChoice)
                          TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                      ] else ...[
                        // Fill in blank - correct answer field
                        Text(
                          'Correct Answer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _optionControllers[0],
                          decoration: const InputDecoration(
                            labelText: 'Correct Answer',
                            hintText: 'Enter the expected answer',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Correct answer is required';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Explanation (optional)
                      TextFormField(
                        controller: _explanationController,
                        decoration: const InputDecoration(
                          labelText: 'Explanation (optional)',
                          hintText: 'Explain why this is the correct answer',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
