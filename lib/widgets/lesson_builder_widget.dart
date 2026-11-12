import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'lesson/lesson_metadata_form.dart';
import 'lesson/content_type_selector.dart';
import 'lesson/term_content_form.dart';
import 'lesson/mcq_content_form.dart';
import 'lesson/concept_content_form.dart';
import 'lesson/content_preview_list.dart';
import 'package:learning_pwa/models/answer_key.dart';

/// Refactored lesson builder widget with extracted components
///
/// This widget now orchestrates the lesson creation process using
/// smaller, focused components instead of being a monolithic widget.
class LessonBuilderWidget extends StatefulWidget {
  final int initialContentTabIndex;
  final Function({
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> content,
  })
  onCreateLesson;

  const LessonBuilderWidget({
    super.key,
    this.initialContentTabIndex = 0,
    required this.onCreateLesson,
  });

  @override
  State<LessonBuilderWidget> createState() => _LessonBuilderWidgetState();
}

class _LessonBuilderWidgetState extends State<LessonBuilderWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Lesson metadata controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];

  // Content management
  late TabController _contentTabController;
  final List<Map<String, dynamic>> _contentItems = [];

  // Term content controllers
  final _termController = TextEditingController();
  final _definitionController = TextEditingController();
  final _exampleController = TextEditingController();

  // MCQ content controllers
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final _explanationController = TextEditingController();

  /// Explicitly chosen correct option; never defaulted to option A.
  int? _correctAnswer;

  // Concept content controllers
  final _conceptTitleController = TextEditingController();
  final _conceptDescriptionController = TextEditingController();
  final _conceptKeyPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialTab = widget.initialContentTabIndex.clamp(0, 2);
    _contentTabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _contentTabController.dispose();

    _termController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();

    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    _explanationController.dispose();

    _conceptTitleController.dispose();
    _conceptDescriptionController.dispose();
    _conceptKeyPointsController.dispose();

    super.dispose();
  }

  // Tag management methods
  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    } else if (_tags.length >= 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 10 tags allowed')));
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  // Content creation methods
  void _addTermContent() {
    final term = _termController.text.trim();
    final definition = _definitionController.text.trim();
    final example = _exampleController.text.trim();

    if (term.isNotEmpty && definition.isNotEmpty) {
      final contentItem = {
        'id': const Uuid().v4(),
        'type': 'term',
        'term': term,
        'definition': definition,
        if (example.isNotEmpty) 'example': example,
      };

      setState(() {
        _contentItems.add(contentItem);
        _termController.clear();
        _definitionController.clear();
        _exampleController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Term "$term" added successfully')),
      );
    }
  }

  void _addQuestionContent() {
    final question = _questionController.text.trim();
    final rawOptions = _optionControllers
        .map((controller) => controller.text.trim())
        .toList();
    // Blank options are dropped, so map the chosen option to its position in
    // the kept list instead of reusing a now-shifted index.
    final options = rawOptions.where((option) => option.isNotEmpty).toList();
    final explanation = _explanationController.text.trim();

    if (question.isNotEmpty && options.length >= 2) {
      final selected = _correctAnswer;
      final correctIndex =
          selected != null &&
              AnswerKey.inRange(selected, rawOptions) &&
              rawOptions[selected].isNotEmpty
          ? rawOptions.take(selected).where((o) => o.isNotEmpty).length
          : null;
      final key = AnswerKey.fromIndex(correctIndex, options);
      if (!key.isScorable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selected == null
                  ? 'Choose the correct answer before adding the question.'
                  : (correctIndex == null
                        ? 'The option you marked correct is empty.'
                        : key.detail ?? 'The correct answer is not valid.'),
            ),
          ),
        );
        return;
      }
      final contentItem = {
        'id': const Uuid().v4(),
        'type': 'mcq',
        'question': question,
        'options': options,
        'correctIndex': key.index,
        if (explanation.isNotEmpty) 'explanation': explanation,
      };

      setState(() {
        _contentItems.add(contentItem);
        _questionController.clear();
        for (final controller in _optionControllers) {
          controller.clear();
        }
        _explanationController.clear();
        _correctAnswer = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added successfully')),
      );
    }
  }

  void _addConceptContent() {
    final title = _conceptTitleController.text.trim();
    final description = _conceptDescriptionController.text.trim();
    final keyPointsText = _conceptKeyPointsController.text.trim();

    if (title.isNotEmpty && description.isNotEmpty) {
      // Parse key points (split by newlines and filter out empty lines)
      final keyPoints = keyPointsText.isNotEmpty
          ? keyPointsText
                .split('\n')
                .map((point) => point.trim())
                .where((point) => point.isNotEmpty)
                .toList()
          : <String>[];

      final contentItem = {
        'id': const Uuid().v4(),
        'type': 'concept',
        'title': title,
        'description': description,
        if (keyPoints.isNotEmpty) 'keyPoints': keyPoints,
      };

      setState(() {
        _contentItems.add(contentItem);
        _conceptTitleController.clear();
        _conceptDescriptionController.clear();
        _conceptKeyPointsController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Concept "$title" added successfully')),
      );
    }
  }

  // Content management methods
  void _reorderContentItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _contentItems.removeAt(oldIndex);
      _contentItems.insert(newIndex, item);
    });
  }

  void _removeContentItem(int index) {
    setState(() {
      _contentItems.removeAt(index);
    });
  }

  void _createLesson() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_contentItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one content item'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      widget.onCreateLesson(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: _tags,
        content: _contentItems,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lesson metadata form
            LessonMetadataForm(
              titleController: _titleController,
              descriptionController: _descriptionController,
              tagController: _tagController,
              tags: _tags,
              onAddTag: _addTag,
              onRemoveTag: _removeTag,
            ),

            const SizedBox(height: 16),

            // Content type selector and forms
            ContentTypeSelector(
              tabController: _contentTabController,
              contentItemsCount: _contentItems.length,
            ),

            const SizedBox(height: 16),

            // Content forms in tab view
            SizedBox(
              height: 400,
              child: TabBarView(
                controller: _contentTabController,
                children: [
                  // Terms form
                  // Own Form: these fields are checked by their Add
                  // button, not by the lesson-level Create (whose
                  // validation previously failed on cleared fields).
                  Form(
                    child: TermContentForm(
                      termController: _termController,
                      definitionController: _definitionController,
                      exampleController: _exampleController,
                      onAddTerm: _addTermContent,
                    ),
                  ),

                  // MCQ form
                  // Own Form: these fields are checked by their Add
                  // button, not by the lesson-level Create (whose
                  // validation previously failed on cleared fields).
                  Form(
                    child: McqContentForm(
                      questionController: _questionController,
                      optionControllers: _optionControllers,
                      explanationController: _explanationController,
                      correctAnswer: _correctAnswer,
                      onCorrectAnswerChanged: (value) {
                        setState(() {
                          _correctAnswer = value;
                        });
                      },
                      onAddQuestion: _addQuestionContent,
                    ),
                  ),

                  // Concept form
                  // Own Form: these fields are checked by their Add
                  // button, not by the lesson-level Create (whose
                  // validation previously failed on cleared fields).
                  Form(
                    child: ConceptContentForm(
                      titleController: _conceptTitleController,
                      descriptionController: _conceptDescriptionController,
                      keyPointsController: _conceptKeyPointsController,
                      onAddConcept: _addConceptContent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content preview and create lesson
            ContentPreviewList(
              contentItems: _contentItems,
              onReorder: _reorderContentItems,
              onRemoveItem: _removeContentItem,
              onCreateLesson: _createLesson,
              canCreateLesson: _contentItems.isNotEmpty,
            ),
          ],
        ),
      ),
    );
  }
}
