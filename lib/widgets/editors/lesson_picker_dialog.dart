import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/lesson.dart';
import '../../providers/course_builder_provider.dart';

/// Dialog for selecting lessons to add to a course
class LessonPickerDialog extends ConsumerStatefulWidget {
  final String? courseId;
  final List<String> excludeLessonIds;

  const LessonPickerDialog({
    super.key,
    this.courseId,
    this.excludeLessonIds = const [],
  });

  @override
  ConsumerState<LessonPickerDialog> createState() => _LessonPickerDialogState();

  /// Show the lesson picker dialog and return selected lessons
  static Future<List<Lesson>?> show({
    required BuildContext context,
    String? courseId,
    List<String> excludeLessonIds = const [],
  }) {
    return showDialog<List<Lesson>>(
      context: context,
      builder: (context) => LessonPickerDialog(
        courseId: courseId,
        excludeLessonIds: excludeLessonIds,
      ),
    );
  }
}

class _LessonPickerDialogState extends ConsumerState<LessonPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedLessonIds = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessonsAsync = ref.watch(availableLessonsProvider(widget.courseId));

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.library_add_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Lessons',
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
              const SizedBox(height: 16),

              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search lessons...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
              ),
              const SizedBox(height: 8),

              // Create new lesson button
              OutlinedButton.icon(
                onPressed: () async {
                  // Navigate to lesson editor and wait for result
                  await context.push('/lesson-editor');
                  // Refresh the lessons list
                  ref.invalidate(availableLessonsProvider(widget.courseId));
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New Lesson'),
              ),
              const SizedBox(height: 16),

              // Selection count
              if (_selectedLessonIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedLessonIds.length} lesson${_selectedLessonIds.length == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedLessonIds.clear());
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // Lesson list
              Expanded(
                child: lessonsAsync.when(
                  data: (lessons) {
                    // Filter out excluded lessons and apply search
                    final filteredLessons = lessons
                        .where((lesson) =>
                            !widget.excludeLessonIds.contains(lesson.id))
                        .where((lesson) =>
                            _searchQuery.isEmpty ||
                            lesson.title.toLowerCase().contains(_searchQuery) ||
                            (lesson.description
                                    ?.toLowerCase()
                                    .contains(_searchQuery) ??
                                false))
                        .toList();

                    if (filteredLessons.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.library_books_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No lessons match your search'
                                  : 'No lessons available',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Create some lessons first',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filteredLessons.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final lesson = filteredLessons[index];
                        final isSelected =
                            _selectedLessonIds.contains(lesson.id);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedLessonIds.add(lesson.id);
                              } else {
                                _selectedLessonIds.remove(lesson.id);
                              }
                            });
                          },
                          title: Text(lesson.title),
                          subtitle: lesson.description != null
                              ? Text(
                                  lesson.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          secondary: _buildLessonStats(lesson, theme),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load lessons',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                      onPressed: _selectedLessonIds.isEmpty
                          ? null
                          : () => _confirmSelection(lessonsAsync),
                      icon: const Icon(Icons.add),
                      label: Text(
                        _selectedLessonIds.isEmpty
                            ? 'Add Lessons'
                            : 'Add ${_selectedLessonIds.length}',
                      ),
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

  Widget _buildLessonStats(Lesson lesson, ThemeData theme) {
    final stats = <String>[];
    if (lesson.terms.isNotEmpty) {
      stats.add('${lesson.terms.length} terms');
    }
    if (lesson.questions.isNotEmpty) {
      stats.add('${lesson.questions.length} questions');
    }
    if (lesson.concepts.isNotEmpty) {
      stats.add('${lesson.concepts.length} concepts');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stats.isEmpty ? 'Empty' : stats.join(', '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _confirmSelection(AsyncValue<List<Lesson>> lessonsAsync) {
    final allLessons = lessonsAsync.valueOrNull ?? [];
    final selectedLessons = allLessons
        .where((lesson) => _selectedLessonIds.contains(lesson.id))
        .toList();
    Navigator.of(context).pop(selectedLessons);
  }
}
