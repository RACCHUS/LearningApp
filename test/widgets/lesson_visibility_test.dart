import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/lesson_screen.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import '../test_helpers/fake_supabase_client.dart';

class _FakeCrudService extends LessonCrudService {
  _FakeCrudService() : super(supabase: FakeSupabaseClient());
  String? lastUpdatedVisibility;
  bool shouldFail = false;

  @override
  Future<Lesson> setVisibility(String lessonId, String visibility) async {
    if (shouldFail) {
      throw Exception('Network error');
    }
    lastUpdatedVisibility = visibility;
    return Lesson(
      id: lessonId,
      title: 'Test Lesson',
      tags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      userId: 'owner-1',
      visibility: visibility,
      terms: const [],
      questions: const [],
      concepts: const [],
    );
  }
}

void main() {
  testWidgets('owner sees private badge, publish action, and no share button',
      (tester) async {
    final crudService = _FakeCrudService();
    final privateLesson = FullLesson(
      lesson: Lesson(
        id: 'lesson-1',
        title: 'Secret Notes',
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'owner-1',
        visibility: 'private',
        terms: const [],
        questions: const [],
        concepts: const [],
      ),
      lessonContent: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerIdProvider.overrideWith((ref) => 'owner-1'),
          lessonProvider('lesson-1')
              .overrideWith((ref) => privateLesson),
          lessonCrudServiceProvider.overrideWith((ref) => crudService),
        ],
        child: const MaterialApp(
          home: LessonScreen(lessonId: 'lesson-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify private badge is shown
    expect(find.byKey(const Key('lesson_visibility_badge')), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);

    // Verify publish action is shown
    expect(find.byKey(const Key('lesson_visibility_action')), findsOneWidget);
    expect(find.byTooltip('Publish lesson'), findsOneWidget);

    // Verify share button is NOT offered for private lesson
    expect(find.byTooltip('Share lesson link'), findsNothing);

    // Tap publish
    await tester.tap(find.byKey(const Key('lesson_visibility_action')));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Publish Lesson'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);

    // Confirm publish
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(crudService.lastUpdatedVisibility, 'public');
  });

  testWidgets('failed publish keeps displayed state and displays error',
      (tester) async {
    final crudService = _FakeCrudService()..shouldFail = true;
    final privateLesson = FullLesson(
      lesson: Lesson(
        id: 'lesson-1',
        title: 'Secret Notes',
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'owner-1',
        visibility: 'private',
        terms: const [],
        questions: const [],
        concepts: const [],
      ),
      lessonContent: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerIdProvider.overrideWith((ref) => 'owner-1'),
          lessonProvider('lesson-1')
              .overrideWith((ref) => privateLesson),
          lessonCrudServiceProvider.overrideWith((ref) => crudService),
        ],
        child: const MaterialApp(
          home: LessonScreen(lessonId: 'lesson-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lesson_visibility_action')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    // Verify error snackbar shown
    expect(find.textContaining('Failed to update visibility'), findsOneWidget);
    // Displayed state remains private
    expect(find.text('Private'), findsOneWidget);
  });

  testWidgets('non-owner sees no visibility badge or action', (tester) async {
    final publicLesson = FullLesson(
      lesson: Lesson(
        id: 'lesson-2',
        title: 'Public Catalog Lesson',
        tags: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'other-user',
        visibility: 'public',
        terms: const [],
        questions: const [],
        concepts: const [],
      ),
      lessonContent: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnerIdProvider.overrideWith((ref) => 'reader-user'),
          lessonProvider('lesson-2')
              .overrideWith((ref) => publicLesson),
        ],
        child: const MaterialApp(
          home: LessonScreen(lessonId: 'lesson-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Non-owner should not see visibility badge or action
    expect(find.byKey(const Key('lesson_visibility_badge')), findsNothing);
    expect(find.byKey(const Key('lesson_visibility_action')), findsNothing);

    // Public lesson should show share button
    expect(find.byTooltip('Share lesson link'), findsOneWidget);
  });
}
