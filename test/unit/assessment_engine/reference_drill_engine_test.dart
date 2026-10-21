import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/reference_drill_engine.dart';

void main() {
  ReviewedReferenceDrillTask syntheticTask() => ReviewedReferenceDrillTask(
    itemId: 'fictional-item',
    answerBindingId: 'fictional-review-binding',
    manifestRevisionId: 'fictional-manifest-2027',
    partKey: 'project_management',
    referenceEditionKey: 'fictional_handbook',
    sourceEdition: '2027-fixture',
    itemContentRevision: 1,
    answerLocationRevision: 1,
    expectedAnswers: {
      ReferenceDrillStep.resourceChoice: 'fictional_handbook',
      ReferenceDrillStep.sectionLocation: '2.1',
      ReferenceDrillStep.interpretation: 'applies',
      ReferenceDrillStep.application: 'answer_b',
    },
  );

  test('R1–R4 expose separate correctness and timing, not a pass estimate', () {
    final session = DisposableReferenceDrillSession(
      task: syntheticTask(),
      permittedSteps: ReferenceDrillStep.values.toSet(),
      startedAt: DateTime.utc(2027, 1, 1),
    );
    expect(session.nextStep, ReferenceDrillStep.resourceChoice);
    session.submit(
      step: ReferenceDrillStep.resourceChoice,
      answer: 'fictional_handbook',
      appElapsed: const Duration(seconds: 13),
    );
    session.submit(
      step: ReferenceDrillStep.sectionLocation,
      answer: '1.9',
      appElapsed: const Duration(seconds: 29),
      selfReportedBookTime: const Duration(minutes: 3),
    );
    session.submit(
      step: ReferenceDrillStep.interpretation,
      answer: 'applies',
      appElapsed: const Duration(seconds: 19),
    );
    session.submit(
      step: ReferenceDrillStep.application,
      answer: 'answer_b',
      appElapsed: const Duration(seconds: 21),
    );
    final result = session.results;
    expect(result.isComplete, isTrue);
    expect(result.fullChainCorrect, isFalse);
    expect(result.manifestRevisionId, 'fictional-manifest-2027');
    expect(result.byStep[ReferenceDrillStep.resourceChoice],
        ReferenceDrillOutcome.correct);
    expect(result.byStep[ReferenceDrillStep.sectionLocation],
        ReferenceDrillOutcome.incorrect);
    expect(result.steps[1].appElapsed, const Duration(seconds: 29));
    expect(result.steps[1].selfReportedBookTime, const Duration(minutes: 3));
    expect(result.steps[0].selfReportedBookTime, isNull);
  });

  test('Standalone R2 location drill is allowed without synthetic R1 score', () {
    final session = DisposableReferenceDrillSession(
      task: syntheticTask(),
      permittedSteps: {ReferenceDrillStep.sectionLocation},
      startedAt: DateTime.utc(2027, 1, 1),
    );
    expect(session.nextStep, ReferenceDrillStep.sectionLocation);
    session.submit(
      step: ReferenceDrillStep.sectionLocation,
      answer: '2.1',
      appElapsed: const Duration(seconds: 16),
    );
    expect(session.nextStep, isNull);
    expect(session.results.steps.length, 1);
    expect(session.results.fullChainCorrect, isFalse);
  });

  test('Steps cannot be skipped or submitted twice in a full chain', () {
    final session = DisposableReferenceDrillSession(
      task: syntheticTask(),
      permittedSteps: ReferenceDrillStep.values.toSet(),
      startedAt: DateTime.utc(2027, 1, 1),
    );
    expect(() => session.submit(
      step: ReferenceDrillStep.application,
      answer: 'answer_b',
      appElapsed: const Duration(seconds: 1),
    ), throwsStateError);
    session.submit(
      step: ReferenceDrillStep.resourceChoice,
      answer: 'fictional_handbook',
      appElapsed: Duration.zero,
    );
    expect(() => session.submit(
      step: ReferenceDrillStep.resourceChoice,
      answer: 'fictional_handbook',
      appElapsed: const Duration(seconds: 2),
    ), throwsStateError);
  });

  test('Missing answers are skipped; durations cannot be negative', () {
    final session = DisposableReferenceDrillSession(
      task: syntheticTask(),
      permittedSteps: {ReferenceDrillStep.interpretation},
      startedAt: DateTime.utc(2027, 1, 1),
    );
    expect(() => session.submit(
      step: ReferenceDrillStep.interpretation,
      answer: '',
      appElapsed: const Duration(seconds: -1),
    ), throwsArgumentError);
    final result = session.submit(
      step: ReferenceDrillStep.interpretation,
      answer: '',
      appElapsed: const Duration(seconds: 10),
    );
    expect(result.outcome, ReferenceDrillOutcome.skipped);
  });

  test('Missing any answer or nonpositive content revisions fail closed', () {
    expect(() => ReviewedReferenceDrillTask(
      itemId: 'item',
      answerBindingId: 'binding',
      manifestRevisionId: 'manifest',
      partKey: 'part',
      referenceEditionKey: 'book',
      sourceEdition: 'edition',
      itemContentRevision: 1,
      answerLocationRevision: 0,
      expectedAnswers: {ReferenceDrillStep.resourceChoice: 'book'},
    ), throwsFormatException);
  });

  test('New manifest never inherits approval for previous edition', () {
    expect(ReferenceDrillEligibility.canStart(
      requestedManifestRevisionId: '2027-uuid',
      approvedManifestRevisionId: '2026-uuid',
      bindingApproved: true,
      partMatches: true,
      editionMatches: true,
    ), isFalse);
    expect(ReferenceDrillEligibility.canStart(
      requestedManifestRevisionId: '2027-uuid',
      approvedManifestRevisionId: '2027-uuid',
      bindingApproved: false,
      partMatches: true,
      editionMatches: true,
    ), isFalse);
    expect(ReferenceDrillEligibility.canStart(
      requestedManifestRevisionId: '2027-uuid',
      approvedManifestRevisionId: '2027-uuid',
      bindingApproved: true,
      partMatches: false,
      editionMatches: true,
    ), isFalse);
    expect(ReferenceDrillEligibility.canStart(
      requestedManifestRevisionId: '2027-uuid',
      approvedManifestRevisionId: '2027-uuid',
      bindingApproved: true,
      partMatches: true,
      editionMatches: false,
    ), isFalse);
    expect(ReferenceDrillEligibility.canStart(
      requestedManifestRevisionId: '2027-uuid',
      approvedManifestRevisionId: '2027-uuid',
      bindingApproved: true,
      partMatches: true,
      editionMatches: true,
    ), isTrue);
  });
}
