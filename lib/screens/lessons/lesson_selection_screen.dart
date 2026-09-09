import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/providers/study_set_provider.dart';
import 'package:go_router/go_router.dart';

class TagFilter extends StatefulWidget {
  final List<Lesson> lessons;
  final void Function(String tag) onTagSelected;
  final String? selectedTag;
  const TagFilter({
    super.key,
    required this.lessons,
    required this.onTagSelected,
    this.selectedTag,
  });
  @override
  State<TagFilter> createState() => _TagFilterState();
}

class _TagFilterState extends State<TagFilter> {
  late List<String> allTags;
  @override
  void initState() {
    super.initState();
    allTags = widget.lessons.expand((l) => l.tags).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (allTags.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: widget.selectedTag == null,
          onSelected: (_) => widget.onTagSelected(''),
        ),
        ...allTags.map(
          (tag) => ChoiceChip(
            label: Text(tag),
            selected: widget.selectedTag == tag,
            onSelected: (_) => widget.onTagSelected(tag),
          ),
        ),
      ],
    );
  }
}

final selectedLessonsProvider = StateProvider<List<String>>((ref) => []);

class LessonSelectionScreen extends ConsumerStatefulWidget {
  const LessonSelectionScreen({super.key});

  @override
  ConsumerState<LessonSelectionScreen> createState() =>
      _LessonSelectionScreenState();
}

class _LessonSelectionScreenState extends ConsumerState<LessonSelectionScreen> {
  String? _selectedTag;
  bool _isSaving = false;

  Future<void> _showSaveDialog(List<String> selectedIds) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Study Set'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'My Study Set',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe your study set',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a name')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _isSaving = true);

      try {
        await ref.read(studySetProvider.notifier).createStudySet(
              title: nameController.text.trim(),
              description: descriptionController.text.trim().isNotEmpty
                  ? descriptionController.text.trim()
                  : null,
              lessonIds: selectedIds,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Study set saved!')),
          );
          // Navigate to study set
          final idsParam = selectedIds.join(',');
          context.push('/study-set?ids=$idsParam');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Lessons for Study Set')),
      body: FutureBuilder<List<Lesson>>(
        future: LessonService().getLessonsForUser(''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load lessons', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No lessons found.'));
          }
          final lessons = snapshot.data!;
          final selected = ref.watch(selectedLessonsProvider);
          final filtered = _selectedTag == null || _selectedTag!.isEmpty
              ? lessons
              : lessons.where((l) => l.tags.contains(_selectedTag)).toList();

          return Column(
            children: [
              // Tag filter
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: TagFilter(
                  lessons: lessons,
                  selectedTag: _selectedTag,
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag.isEmpty ? null : tag);
                  },
                ),
              ),

              // Selected count
              if (selected.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        '${selected.length} lesson${selected.length == 1 ? '' : 's'} selected',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          ref.read(selectedLessonsProvider.notifier).state = [];
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),

              // Lessons list
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final lesson = filtered[index];
                    return CheckboxListTile(
                      title: Text(lesson.title),
                      subtitle: Text(lesson.description ?? ''),
                      value: selected.contains(lesson.id),
                      onChanged: (checked) {
                        final updated = [...selected];
                        if (checked == true) {
                          updated.add(lesson.id);
                        } else {
                          updated.remove(lesson.id);
                        }
                        ref.read(selectedLessonsProvider.notifier).state =
                            updated;
                      },
                    );
                  },
                ),
              ),

              // Bottom action bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      // Study Now (ephemeral)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selected.isEmpty || _isSaving
                              ? null
                              : () {
                                  final idsParam = selected.join(',');
                                  context.push('/study-set?ids=$idsParam');
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Study Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Save & Study
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: selected.isEmpty || _isSaving
                              ? null
                              : () => _showSaveDialog(selected),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save & Study'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
