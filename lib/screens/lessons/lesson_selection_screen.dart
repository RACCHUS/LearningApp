

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:go_router/go_router.dart';

class TagFilter extends StatefulWidget {
  final List<Lesson> lessons;
  final void Function(String tag) onTagSelected;
  final String? selectedTag;
  const TagFilter({super.key, required this.lessons, required this.onTagSelected, this.selectedTag});
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
        ...allTags.map((tag) => ChoiceChip(
              label: Text(tag),
              selected: widget.selectedTag == tag,
              onSelected: (_) => widget.onTagSelected(tag),
            )),
      ],
    );
  }
}


final selectedLessonsProvider = StateProvider<List<String>>((ref) => []);

class LessonSelectionScreen extends ConsumerStatefulWidget {
  const LessonSelectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LessonSelectionScreen> createState() => _LessonSelectionScreenState();
}

class _LessonSelectionScreenState extends ConsumerState<LessonSelectionScreen> {
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Lessons for Study Set')),
      body: FutureBuilder<List<Lesson>>(
        future: LessonService().getLessonsForUser(''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No lessons found.'));
          }
          final lessons = snapshot.data!;
          final selected = ref.watch(selectedLessonsProvider);
          final filtered = _selectedTag == null || _selectedTag!.isEmpty
              ? lessons
              : lessons.where((l) => l.tags.contains(_selectedTag)).toList();
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: TagFilter(
                  lessons: lessons,
                  selectedTag: _selectedTag,
                  onTagSelected: (tag) {
                    setState(() => _selectedTag = tag.isEmpty ? null : tag);
                  },
                ),
              ),
              ...filtered.map((lesson) => CheckboxListTile(
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
                      ref.read(selectedLessonsProvider.notifier).state = updated;
                    },
                  )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        final idsParam = selected.join(',');
                        context.push('/study-set?ids=$idsParam');
                      },
                child: const Text('Create Study Set'),
              ),
            ],
          );
        },
      ),
    );
  }
}
