import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/widgets/lesson/rich_lesson_reader.dart';

void main() {
  final now = DateTime(2026, 11, 13);
  final lesson = Lesson(
    id: 'lesson-pos',
    title: 'Long lesson',
    tags: const [],
    createdAt: now,
    updatedAt: now,
    userId: 'u',
    terms: const [],
    questions: const [],
    concepts: const [],
  );
  final unified = UnifiedLesson(
    lesson: lesson,
    blocks: [
      for (var i = 1; i <= 30; i++)
        LessonBlock(
          id: 'blk-$i',
          lessonId: 'lesson-pos',
          sortOrder: i,
          blockType: LessonBlockType.markdown,
          content: {
            'body':
                '### Section $i\n'
                '${List.filled(12, 'Paragraph text for section $i.').join(' ')}',
          },
          createdAt: now,
          updatedAt: now,
        ),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    String? initial,
    required List<String> visible,
    required List<String> handled,
  }) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RichLessonReader(
          unifiedLesson: unified,
          initialBlockId: initial,
          onVisibleBlockChanged: visible.add,
          onInitialBlockHandled: () => handled.add('done'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reports the block at the top while scrolling', (tester) async {
    final visible = <String>[];
    await pump(tester, visible: visible, handled: []);
    expect(visible, isNotEmpty);
    expect(visible.last, 'blk-1');

    await tester.drag(find.byType(ListView), const Offset(0, -2500));
    await tester.pumpAndSettle();
    final id = int.parse(visible.last.split('-').last);
    expect(id, greaterThan(3), reason: 'scrolled well past the start');
  });

  testWidgets('scrolls back to a block far down the lesson', (tester) async {
    final visible = <String>[];
    final handled = <String>[];
    await pump(tester, initial: 'blk-22', visible: visible, handled: handled);
    expect(handled, ['done']);
    expect(find.textContaining('Section 22'), findsWidgets);
    expect(visible.last, anyOf('blk-21', 'blk-22'));
  });

  testWidgets('an unknown block is reported handled and ignored', (
    tester,
  ) async {
    final handled = <String>[];
    await pump(tester, initial: 'gone', visible: [], handled: handled);
    expect(handled, ['done']);
    expect(find.textContaining('Section 1'), findsWidgets);
  });
}
