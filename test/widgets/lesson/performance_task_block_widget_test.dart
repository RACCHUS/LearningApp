import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/lesson_block_renderer.dart';
import 'package:learning_pwa/widgets/lesson/blocks/performance_task_block_widget.dart';

// Ingestion plan v1.2 §8.8: a hands-on task checked against a published
// rubric, always labelled as self-checked and never sent anywhere.
void main() {
  final now = DateTime(2026, 11, 24);

  LessonBlock block(Map<String, dynamic> content, {String type = 'performance_task'}) =>
      LessonBlock(
        id: 'pt-1',
        lessonId: 'lesson-1',
        sortOrder: 1,
        blockType: LessonBlockType.fromString(type),
        content: content,
        createdAt: now,
        updatedAt: now,
      );

  final task = {
    'task_id': 'excel-budget-workbook-v1',
    'title': 'Build and check a budget workbook',
    'verification': 'self_check',
    'body': 'Fallback: build the workbook and check it against the rubric.',
    'brief': 'Build the **Budget** sheet in Excel.',
    'deliverable': 'A saved workbook with a SUM total.',
    'criteria': [
      {'id': 'total', 'text': 'C10 holds =SUM(C2:C9)', 'how_to_check': 'Click C10 and read the formula bar.'},
      {'id': 'value', 'text': 'C10 shows 440'},
      {'id': 'blank', 'text': '   '},
    ],
    'exemplar': 'Exemplar: C10 contains `=SUM(C2:C9)` and shows **440**.',
  };

  Future<void> pump(WidgetTester tester, LessonBlock b) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: LessonBlockRenderer(block: b))),
    ));
    await tester.pumpAndSettle();
  }

  test('performance_task round-trips through the block type', () {
    expect(LessonBlockType.fromString('performance_task'), LessonBlockType.performanceTask);
    expect(LessonBlockType.performanceTask.toDbString(), 'performance_task');
  });

  test('blank criteria are ignored', () {
    final criteria = PerformanceTaskBlockWidget.criteriaOf(block(task));
    expect(criteria.map((c) => c.id), ['total', 'value']);
    expect(criteria.first.howToCheck, 'Click C10 and read the formula bar.');
    expect(criteria.last.howToCheck, isNull);
  });

  testWidgets('shows the brief, rubric, exemplar and the self-check label', (tester) async {
    await pump(tester, block(task));
    expect(find.byKey(const Key('performance-task')), findsOneWidget);
    expect(find.text('Build and check a budget workbook'), findsOneWidget);
    expect(find.text('C10 holds =SUM(C2:C9)'), findsOneWidget);
    expect(find.text('Click C10 and read the formula bar.'), findsOneWidget);
    expect(find.text(performanceTaskSelfCheckNote), findsOneWidget);
    expect(find.text('0 of 2 criteria checked'), findsOneWidget);
    expect(find.textContaining('Fallback:'), findsNothing);
  });

  testWidgets('ticking every criterion says the work meets the rubric', (tester) async {
    await pump(tester, block(task));
    await tester.tap(find.byKey(const Key('criterion-total')));
    await tester.pump();
    expect(find.text('1 of 2 criteria checked'), findsOneWidget);
    await tester.tap(find.byKey(const Key('criterion-value')));
    await tester.pump();
    expect(find.text('Your work meets every criterion in this rubric.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('criterion-value')));
    await tester.pump();
    expect(find.text('1 of 2 criteria checked'), findsOneWidget);
    // The label never changes to a verified claim.
    expect(find.text(performanceTaskSelfCheckNote), findsOneWidget);
  });

  testWidgets('the exemplar is hidden until opened', (tester) async {
    await pump(tester, block(task));
    expect(find.textContaining('Exemplar:'), findsNothing);
    await tester.tap(find.text('See an example that meets the rubric'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Exemplar:'), findsWidgets);
  });

  testWidgets('a task without a usable rubric falls back to its body', (tester) async {
    final broken = Map<String, dynamic>.from(task)..['criteria'] = [{'text': 'only one'}];
    await pump(tester, block(broken));
    expect(find.byKey(const Key('performance-task')), findsNothing);
    expect(find.textContaining('Fallback:'), findsOneWidget);
  });

  testWidgets('an older client reading it as markdown still shows the body', (tester) async {
    // Older apps map unknown block types to markdown and read `body`.
    await pump(tester, block(task, type: 'some_future_block'));
    expect(find.textContaining('Fallback:'), findsOneWidget);
  });
}
