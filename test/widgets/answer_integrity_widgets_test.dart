// PR-0a renderer/scorer safety (master plan v2.6 §14.8, Appendix H.3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/session_result.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/screens/study/session_results_screen.dart';
import 'package:learning_pwa/widgets/lesson_content_renderer.dart';
import 'package:learning_pwa/widgets/question_widgets/unscorable_answer_notice.dart';

QuestionContent _q(List<String> options, int correct, {String? type}) =>
    QuestionContent(
      id: 'q',
      lessonId: 'l',
      order: 0,
      questionText: 'Is the sky blue?',
      options: options,
      correctAnswer: correct,
      questionType: type,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget _host(Widget child) => ProviderScope(
  overrides: [
    canSpeakProvider.overrideWithValue(false),
    canListenProvider.overrideWithValue(false),
    readAloudOffProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _answerTrueFalse(WidgetTester tester, String choice) async {
  await tester.tap(find.widgetWithText(ChoiceChip, choice));
  await tester.pump();
  await tester.tap(find.text('Submit'));
  await tester.pump();
}

void main() {
  group('True/false uses option labels, not index position', () {
    testWidgets('[True, False] key 0: "True" is correct', (tester) async {
      await tester.pumpWidget(
        _host(
          LessonContentRenderer(
            content: _q(['True', 'False'], 0, type: 'true_false'),
            onNext: () {},
          ),
        ),
      );
      await _answerTrueFalse(tester, 'True');
      expect(find.textContaining('Correct'), findsWidgets);
      expect(find.textContaining('Incorrect'), findsNothing);
    });

    testWidgets('[False, True] key 0: "False" is correct', (tester) async {
      await tester.pumpWidget(
        _host(
          LessonContentRenderer(
            content: _q(['False', 'True'], 0, type: 'true_false'),
            onNext: () {},
          ),
        ),
      );
      await _answerTrueFalse(tester, 'False');
      expect(find.textContaining('Incorrect'), findsNothing);
    });

    testWidgets('[True, False] key 0: "False" is incorrect', (tester) async {
      await tester.pumpWidget(
        _host(
          LessonContentRenderer(
            content: _q(['True', 'False'], 0, type: 'true_false'),
            onNext: () {},
          ),
        ),
      );
      await _answerTrueFalse(tester, 'False');
      expect(find.textContaining('Incorrect'), findsOneWidget);
    });

    testWidgets('unknown labels are not scored', (tester) async {
      await tester.pumpWidget(
        _host(
          LessonContentRenderer(
            content: _q(['True', 'True'], 0, type: 'true_false'),
            onNext: () {},
          ),
        ),
      );
      await _answerTrueFalse(tester, 'True');
      expect(find.byType(UnscorableAnswerNotice), findsOneWidget);
      expect(find.textContaining('Correct'), findsNothing);
    });
  });

  testWidgets('MCQ with an unscorable stored key shows a notice, not a guess', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        LessonContentRenderer(
          content: _q(['Paris', 'Rome', 'Berlin'], AnswerKey.unscorableIndex),
          onNext: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('Paris'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();
    expect(find.byType(UnscorableAnswerNotice), findsOneWidget);
    expect(find.textContaining('Incorrect'), findsNothing);
  });

  testWidgets('results screen survives invalid selected and correct indices', (
    tester,
  ) async {
    Question question(int correct) => Question(
      id: 'q$correct',
      questionText: 'Question $correct',
      options: const ['A1', 'B1'],
      correctAnswer: correct,
      type: 'mcq',
      createdBy: 'u',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SessionResultsScreen(
          result: SessionResult(
            mode: SessionMode.mcq,
            correct: 0,
            total: 2,
            missedQuestions: [
              MissedQuestion(question: question(7), selectedAnswer: 9),
              MissedQuestion(question: question(1), selectedAnswer: 0),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Correct: B1'), 200);
    expect(
      find.text('No correct answer is saved for this question.'),
      findsOneWidget,
    );
    expect(find.text('Your answer: not recorded'), findsOneWidget);
    expect(find.text('Correct: B1'), findsOneWidget);
    expect(find.text('Your answer: A1'), findsOneWidget);
  });
}
