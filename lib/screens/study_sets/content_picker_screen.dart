import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/providers/study_set_provider.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Selection state for content picker
class ContentSelection {
  final Set<String> selectedTermIds;
  final Set<String> selectedQuestionIds;
  final Set<String> selectedConceptIds;

  const ContentSelection({
    this.selectedTermIds = const {},
    this.selectedQuestionIds = const {},
    this.selectedConceptIds = const {},
  });

  int get totalSelected =>
      selectedTermIds.length +
      selectedQuestionIds.length +
      selectedConceptIds.length;

  ContentSelection copyWith({
    Set<String>? selectedTermIds,
    Set<String>? selectedQuestionIds,
    Set<String>? selectedConceptIds,
  }) {
    return ContentSelection(
      selectedTermIds: selectedTermIds ?? this.selectedTermIds,
      selectedQuestionIds: selectedQuestionIds ?? this.selectedQuestionIds,
      selectedConceptIds: selectedConceptIds ?? this.selectedConceptIds,
    );
  }
}

/// State notifier for managing content selection
class ContentSelectionNotifier extends StateNotifier<ContentSelection> {
  ContentSelectionNotifier() : super(const ContentSelection());

  void toggleTerm(String id) {
    final newSet = Set<String>.from(state.selectedTermIds);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = state.copyWith(selectedTermIds: newSet);
  }

  void toggleQuestion(String id) {
    final newSet = Set<String>.from(state.selectedQuestionIds);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = state.copyWith(selectedQuestionIds: newSet);
  }

  void toggleConcept(String id) {
    final newSet = Set<String>.from(state.selectedConceptIds);
    if (newSet.contains(id)) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = state.copyWith(selectedConceptIds: newSet);
  }

  void selectAllTerms(List<Term> terms) {
    state = state.copyWith(
      selectedTermIds: terms.map((t) => t.id).toSet(),
    );
  }

  void selectAllQuestions(List<Question> questions) {
    state = state.copyWith(
      selectedQuestionIds: questions.map((q) => q.id).toSet(),
    );
  }

  void selectAllConcepts(List<Concept> concepts) {
    state = state.copyWith(
      selectedConceptIds: concepts.map((c) => c.id).toSet(),
    );
  }

  void clearTerms() {
    state = state.copyWith(selectedTermIds: {});
  }

  void clearQuestions() {
    state = state.copyWith(selectedQuestionIds: {});
  }

  void clearConcepts() {
    state = state.copyWith(selectedConceptIds: {});
  }

  void clearAll() {
    state = const ContentSelection();
  }
}

/// Provider for content selection state
final contentSelectionProvider = StateNotifierProvider.autoDispose<
    ContentSelectionNotifier,
    ContentSelection>((ref) => ContentSelectionNotifier());

/// Provider for loading lessons for content picking
final contentPickerLessonsProvider =
    FutureProvider.family<List<Lesson>, List<String>>((ref, lessonIds) async {
  if (lessonIds.isEmpty) return [];

  final lessonService = LessonService();
  final lessons = <Lesson>[];

  for (final id in lessonIds) {
    try {
      final lesson = await lessonService.getLesson(id);
      lessons.add(lesson);
    } catch (e) {
      // Skip lessons that fail to load
    }
  }

  return lessons;
});

/// Screen for picking individual content items (terms, questions, concepts)
/// from multiple lessons to create a custom study set
class ContentPickerScreen extends ConsumerStatefulWidget {
  final List<String> lessonIds;
  final String? title;

  const ContentPickerScreen({
    super.key,
    required this.lessonIds,
    this.title,
  });

  @override
  ConsumerState<ContentPickerScreen> createState() =>
      _ContentPickerScreenState();
}

