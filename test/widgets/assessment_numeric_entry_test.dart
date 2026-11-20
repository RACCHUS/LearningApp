import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';

void main() {
  final now = DateTime(2026, 11, 20);

  AssessmentItem item({Map<String, dynamic>? scoring}) => AssessmentItem(
    id: 'num-1',
    interactionType: AssessmentInteractionType.numericEntry,
    prompt: r'What is $15\%$ of 80?',
    responseSpec: const {},
    scoringSpec: scoring ?? {'correct_value': 12},
    explanation: "Book answer: 12",
    difficulty: 'beginner',
    cognitiveLevel: 'application',
    createdAt: now,
    updatedAt: now,
  );

  Future<bool?> answer(WidgetTester tester, String text, {Map<String, dynamic>? scoring}) async {
    bool? result;
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssessmentItemRenderer(
              key: UniqueKey(),
              item: item(scoring: scoring),
              onAnswerSubmitted: (correct, score) => result = correct,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('numeric-entry-num-1')), text);
    await tester.pump();
    await tester.tap(find.text('Check Answer'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a number box replaces the "not supported" message', (tester) async {
    await answer(tester, '12');
    expect(find.textContaining('not yet supported'), findsNothing);
  });

  testWidgets('the right number is correct', (tester) async {
    expect(await answer(tester, '12'), isTrue);
  });

  testWidgets('equivalent forms count: 12.0 and grouped thousands', (tester) async {
    expect(await answer(tester, ' 12.0 '), isTrue);
    expect(
      await answer(tester, '1,200', scoring: {'correct_value': 1200}),
      isTrue,
    );
  });

  testWidgets('a wrong number or words are incorrect', (tester) async {
    expect(await answer(tester, '13'), isFalse);
    expect(await answer(tester, 'twelve'), isFalse);
  });

  testWidgets('tolerance is respected', (tester) async {
    final spec = {'correct_value': 3.14, 'tolerance': 0.005};
    expect(await answer(tester, '3.141', scoring: spec), isTrue);
    expect(await answer(tester, '3.2', scoring: spec), isFalse);
  });

  test('number parsing never reinterprets a decimal comma', () {
    expect(parseNumericAnswer('0,6'), isNull);
    expect(parseNumericAnswer('−12'), -12);
    expect(parseNumericAnswer('1,200.5'), 1200.5);
    expect(parseNumericAnswer('.5'), 0.5);
  });
}
