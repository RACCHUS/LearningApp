import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/lesson_screen.dart';

/// Manual lesson completion lives in the lesson screen's "More options"
/// menu (moved from the retired LessonCard, code-efficiency plan §14).
void main() {
  Future<void> pump(WidgetTester tester, {required double progress}) async {
    final lesson = FullLesson(
      lesson: Lesson(
        id: 'lesson-1',
        title: 'Photosynthesis',
        tags: const [],
        createdAt: DateTime(2026, 11, 17),
        updatedAt: DateTime(2026, 11, 17),
        userId: 'someone-else',
        visibility: 'public',
        terms: const [],
        questions: const [],
        concepts: const [],
      ),
      lessonContent: const [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        learnerIdProvider.overrideWith((ref) => 'learner-1'),
        lessonProvider('lesson-1').overrideWith((ref) => lesson),
        lessonProgressProvider('lesson-1').overrideWith((ref) => progress),
      ],
      child: const MaterialApp(home: LessonScreen(lessonId: 'lesson-1')),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lesson-more-menu')));
    await tester.pumpAndSettle();
  }

  testWidgets('an unfinished lesson offers "Mark as completed"', (tester) async {
    await pump(tester, progress: 0.5);
    expect(find.byKey(const Key('lesson-toggle-complete')), findsOneWidget);
    expect(find.text('Mark as completed'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('a completed lesson offers "Mark as incomplete"', (tester) async {
    await pump(tester, progress: 1.0);
    expect(find.text('Mark as incomplete'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
