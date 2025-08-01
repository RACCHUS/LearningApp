import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';

class LessonScreen extends ConsumerWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonProvider(lessonId));

    return Scaffold(
      appBar: AppBar(
        title: lessonAsync.when(
          data: (data) => Text(data.lesson.title),
          loading: () => const Text('Loading...'),
          error: (error, stackTrace) => const Text('Error'),
        ),
      ),
      body: lessonAsync.when(
        data: (data) {
          return ListView.builder(
            itemCount: data.lessonContent.length,
            itemBuilder: (context, index) {
              final content = data.lessonContent[index];
              return ListTile(
                title: Text(content.type),
                subtitle: Text(content.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}