import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/diagnostic_assessment.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';

import '../test_helpers/fake_supabase_client.dart';

DiagnosticAssessmentItem _question() => DiagnosticAssessmentItem(
  item: AssessmentItem(
    id: 'question-a',
    prompt: 'Synthetic question',
    interactionType: AssessmentInteractionType.singleChoice,
    responseSpec: const {'options': ['A', 'B']},
    scoringSpec: const {'correct_index': 0},
    createdAt: DateTime.utc(2026, 10, 21),
    updatedAt: DateTime.utc(2026, 10, 21),
  ),
  concepts: const [
    DiagnosticConceptRef(
      conceptId: 'concept-1', conceptName: 'Concept One',
    ),
  ],
);

DiagnosticAssessmentReport _report({
  required String owner,
  required String part,
}) => DiagnosticAssessmentReport(
  id: 'report-$part',
  targetId: 'target-1',
  targetVersionId: 'version-1',
  targetTitle: 'Synthetic target',
  examPartKey: part,
  curriculumRootNodeId: 'root-$part',
  learnerId: owner,
  completedAt: DateTime.utc(2026, 10, 21),
  totalQuestions: 1,
  correctQuestions: 1,
  partialQuestions: 0,
  overallEvidenceScore: 1,
  evidenceBand: DiagnosticEvidenceBand.strongEvidence,
  conceptEvaluations: const [],
  reinforcementPriorities: const [],
  strongEvidenceConcepts: const [],
  evidencePersisted: true,
);

class _ControlledScopedService extends DiagnosticAssessmentService {
  _ControlledScopedService() : super(supabase: FakeSupabaseClient());

  int submissions = 0;
  String? seenPart;
  String? seenOwner;
  Completer<DiagnosticAssessmentReport>? pending;
  DiagnosticAssessmentReport? overrideReport;

  @override
  Future<DiagnosticAssessmentReport> evaluatePartDiagnosticSession({
    required String userId,
    required String targetId,
    required String targetTitle,
    required String targetVersionId,
    required String examPartKey,
    required List<DiagnosticAssessmentItem> items,
    required List<DiagnosticAnswerSubmission> submissions,
  }) async {
    this.submissions++;
    seenPart = examPartKey;
    seenOwner = userId;
    return pending?.future ??
        overrideReport ??
        _report(owner: userId, part: examPartKey);
  }
}

void main() {
  group('EXM-03 learner-scoped diagnostic session', () {
    late _ControlledScopedService service;
    late DiagnosticSessionNotifier notifier;

    setUp(() {
      service = _ControlledScopedService();
      notifier = DiagnosticSessionNotifier(
        service,
        (targetId: 'target-1', targetVersionId: 'version-1'),
        examPartKey: 'part_a',
        learnerId: 'learner-a',
      )..initialize([_question()]);
    });

    tearDown(() => notifier.dispose());

    test('stores explicit part/owner and forbids unknown response IDs', () {
      expect(notifier.state.examPartKey, 'part_a');
      expect(notifier.state.learnerId, 'learner-a');
      notifier.recordResponse('foreign-question', 0);
      expect(notifier.state.responses, isEmpty);
      notifier.recordResponse('question-a', 0);
      expect(notifier.state.responses['question-a'], 0);
    });

    test('wrong learner cannot submit or create other-owner report', () async {
      notifier.recordResponse('question-a', 0);
      await expectLater(
        notifier.submitAssessment(
          userId: 'learner-b', targetTitle: 'Synthetic target',
        ),
        throwsStateError,
      );
      expect(service.submissions, 0);
      expect(notifier.state.isSubmitting, isFalse);
    });

    test('repeat click cannot score twice even while first call is pending',
        () async {
      service.pending = Completer<DiagnosticAssessmentReport>();
      notifier.recordResponse('question-a', 0);
      final first = notifier.submitAssessment(
        userId: 'learner-a', targetTitle: 'Synthetic target',
      );
      expect(notifier.state.isSubmitting, isTrue);
      expect(service.submissions, 1);
      notifier.recordResponse('question-a', 1);
      expect(notifier.state.responses['question-a'], 0);

      await expectLater(
        notifier.submitAssessment(
          userId: 'learner-a', targetTitle: 'Synthetic target',
        ),
        throwsStateError,
      );
      service.pending!.complete(_report(owner: 'learner-a', part: 'part_a'));
      final report = await first;
      expect(report.examPartKey, 'part_a');
      expect(report.learnerId, 'learner-a');
      expect(notifier.state.report, same(report));
      expect(service.submissions, 1);

      await expectLater(
        notifier.submitAssessment(
          userId: 'learner-a', targetTitle: 'Synthetic target',
        ),
        throwsStateError,
      );
      expect(service.submissions, 1);
    });

    test('mismatched result is rejected without publishing private report',
        () async {
      service.overrideReport = _report(owner: 'learner-b', part: 'part_b');
      notifier.recordResponse('question-a', 0);
      await expectLater(
        notifier.submitAssessment(
          userId: 'learner-a', targetTitle: 'Synthetic target',
        ),
        throwsStateError,
      );
      expect(notifier.state.report, isNull);
      expect(notifier.state.isSubmitting, isFalse);
    });
  });

  test('distinct part keys cannot reuse an old part response', () {
    final service = _ControlledScopedService();
    final owner = StateProvider<String>((ref) => 'learner-a');
    final container = ProviderContainer(overrides: [
      learnerIdProvider.overrideWith((ref) => ref.watch(owner)),
      diagnosticAssessmentServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    final keyA = (
      targetId: 'target-1',
      targetVersionId: 'version-1',
      examPartKey: 'part_a',
      learnerId: 'learner-a',
    );
    final keyB = (
      targetId: 'target-1',
      targetVersionId: 'version-1',
      examPartKey: 'part_b',
      learnerId: 'learner-a',
    );
    final a = container.read(scopedDiagnosticSessionProvider(keyA).notifier);
    final b = container.read(scopedDiagnosticSessionProvider(keyB).notifier);
    a.initialize([_question()]);
    b.initialize([_question()]);
    a.recordResponse('question-a', 0);
    expect(a.state.responses['question-a'], 0);
    expect(b.state.responses, isEmpty);

    container.read(owner.notifier).state = 'learner-b';
    expect(
      () => container.read(scopedDiagnosticSessionProvider(keyA)),
      throwsStateError,
    );
  });
}
