// PR-0b: real Manual Builder output (master plan v2.6 §14.9).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/widgets/lesson_builder_widget.dart';

void main() {
  Future<List<Map<String, dynamic>>?> buildMcq(
    WidgetTester tester, {
    required Map<String, String> options,
    String? correctLabel,
  }) async {
    List<Map<String, dynamic>>? captured;
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonBuilderWidget(
            initialContentTabIndex: 1,
            onCreateLesson:
                ({
                  required String title,
                  required String description,
                  required List<String> tags,
                  required List<Map<String, dynamic>> content,
                }) {
                  captured = content;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Question'),
      'Which is largest?',
    );
    for (final entry in options.entries) {
      await tester.enterText(
        find.widgetWithText(TextFormField, entry.key),
        entry.value,
      );
    }
    if (correctLabel != null) {
      final row = find.ancestor(
        of: find.widgetWithText(TextFormField, correctLabel),
        matching: find.byType(Row),
      );
      final radio = find
          .descendant(of: row, matching: find.byType(Radio<int>))
          .first;
      await tester.ensureVisible(radio);
      await tester.pumpAndSettle();
      await tester.tap(radio);
    }
    await tester.pump();
    await tester.ensureVisible(find.text('Add Question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Question'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Lesson Title'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lesson Title'),
      'Builder lesson',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description').first,
      'Compare numbers.',
    );
    final create = find.text('Create Lesson');
    if (create.evaluate().isNotEmpty) {
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
    }
    return captured;
  }

  testWidgets('no correct answer chosen: question is not added', (
    tester,
  ) async {
    final content = await buildMcq(
      tester,
      options: {'Option A (required)': '1', 'Option B (required)': '2'},
    );
    expect(content, isNull);
    expect(
      find.text('Choose the correct answer before adding the question.'),
      findsOneWidget,
    );
  });

  testWidgets('blank option does not shift the chosen correct answer', (
    tester,
  ) async {
    final content = await buildMcq(
      tester,
      options: {
        'Option A (required)': '1',
        'Option B (required)': '2',
        'Option D': '4',
      },
      correctLabel: 'Option D',
    );
    expect(content, isNotNull);
    final mcq = content!.single;
    expect(mcq['options'], ['1', '2', '4']);
    expect(mcq['correctIndex'], 2);
    expect((mcq['options'] as List)[mcq['correctIndex'] as int], '4');

    // The real Builder envelope imports cleanly through the shared preview.
    final preview = LessonImportService.preview({
      'lesson': {'title': 'Builder lesson', 'description': '', 'tags': []},
      'content': content,
    });
    expect(preview.issues, isEmpty);
    expect(preview.questionCount, 1);
  });
}
