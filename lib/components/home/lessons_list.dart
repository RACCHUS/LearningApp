import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/base_lesson.dart';

class LessonsList extends StatelessWidget {
  final List<BaseLesson> lessons;

  const LessonsList({super.key, required this.lessons});

  @override
  Widget build(BuildContext context) {
    if (lessons.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('No lessons found'),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final lesson = lessons[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(lesson.title),
                subtitle: Text(lesson.description ?? ''),
                onTap: () {
                  context.go('/lesson/${lesson.id}');
                },
              ),
            );
          },
          childCount: lessons.length,
        ),
      ),
    );
  }
}