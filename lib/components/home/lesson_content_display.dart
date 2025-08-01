import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/components/home/lessons_list.dart';

class LessonContentDisplay extends ConsumerWidget {
  final AsyncValue<List<BaseLesson>> lessonsAsync;

  const LessonContentDisplay({super.key, required this.lessonsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return lessonsAsync.when(
      data: (lessons) {
        return LessonsList(lessons: lessons);
      },
      loading: () => const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => SliverFillRemaining(
        child: Center(
          child: Text('Error loading lessons: $error'),
        ),
      ),
    );
  }
}