class _ContentPickerScreenState extends ConsumerState<ContentPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync =
        ref.watch(contentPickerLessonsProvider(widget.lessonIds));
    final selection = ref.watch(contentSelectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Pick Content'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Terms', icon: Icon(Icons.style)),
            Tab(text: 'Questions', icon: Icon(Icons.quiz)),
            Tab(text: 'Concepts', icon: Icon(Icons.lightbulb)),
          ],
        ),
        actions: [
          if (selection.totalSelected > 0)
            TextButton(
              onPressed: () =>
                  ref.read(contentSelectionProvider.notifier).clearAll(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: lessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load content'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref
                    .invalidate(contentPickerLessonsProvider(widget.lessonIds)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (lessons) {
          // Aggregate all content from lessons
          final allTerms = lessons.expand((l) => l.terms).toList();
          final allQuestions = lessons.expand((l) => l.questions).toList();
          final allConcepts = lessons.expand((l) => l.concepts).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _TermsTab(terms: allTerms, lessons: lessons),
              _QuestionsTab(questions: allQuestions, lessons: lessons),
              _ConceptsTab(concepts: allConcepts, lessons: lessons),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context, selection),
    );
  }

  Widget _buildBottomBar(BuildContext context, ContentSelection selection) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selection.totalSelected} items selected',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (selection.totalSelected > 0)
                    Text(
                      '${selection.selectedTermIds.length} terms, '
                      '${selection.selectedQuestionIds.length} questions, '
                      '${selection.selectedConceptIds.length} concepts',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: selection.totalSelected == 0
                  ? null
                  : () {
                      _createStudySet(context, selection);
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Study'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createStudySet(BuildContext context, ContentSelection selection) async {
    // Show dialog to get study set name
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Study Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter a name for your study set',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add a description',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Text(
              '${selection.totalSelected} items selected',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true || titleController.text.trim().isEmpty) {
      titleController.dispose();
      descriptionController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();

    if (!context.mounted) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating study set "$title"...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      // Create the study set using the provider
      final studySetNotifier = ProviderScope.containerOf(context).read(studySetProvider.notifier);
      final studySet = await studySetNotifier.createStudySetWithContent(
        title: title,
        description: description.isNotEmpty ? description : null,
        termIds: selection.selectedTermIds.toList(),
        questionIds: selection.selectedQuestionIds.toList(),
        conceptIds: selection.selectedConceptIds.toList(),
      );

      if (!context.mounted) return;

      if (studySet != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Study set "$title" created!'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                context.go('/study-sets');
              },
            ),
          ),
        );
        context.pop(selection);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create study set'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Tab showing terms with checkboxes
class _TermsTab extends ConsumerWidget {
  final List<Term> terms;
  final List<Lesson> lessons;

  const _TermsTab({required this.terms, required this.lessons});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(contentSelectionProvider);
    final notifier = ref.read(contentSelectionProvider.notifier);

    if (terms.isEmpty) {
      return const _EmptyState(
        icon: Icons.style_outlined,
        message: 'No terms available',
      );
    }

    return Column(
      children: [
        _SelectAllBar(
          selectedCount: selection.selectedTermIds.length,
          totalCount: terms.length,
          onSelectAll: () => notifier.selectAllTerms(terms),
          onClear: () => notifier.clearTerms(),
        ),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
            itemCount: terms.length,
            itemBuilder: (context, index) {
              final term = terms[index];
              final isSelected = selection.selectedTermIds.contains(term.id);
              final lesson = _findLessonForTerm(term);

              return _ContentTile(
                title: term.term,
                subtitle: term.definition,
                lessonTitle: lesson?.title,
                isSelected: isSelected,
                onTap: () => notifier.toggleTerm(term.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Lesson? _findLessonForTerm(Term term) {
    for (final lesson in lessons) {
      if (lesson.terms.any((t) => t.id == term.id)) {
        return lesson;
      }
    }
    return null;
  }
}

/// Tab showing questions with checkboxes
class _QuestionsTab extends ConsumerWidget {
  final List<Question> questions;
  final List<Lesson> lessons;

  const _QuestionsTab({required this.questions, required this.lessons});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(contentSelectionProvider);
    final notifier = ref.read(contentSelectionProvider.notifier);

    if (questions.isEmpty) {
      return const _EmptyState(
        icon: Icons.quiz_outlined,
        message: 'No questions available',
      );
    }

    return Column(
      children: [
        _SelectAllBar(
          selectedCount: selection.selectedQuestionIds.length,
          totalCount: questions.length,
          onSelectAll: () => notifier.selectAllQuestions(questions),
          onClear: () => notifier.clearQuestions(),
        ),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final question = questions[index];
              final isSelected =
                  selection.selectedQuestionIds.contains(question.id);
              final lesson = _findLessonForQuestion(question);

              return _ContentTile(
                title: question.questionText,
                subtitle:
                    'Answer: ${question.options.isNotEmpty && question.correctAnswer >= 0 && question.correctAnswer < question.options.length ? question.options[question.correctAnswer] : "N/A"}',
                lessonTitle: lesson?.title,
                isSelected: isSelected,
                onTap: () => notifier.toggleQuestion(question.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Lesson? _findLessonForQuestion(Question question) {
    for (final lesson in lessons) {
      if (lesson.questions.any((q) => q.id == question.id)) {
        return lesson;
      }
    }
    return null;
  }
}

/// Tab showing concepts with checkboxes
class _ConceptsTab extends ConsumerWidget {
  final List<Concept> concepts;
  final List<Lesson> lessons;

  const _ConceptsTab({required this.concepts, required this.lessons});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(contentSelectionProvider);
    final notifier = ref.read(contentSelectionProvider.notifier);

    if (concepts.isEmpty) {
      return const _EmptyState(
        icon: Icons.lightbulb_outlined,
        message: 'No concepts available',
      );
    }

    return Column(
      children: [
        _SelectAllBar(
          selectedCount: selection.selectedConceptIds.length,
          totalCount: concepts.length,
          onSelectAll: () => notifier.selectAllConcepts(concepts),
          onClear: () => notifier.clearConcepts(),
        ),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: DesignTokens.space4),
            itemCount: concepts.length,
            itemBuilder: (context, index) {
              final concept = concepts[index];
              final isSelected =
                  selection.selectedConceptIds.contains(concept.id);
              final lesson = _findLessonForConcept(concept);

              return _ContentTile(
                title: concept.conceptText,
                subtitle: concept.exampleText ?? '',
                lessonTitle: lesson?.title,
                isSelected: isSelected,
                onTap: () => notifier.toggleConcept(concept.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Lesson? _findLessonForConcept(Concept concept) {
    for (final lesson in lessons) {
      if (lesson.concepts.any((c) => c.id == concept.id)) {
        return lesson;
      }
    }
    return null;
  }
}

/// Bar for select all / clear actions
class _SelectAllBar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  const _SelectAllBar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$selectedCount of $totalCount selected',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          if (selectedCount < totalCount)
            TextButton(
              onPressed: onSelectAll,
              child: const Text('Select All'),
            ),
          if (selectedCount > 0)
            TextButton(
              onPressed: onClear,
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

/// Individual content tile with checkbox
class _ContentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? lessonTitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContentTile({
    required this.title,
    required this.subtitle,
    this.lessonTitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.space2),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lessonTitle != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 12,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              lessonTitle!,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
