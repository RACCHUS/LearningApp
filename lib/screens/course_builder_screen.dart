import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/course_builder_provider.dart';
import '../widgets/editors/lesson_picker_dialog.dart';
import '../widgets/editors/course_lesson_tile.dart';

/// Screen for creating and editing courses
class CourseBuilderScreen extends ConsumerStatefulWidget {
  final String? courseId;

  const CourseBuilderScreen({
    super.key,
    this.courseId,
  });

  @override
  ConsumerState<CourseBuilderScreen> createState() =>
      _CourseBuilderScreenState();
}

class _CourseBuilderScreenState extends ConsumerState<CourseBuilderScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(CourseBuilderState state) {
    if (_titleController.text != state.title) {
      _titleController.text = state.title;
    }
    if (_descriptionController.text != state.description) {
      _descriptionController.text = state.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(courseBuilderProvider(widget.courseId));
    final notifier = ref.read(courseBuilderProvider(widget.courseId).notifier);

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
          title: Text(state.isNewCourse ? 'Create Course' : 'Edit Course'),
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
                tooltip: 'Save course',
              ),
          ],
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error message
                  if (state.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
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

                  // Course details card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Course Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Course Title',
                                hintText: 'Enter a descriptive title',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.school_outlined),
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
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText: 'Describe what students will learn',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description_outlined),
                                alignLabelWithHint: true,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 3,
                              onChanged: notifier.setDescription,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Description is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Category and Difficulty row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: state.category,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: courseCategories.map((cat) {
                                      return DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        notifier.setCategory(value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: state.difficulty,
                                    decoration: const InputDecoration(
                                      labelText: 'Difficulty',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: courseDifficultyLevels.map((level) {
                                      return DropdownMenuItem(
                                        value: level,
                                        child: Text(
                                          level[0].toUpperCase() +
                                              level.substring(1),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        notifier.setDifficulty(value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Estimated hours and Public toggle
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: state.estimatedHours.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Estimated Hours',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.timer_outlined),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final hours = int.tryParse(value) ?? 0;
                                      notifier.setEstimatedHours(hours);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: SwitchListTile(
                                    title: const Text('Public'),
                                    subtitle: const Text('Visible to others'),
                                    value: state.isPublic,
                                    onChanged: notifier.setIsPublic,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Tags
                            Text(
                              'Tags',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...state.tags.map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    onDeleted: () => notifier.removeTag(tag),
                                  );
                                }),
                                SizedBox(
                                  width: 150,
                                  child: TextField(
                                    controller: _tagController,
                                    decoration: InputDecoration(
                                      hintText: 'Add tag',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: () {
                                          if (_tagController.text.isNotEmpty) {
                                            notifier.addTag(_tagController.text);
                                            _tagController.clear();
                                          }
                                        },
                                      ),
                                    ),
                                    onSubmitted: (value) {
                                      if (value.isNotEmpty) {
                                        notifier.addTag(value);
                                        _tagController.clear();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Lessons section
                  Row(
                    children: [
                      Text(
                        'Lessons',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${state.lessons.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () => _addLessons(notifier, state),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Lessons'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Lessons list
                  if (state.lessons.isEmpty)
                    EmptyCourseLessonsState(
                      onAddLessons: () => _addLessons(notifier, state),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.lessons.length,
                      onReorder: notifier.reorderLessons,
                      itemBuilder: (context, index) {
                        final item = state.lessons[index];
                        return CourseLessonTile(
                          key: ValueKey(item.lesson.id),
                          item: item,
                          index: index,
                          onRemove: () =>
                              notifier.removeLesson(item.lesson.id),
                          onToggleRequired: () =>
                              notifier.toggleLessonRequired(item.lesson.id),
                        );
                      },
                    ),
                ],
              ),
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

  Future<void> _addLessons(
    CourseBuilderNotifier notifier,
    CourseBuilderState state,
  ) async {
    final excludeIds = state.lessons.map((item) => item.lesson.id).toList();
    final selectedLessons = await LessonPickerDialog.show(
      context: context,
      courseId: state.courseId,
      excludeLessonIds: excludeIds,
    );

    if (selectedLessons != null && selectedLessons.isNotEmpty) {
      for (final lesson in selectedLessons) {
        notifier.addLesson(lesson);
      }
    }
  }

  Future<void> _save(CourseBuilderNotifier notifier) async {
    if (!_formKey.currentState!.validate()) return;

    final course = await notifier.save();
    if (course != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course "${course.title}" saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(course);
    }
  }
}
