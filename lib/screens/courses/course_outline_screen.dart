import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/next_action_provider.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

final courseOutlineProvider =
    FutureProvider.family<CourseWithContent, String>((ref, courseId) async {
  return ref.watch(courseServiceProvider).getCourseWithContent(courseId);
});

/// The single secondary destination from Learn.
///
/// Every unlocked lesson is directly tappable — this is what satisfies the
/// Direct Access Rule. The percentage shown is **structural only**; retrieval
/// strength never appears here.
class CourseOutlineScreen extends ConsumerWidget {
  final String courseId;

  const CourseOutlineScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(courseOutlineProvider(courseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Course outline')),
      body: outline.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _OutlineError(
          onRetry: () => ref.invalidate(courseOutlineProvider(courseId)),
        ),
        data: (content) => _Outline(content: content),
      ),
    );
  }
}

class _Outline extends StatelessWidget {
  final CourseWithContent content;

  const _Outline({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessons = content.orderedLessons;

    if (lessons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content.course.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: DesignTokens.space3),
            const Text('This course has no lessons yet.'),
            const SizedBox(height: DesignTokens.space4),
            OutlinedButton(
              onPressed: () => context.go('/library'),
              child: const Text('Browse Library'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      children: [
        Text(content.course.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: DesignTokens.space1),
        Text(
          '${lessons.length} lessons',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: DesignTokens.space5),
        for (final lesson in lessons)
          ListTile(
            key: Key('outline-lesson-${lesson.id}'),
            leading: const Icon(Icons.circle_outlined, size: 18),
            title: Text(lesson.title),
            onTap: () => context.push('/lesson/${lesson.id}'),
          ),
      ],
    );
  }
}

class _OutlineError extends StatelessWidget {
  final VoidCallback onRetry;
  const _OutlineError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load this course.'),
            const SizedBox(height: DesignTokens.space4),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: DesignTokens.space2),
            TextButton(
              onPressed: () => context.go('/library'),
              child: const Text('Go to Library'),
            ),
          ],
        ),
      ),
    );
  }
}
