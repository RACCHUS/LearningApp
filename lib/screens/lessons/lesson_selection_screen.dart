import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:go_router/go_router.dart';

final selectedLessonsProvider = StateProvider<List<String>>((ref) => []);

class LessonSelectionScreen extends ConsumerWidget {
  const LessonSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          return ListView(
            children: [
              ...lessons.map((lesson) => CheckboxListTile(
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
                        // Use GoRouter navigation
                        GoRouter.of(context).push('/study-set?ids=$idsParam');
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
