import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/providers/assessment_engine_provider.dart';
import 'package:learning_pwa/services/assessment/exam_evaluation_service.dart';
import 'package:learning_pwa/services/assessment/exam_practice_elapsed_clock.dart';

class _ManualPracticeClock implements ExamPracticeElapsedClock {
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  Duration get elapsed => _elapsed;

  @override
  void start() => _running = true;

  @override
  void stop() => _running = false;

  @override
  void reset() => _elapsed = Duration.zero;

  void advance(Duration duration) {
    if (_running) _elapsed += duration;
  }
}

MockExamSession _session({int limitSeconds = 60, String id = 'practice-1'}) {
  final now = DateTime.utc(2026, 10, 21);
  return MockExamSession(
    id: id,
    blueprint: const MockExamBlueprint(
      targetVersionId: 'synthetic-version',
      examCode: 'PRACTICE',
      title: 'Local practice, not an official exam',
      domainWeights: [
        DomainWeightConstraint(
          domainId: 'domain-1',
          domainCode: '1',
          domainTitle: 'Synthetic domain',
          weight: 1,
        ),
      ],
    ),
    items: [
      AssessmentItem(
        id: 'item-1',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Synthetic test question',
        responseSpec: const {
          'options': ['Option A', 'Option B'],
        },
        scoringSpec: const {'correct_index': 0},
        createdAt: now,
        updatedAt: now,
      ),
    ],
    itemDomainMap: const {'item-1': '1'},
    startedAt: now,
    timeLimit: Duration(seconds: limitSeconds),
  );
}

void main() {
  test('delayed clock is reconciled before an answer or flag is accepted', () {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session(limitSeconds: 30));
    notifier.recordResponse('item-1', 0);
    clock.advance(const Duration(seconds: 31));

    // Even if a suspended browser did not deliver its periodic timer,
    // the deadline is checked synchronously before the user can edit.
    notifier.recordResponse('item-1', 1);
    notifier.toggleFlag('item-1');

    expect(notifier.state!.status, ExamSessionStatus.expired);
    expect(notifier.state!.elapsedSeconds, 31);
    expect(notifier.state!.userResponses['item-1'], 0);
    expect(notifier.state!.flaggedItemIds, isEmpty);
    expect(notifier.state!.remainingDuration, Duration.zero);
  });

  test('pause excludes inactive time and resume preserves original start', () {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session());
    final startedAt = notifier.state!.startedAt;
    clock.advance(const Duration(seconds: 12));
    notifier.pauseSession();

    expect(notifier.state!.status, ExamSessionStatus.paused);
    expect(notifier.state!.elapsedSeconds, 12);
    clock.advance(const Duration(seconds: 90));
    notifier.recordResponse('item-1', 0);
    expect(notifier.state!.userResponses, isEmpty);

    notifier.resumeSession();
    expect(notifier.state!.startedAt, startedAt);
    clock.advance(const Duration(seconds: 9));
    notifier.recordResponse('item-1', 0);
    expect(notifier.state!.elapsedSeconds, 21);
    expect(notifier.state!.remainingDuration, const Duration(seconds: 39));
    expect(notifier.state!.userResponses['item-1'], 0);
  });

  test('late submission stays expired and may be scored only once', () {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session(limitSeconds: 20));
    clock.advance(const Duration(seconds: 26));
    final report = notifier.submitExam();

    expect(report, isNotNull);
    expect(report!.durationTaken, const Duration(seconds: 26));
    expect(notifier.state!.status, ExamSessionStatus.expired);
    expect(notifier.submitExam(), isNull);
    notifier.recordResponse('item-1', 0);
    expect(notifier.state!.userResponses, isEmpty);
  });

  test('manual submission finishes once, fresh session resets clock', () {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session());
    clock.advance(const Duration(seconds: 8));
    notifier.recordResponse('item-1', 0);
    expect(notifier.submitExam(), isNotNull);
    expect(notifier.state!.status, ExamSessionStatus.completed);
    expect(notifier.submitExam(), isNull);

    notifier.startSession(_session(id: 'practice-2'));
    expect(notifier.state!.id, 'practice-2');
    expect(notifier.state!.elapsedSeconds, 0);
    expect(notifier.state!.status, ExamSessionStatus.inProgress);
    expect(notifier.submitExam(), isNotNull);
  });

  testWidgets('timer callback reconciles an entire throttled interval',
      (tester) async {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session(limitSeconds: 10));
    clock.advance(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 1));

    expect(notifier.state!.status, ExamSessionStatus.expired);
    expect(notifier.state!.elapsedSeconds, 15);
    expect(notifier.state!.remainingDuration, Duration.zero);
  });

  test('zero-duration practice session expires immediately', () {
    final clock = _ManualPracticeClock();
    final notifier = ExamSessionNotifier(
      ExamEvaluationService(),
      clock: clock,
    );
    addTearDown(notifier.dispose);

    notifier.startSession(_session(limitSeconds: 0));
    expect(notifier.state!.status, ExamSessionStatus.expired);
    expect(notifier.submitExam(), isNotNull);
    expect(notifier.submitExam(), isNull);
  });
}
