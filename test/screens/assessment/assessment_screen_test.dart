import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/assessment.dart';
import 'package:learning_pwa/models/skill.dart';
import 'package:learning_pwa/providers/skill_stats_provider.dart';
import 'package:learning_pwa/screens/assessment/assessment_screen.dart';
import 'package:learning_pwa/services/skill_assessment_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

/// Records what the screen asks of the server; grading is whatever the test
/// says the server returned, so the screen can be checked for trusting it.
class _FakeService extends SkillAssessmentService {
  _FakeService({required this.questions, this.timeLimitMinutes = 10})
      : super(supabase: FakeSupabaseClient());

  final List<AssessmentQuestion> questions;
  final int timeLimitMinutes;
  Object? startError;
  Object? completeError;
  AssessmentResult Function(Map<String, int> answers)? grade;

  final Map<String, int> submitted = {};
  int completeCalls = 0;

  SkillAssessment get _assessment => SkillAssessment(
        id: 'assess-1',
        skillId: 'skill-1',
        title: 'Fractions check',
        timeLimitMinutes: timeLimitMinutes,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        questions: List.of(questions),
      );

  @override
  Future<SkillAssessment> getAssessmentWithQuestions(String assessmentId,
      {bool sanitizeForTaking = true}) async {
    if (startError != null) throw startError!;
    return _assessment;
  }

