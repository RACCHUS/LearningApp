import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/reference_mastery_drill.dart';

ReferenceDrillStep choice(ReferenceSkill skill, int answer) =>
    ReferenceDrillStep.choice(
      skill: skill,
      prompt: 'Synthetic question for ' + skill.name,
      options: const ['Option A', 'Option B', 'Option C'],
      correctOptionIndex: answer,
      feedback: 'Check the fictional training guide.',
    );

ReferenceDrillExercise exerciseFor(ReferenceDrillMode mode) {
  final steps = switch (mode) {
    ReferenceDrillMode.r1 => [choice(ReferenceSkill.chooseReference, 1)],
    ReferenceDrillMode.r2 => [
        ReferenceDrillStep.location(
          prompt: 'Find the synthetic section',
          acceptedSectionIdentifiers: const ['Sec. 2.1', '2.1'],
          feedback: 'Look up the fictional index.',
        ),
      ],
    ReferenceDrillMode.r3 => [choice(ReferenceSkill.interpret, 2)],
    ReferenceDrillMode.r4 => [
        choice(ReferenceSkill.chooseReference, 1),
        ReferenceDrillStep.location(
          prompt: 'Find the synthetic section',
          acceptedSectionIdentifiers: const ['2.1'],
          feedback: 'Look up the fictional index.',
        ),
        choice(ReferenceSkill.interpret, 2),
        choice(ReferenceSkill.solve, 0),
      ],
  };
  return ReferenceDrillExercise(
    id: 'synthetic-exercise',
    mode: mode,
    manifestRevisionId: 'fictional-manifest-revision',
    bindingRevisionId: 'fictional-reviewed-binding',
    scenario: 'Fictional training task with no official exam claims',
    steps: steps,
    syntheticFixture: true,
  );
}

void main() {
  group('EXM-02A internal R1–R4 prototype', () {
    test('R1 measures reference selection only', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r1));
      expect(session.currentStep!.skill, ReferenceSkill.chooseReference);
      expect(session.submitOption(1).correct, isTrue);
      expect(session.complete, isTrue);
      expect(session.skillAccuracy.keys, [ReferenceSkill.chooseReference]);
      expect(() => session.submitOption(1), throwsStateError);
    });

    test('R2 requires reviewed section, not guessed page number', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r2));
      expect(session.submitSection('  SEC.   2.1  ').correct, isTrue);
      expect(session.complete, isTrue);
      final failed = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r2));
      expect(failed.submitSection('page 11').correct, isFalse);
    });

    test('R3 tests interpretation independently of reference selection', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r3));
      expect(session.submitOption(2).correct, isTrue);
      expect(session.skillAccuracy[ReferenceSkill.interpret], isTrue);
      expect(session.skillAccuracy.containsKey(ReferenceSkill.chooseReference),
          isFalse);
    });

    test('R4 keeps a wrong book separate from correct section and solution', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r4));
      session.submitOption(0); // wrong book
      session.continueAfterFeedback();
      session.submitSection('2.1'); // correct location
      session.continueAfterFeedback();
      session.submitOption(0); // wrong interpretation
      session.continueAfterFeedback();
      session.submitOption(0); // correct solution
      expect(session.complete, isTrue);
      expect(session.correctSteps, 2);
      expect(session.skillAccuracy, {
        ReferenceSkill.chooseReference: false,
        ReferenceSkill.locateSection: true,
        ReferenceSkill.interpret: false,
        ReferenceSkill.solve: true,
      });
    });

    test('Only the correct step order can represent each drill type', () {
      expect(
        () => ReferenceDrillExercise(
          id: 'invalid',
          mode: ReferenceDrillMode.r4,
          manifestRevisionId: 'rev',
          bindingRevisionId: 'binding',
          scenario: 'Scenario',
          steps: [choice(ReferenceSkill.solve, 0)],
          syntheticFixture: true,
        ),
        throwsStateError,
      );
    });

    test('Real content is blocked until approved secure delivery exists', () {
      expect(
        () => ReferenceDrillExercise(
          id: 'unreviewed-real-item',
          mode: ReferenceDrillMode.r1,
          manifestRevisionId: 'rev',
          bindingRevisionId: 'binding',
          scenario: 'Do not publish this',
          steps: [choice(ReferenceSkill.chooseReference, 1)],
          syntheticFixture: false,
        ),
        throwsStateError,
      );
    });

    test('Invalid answer format does not advance the session', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r4));
      expect(() => session.submitSection('2.1'), throwsFormatException);
      expect(() => session.submitOption(999), throwsFormatException);
      expect(session.currentStepIndex, 0);
    });

    test('Measured app time is distinct from optional physical book time', () {
      var now = DateTime.utc(2027, 1, 1);
      final session = ReferenceDrillSession(
        exerciseFor(ReferenceDrillMode.r4),
        clock: () => now,
      );
      now = now.add(const Duration(seconds: 12));
      session.submitOption(1);
      now = now.add(const Duration(seconds: 40)); // reading feedback
      session.continueAfterFeedback();
      now = now.add(const Duration(seconds: 18));
      session.submitSection('2.1');
      now = now.add(const Duration(seconds: 7)); // reading feedback
      session.continueAfterFeedback();
      now = now.add(const Duration(seconds: 9));
      session.submitOption(2);
      now = now.add(const Duration(seconds: 20)); // reading feedback
      session.continueAfterFeedback();
      now = now.add(const Duration(seconds: 22));
      session.submitOption(0);
      expect(session.observedAppDuration, const Duration(seconds: 61));
      expect(session.selfReportedPhysicalMinutes, isNull);
      session.reportPhysicalBookMinutes(7);
      expect(session.selfReportedPhysicalMinutes, 7);
      expect(session.observedAppDuration, const Duration(seconds: 61));
      expect(() => session.reportPhysicalBookMinutes(1441),
          throwsFormatException);
    });

    test('Feedback must be acknowledged before another step can be scored', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r4));
      session.submitOption(1);
      expect(() => session.submitSection('2.1'), throwsStateError);
      session.continueAfterFeedback();
      expect(session.submitSection('2.1').correct, isTrue);
    });

    test('Self-reported time is not editable until session finishes', () {
      final session = ReferenceDrillSession(exerciseFor(ReferenceDrillMode.r1));
      expect(() => session.reportPhysicalBookMinutes(2), throwsStateError);
    });
  });
}
