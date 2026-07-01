import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/lesson_editor_provider.dart';
import '../models/term.dart';
import '../models/question.dart';
import '../models/concept.dart';
import '../widgets/editors/term_editor_sheet.dart';
import '../widgets/editors/question_editor_sheet.dart';
import '../widgets/editors/concept_editor_sheet.dart';
import '../widgets/editors/content_list_tile.dart';

/// Screen for creating and editing lessons with mixed content types
class LessonEditorScreen extends ConsumerStatefulWidget {
  final String? lessonId;

  const LessonEditorScreen({
    super.key,
    this.lessonId,
  });

  @override
  ConsumerState<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends ConsumerState<LessonEditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(LessonEditorState state) {
    if (_titleController.text != state.title) {
      _titleController.text = state.title;
    }
    if (_descriptionController.text != (state.description ?? '')) {
      _descriptionController.text = state.description ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(lessonEditorProvider(widget.lessonId));
    final notifier = ref.read(lessonEditorProvider(widget.lessonId).notifier);

    // Sync controllers when state changes from loading
    if (!state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncControllersFromState(state);
      });
    }

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.isNewLesson ? 'Create Lesson' : 'Edit Lesson'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (state.isDirty) {
                final shouldPop = await _showUnsavedChangesDialog();
                if (shouldPop && context.mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            if (state.isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.circle,
                  size: 12,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            if (state.isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: state.isValid ? () => _save(notifier) : null,
                icon: const Icon(Icons.save),
                tooltip: 'Save lesson',
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: Badge(
                  label: Text('${state.terms.length}'),
                  isLabelVisible: state.terms.isNotEmpty,
                  child: const Icon(Icons.style_outlined),
                ),
                text: 'Flashcards',
              ),
              Tab(
                icon: Badge(
                  label: Text('${state.questions.length}'),
                  isLabelVisible: state.questions.isNotEmpty,
                  child: const Icon(Icons.quiz_outlined),
                ),
                text: 'Questions',
              ),
              Tab(
                icon: Badge(
                  label: Text('${state.concepts.length}'),
                  isLabelVisible: state.concepts.isNotEmpty,
                  child: const Icon(Icons.lightbulb_outline),
                ),
                text: 'Concepts',
              ),
            ],
          ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Lesson metadata form
                _buildMetadataSection(theme, state, notifier),

                // Error message
                if (state.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: notifier.clearError,
                          icon: const Icon(Icons.close),
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTermsTab(state, notifier),
                      _buildQuestionsTab(state, notifier),
                      _buildConceptsTab(state, notifier),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContent(notifier, state),
        icon: const Icon(Icons.add),
        label: Text(_getAddButtonLabel()),
      ),
      ),
    );
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
              'You have unsaved changes. Are you sure you want to leave?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildMetadataSection(
    ThemeData theme,
    LessonEditorState state,
    LessonEditorNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                hintText: 'Enter a title for your lesson',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: notifier.setTitle,
              validator: (value) {
                if (value == null || value.trim().length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe what this lesson covers',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              onChanged: notifier.setDescription,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsTab(LessonEditorState state, LessonEditorNotifier notifier) {
    if (state.terms.isEmpty) {
      return EmptyContentState(
        type: ContentItemType.term,
        onAdd: () => _showTermEditor(notifier),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.terms.length,
      onReorder: notifier.reorderTerms,
      itemBuilder: (context, index) {
        final term = state.terms[index];
        return ContentListTile(
          key: ValueKey(term.id),
          title: term.term,
          subtitle: term.definition,
          type: ContentItemType.term,
          index: index,
          onEdit: () => _showTermEditor(notifier, term: term),
          onDelete: () => notifier.removeTerm(term.id),
        );
      },
    );
  }

  Widget _buildQuestionsTab(
    LessonEditorState state,
    LessonEditorNotifier notifier,
  ) {
    if (state.questions.isEmpty) {
      return EmptyContentState(
        type: ContentItemType.question,
        onAdd: () => _showQuestionEditor(notifier),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.questions.length,
      onReorder: notifier.reorderQuestions,
      itemBuilder: (context, index) {
        final question = state.questions[index];
        return ContentListTile(
          key: ValueKey(question.id),
          title: question.questionText,
          subtitle: _getQuestionSubtitle(question),
          type: ContentItemType.question,
          index: index,
          onEdit: () => _showQuestionEditor(notifier, question: question),
          onDelete: () => notifier.removeQuestion(question.id),
        );
      },
    );
  }

  Widget _buildConceptsTab(
    LessonEditorState state,
    LessonEditorNotifier notifier,
  ) {
    if (state.concepts.isEmpty) {
      return EmptyContentState(
        type: ContentItemType.concept,
        onAdd: () => _showConceptEditor(notifier, state),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.concepts.length,
      onReorder: notifier.reorderConcepts,
      itemBuilder: (context, index) {
        final concept = state.concepts[index];
        return ContentListTile(
          key: ValueKey(concept.id),
          title: concept.conceptText,
          subtitle: concept.exampleText,
          type: ContentItemType.concept,
          index: index,
          onEdit: () => _showConceptEditor(notifier, state, concept: concept),
          onDelete: () => notifier.removeConcept(concept.id),
        );
      },
    );
  }

  String _getQuestionSubtitle(Question question) {
    switch (question.type) {
      case 'multiple_choice':
        return 'Multiple Choice • ${question.options.length} options';
      case 'true_false':
        return 'True/False';
      case 'fill_in_blank':
        return 'Fill in Blank';
      default:
        return question.type;
    }
  }

  String _getAddButtonLabel() {
    switch (_tabController.index) {
      case 0:
        return 'Add Flashcard';
      case 1:
        return 'Add Question';
      case 2:
        return 'Add Concept';
      default:
        return 'Add';
    }
  }

  void _addContent(LessonEditorNotifier notifier, LessonEditorState state) {
    switch (_tabController.index) {
      case 0:
        _showTermEditor(notifier);
        break;
      case 1:
        _showQuestionEditor(notifier);
        break;
      case 2:
        _showConceptEditor(notifier, state);
        break;
    }
  }

  void _showTermEditor(LessonEditorNotifier notifier, {Term? term}) {
    TermEditorSheet.show(
      context: context,
      term: term,
      userId: _userId,
      onSave: (savedTerm) {
        if (term != null) {
          notifier.updateTerm(term.id, savedTerm);
        } else {
          notifier.addTerm(savedTerm);
        }
      },
    );
  }

  void _showQuestionEditor(LessonEditorNotifier notifier, {Question? question}) {
    QuestionEditorSheet.show(
      context: context,
      question: question,
      userId: _userId,
      onSave: (savedQuestion) {
        if (question != null) {
          notifier.updateQuestion(question.id, savedQuestion);
        } else {
          notifier.addQuestion(savedQuestion);
        }
      },
    );
  }

  void _showConceptEditor(
    LessonEditorNotifier notifier,
    LessonEditorState state, {
    Concept? concept,
  }) {
    final lessonId = state.lessonId ?? 'temp-${DateTime.now().millisecondsSinceEpoch}';
    ConceptEditorSheet.show(
      context: context,
      concept: concept,
      userId: _userId,
      lessonId: lessonId,
      onSave: (savedConcept) {
        if (concept != null) {
          notifier.updateConcept(concept.id, savedConcept);
        } else {
          notifier.addConcept(savedConcept);
        }
      },
    );
  }

  Future<void> _save(LessonEditorNotifier notifier) async {
    if (!_formKey.currentState!.validate()) return;

    final lesson = await notifier.save();
    if (!mounted) return;
    if (lesson != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lesson "${lesson.title}" saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(lesson);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save lesson. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