  @override
  Future<AssessmentAttempt> startAssessment(String assessmentId) async =>
      AssessmentAttempt(
        id: 'attempt-1',
        assessmentId: assessmentId,
        userId: 'user-1',
        startedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

  @override
  Future<void> submitAnswer(String attemptId, String questionId, int answerIndex) async {
    submitted[questionId] = answerIndex;
  }

  @override
  Future<AssessmentResult> completeAssessment(String attemptId,
      {bool wasOvertime = false}) async {
    completeCalls++;
    if (completeError != null) throw completeError!;
    return grade!(Map.of(submitted));
  }

  @override
  Future<List<UserSkillStats>> getUserSkillStats() async => const [];
}

AssessmentQuestion _q(String id, String text, List<String> options) => AssessmentQuestion(
      id: id,
      assessmentId: 'assess-1',
      questionText: text,
      options: options,
      createdAt: DateTime(2026),
    );

final _questions = [
  _q('q1', 'Q1: 1/2 + 1/4', ['3/4', '2/6']),
  _q('q2', 'Q2: 2/3 of 9', ['6', '3']),
];

/// What a correct learner picks for each question text (questions are shuffled).
const _rightOption = {'Q1: 1/2 + 1/4': '3/4', 'Q2: 2/3 of 9': '6'};

AssessmentResult _result(
  _FakeService service, {
  required int score,
  required int correct,
  required bool passed,
  int previousLevel = 10,
  int newLevel = 10,
}) =>
    AssessmentResult(
      attempt: AssessmentAttempt(
        id: 'attempt-1',
        assessmentId: 'assess-1',
        userId: 'user-1',
        startedAt: DateTime(2026),
        createdAt: DateTime(2026),
        score: score,
        correctCount: correct,
        totalQuestions: _questions.length,
      ),
      assessment: service._assessment,
      previousLevel: previousLevel,
      newLevel: newLevel,
      passed: passed,
      questionResults: [
        for (final q in _questions)
          QuestionResult(
            question: AssessmentQuestion(
              id: q.id,
              assessmentId: q.assessmentId,
              questionText: q.questionText,
              options: q.options,
              correctAnswer: 0,
              explanation: 'Because ${q.options[0]}.',
              createdAt: q.createdAt,
            ),
            userAnswer: service.submitted[q.id],
            isCorrect: service.submitted[q.id] == 0,
          ),
      ],
    );

Future<void> _pumpScreen(WidgetTester tester, _FakeService service) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('HOME')),
        routes: [
          GoRoute(
            path: 'assess',
            builder: (_, __) => const AssessmentScreen(assessmentId: 'assess-1'),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [skillAssessmentServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/home/assess');
  await tester.pump(); // start the attempt (post-frame callback)
  await tester.pump(const Duration(milliseconds: 600)); // finish the page transition
}

Future<String> _answerCurrent(WidgetTester tester,
    {bool correctly = true, Set<String> answerWrong = const {}}) async {
  final questionText = _rightOption.keys.firstWhere((t) => find.text(t).evaluate().isNotEmpty);
  if (answerWrong.contains(questionText)) correctly = false;
  final right = _rightOption[questionText]!;
  final options = _questions.firstWhere((q) => q.questionText == questionText).options;
  await tester.tap(find.text(correctly ? right : options.firstWhere((o) => o != right)));
  await tester.pump();
  return questionText;
}

FilledButton _button(WidgetTester tester, String label) => tester.widget<FilledButton>(
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );

void main() {
  testWidgets('Next and Submit stay disabled until the learner has answered', (tester) async {
    final service = _FakeService(questions: _questions);
    await _pumpScreen(tester, service);

    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(_button(tester, 'Next').onPressed, isNull);

    await _answerCurrent(tester);
    expect(_button(tester, 'Next').onPressed, isNotNull);
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(_button(tester, 'Submit').onPressed, isNull);
    await _answerCurrent(tester);
    expect(_button(tester, 'Submit').onPressed, isNotNull);

    // Previous keeps the earlier answer.
    await tester.tap(find.text('Previous'));
    await tester.pump();
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(_button(tester, 'Next').onPressed, isNotNull);
  });

  testWidgets('submitting sends each chosen answer once and shows the server grade', (tester) async {
    final service = _FakeService(questions: _questions);
    // The server decides: 50%, not passed, even though the client might count otherwise.
    service.grade = (_) => _result(service, score: 50, correct: 1, passed: false);
    await _pumpScreen(tester, service);

    // Q1 right (option 0), Q2 wrong (option 1), whatever order they appear in.
    const wrong = {'Q2: 2/3 of 9'};
    await _answerCurrent(tester, answerWrong: wrong);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await _answerCurrent(tester, answerWrong: wrong);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Assessment?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pump();
    await tester.pump();

    expect(service.completeCalls, 1);
    expect(service.submitted, {'q1': 0, 'q2': 1});
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Keep practicing!'), findsOneWidget);
    expect(find.text('1/2 correct'), findsOneWidget);
    expect(find.text('Passed!'), findsNothing);
  });

  testWidgets('choosing Review in the submit dialog sends nothing', (tester) async {
    final service = _FakeService(questions: [_questions.first]);
    service.grade = (_) => _result(service, score: 100, correct: 1, passed: true);
    await _pumpScreen(tester, service);

    await _answerCurrent(tester);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(service.completeCalls, 0);
    expect(service.submitted, isEmpty);
    expect(find.text('Question 1 of 1'), findsOneWidget);
  });

  testWidgets('a failed start shows an error with a way back', (tester) async {
    final service = _FakeService(questions: _questions)
      ..startError = Exception('User must be authenticated');
    await _pumpScreen(tester, service);

    expect(find.textContaining('User must be authenticated'), findsOneWidget);
    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('a failed submit tells the learner and keeps their answers', (tester) async {
    final service = _FakeService(questions: [_questions.first])
      ..completeError = Exception('grading unavailable');
    await _pumpScreen(tester, service);

    await _answerCurrent(tester);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400)); // dialog finishes closing
    expect(find.textContaining('could not be submitted'), findsOneWidget);
    expect(service.completeCalls, 1);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(_button(tester, 'Submit').onPressed, isNotNull, reason: 'learner can retry');
  });

  testWidgets('closing asks before abandoning; Continue keeps the attempt', (tester) async {
    final service = _FakeService(questions: _questions);
    await _pumpScreen(tester, service);
    await _answerCurrent(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Abandon Assessment?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(_button(tester, 'Next').onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(service.completeCalls, 0);
  });

  testWidgets('running past the time limit shows the overtime notice', (tester) async {
    final service = _FakeService(questions: _questions, timeLimitMinutes: 1);
    await _pumpScreen(tester, service);

    expect(find.textContaining("Time's up"), findsNothing);
    await tester.pump(const Duration(seconds: 61));
    expect(find.textContaining("Time's up"), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose the periodic timer
  });

  testWidgets('result review marks the correct option and shows the explanation', (tester) async {
    final service = _FakeService(questions: [_questions.first]);
    service.grade = (_) => _result(service, score: 0, correct: 0, passed: false);
    await _pumpScreen(tester, service);

    await _answerCurrent(tester, correctly: false);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
    await tester.pump();
    await tester.pump();

    expect(find.text('Keep practicing!'), findsOneWidget);
    final reviewItem = find.text('Question 1');
    await tester.scrollUntilVisible(reviewItem, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Incorrect'), findsWidgets);
    await tester.tap(reviewItem);
    await tester.pumpAndSettle();
    expect(find.text('Q1: 1/2 + 1/4'), findsOneWidget);
    expect(find.text('Because 3/4.'), findsOneWidget);
  });
}
