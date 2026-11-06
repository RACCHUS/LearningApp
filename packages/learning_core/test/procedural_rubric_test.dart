import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProceduralRubricCore & ProceduralEvaluatorCore (OPP-4, OPP-3)', () {
    const handwashingStep = RubricCriterionCore(
      id: 'cna-crit-1',
      stepOrder: 1,
      title: 'Hand Hygiene Prior to Resident Contact',
      description: 'Lather hands with soap for at least 20 seconds before touching resident.',
      stepType: RubricStepType.criticalStep,
      weight: 1.0,
      maxScore: 2,
      criticalFailureNotice: 'Failure to perform hand hygiene breaches infection control standards.',
      authoritativeSourceRef: 'Prometric CNA Clinical Skills Checklist 2024 / CDC Hand Hygiene Protocol',
      descriptors: {
        0: 'Did not perform hand hygiene before touching resident',
        1: 'Used hand sanitizer but did not rub until dry',
        2: 'Thorough soap scrub for 20+ seconds or full sanitizing protocol',
      },
    );

    const vitalsStep = RubricCriterionCore(
      id: 'cna-crit-2',
      stepOrder: 2,
      title: 'Measure and Record Radial Pulse',
      description: 'Count pulse beats for full 60 seconds with fingertip placement.',
      stepType: RubricStepType.standardStep,
      weight: 1.0,
      maxScore: 2,
      descriptors: {
        0: 'Pulse rate error > 4 BPM or counted for < 30 seconds',
        1: 'Counted for 30s and multiplied with accuracy within 4 BPM',
        2: 'Counted full 60s and recorded exact measurement within 2 BPM',
      },
    );

    const documentationStep = RubricCriterionCore(
      id: 'cna-crit-3',
      stepOrder: 3,
      title: 'Document Resident Care Record',
      description: 'Sign and record values on official clinical sheet.',
      stepType: RubricStepType.standardStep,
      weight: 1.0,
      maxScore: 2,
    );

    final cnaRubric = ProceduralRubricCore(
      id: 'rubric-cna-skills',
      title: 'CNA Clinical Skills Exam: Vital Signs & Patient Contact',
      targetDomain: 'Certified Nursing Assistant (CNA)',
      passingScorePercentage: 0.80,
      timeLimitSeconds: 600,
      criteria: [handwashingStep, vitalsStep, documentationStep],
    );

    test('validates that critical steps require an authoritativeSourceRef citation', () {
      final validErrors = ProceduralEvaluatorCore.validateRubric(cnaRubric);
      expect(validErrors, isEmpty);

      const invalidCritical = RubricCriterionCore(
        id: 'bad-crit',
        stepOrder: 1,
        title: 'Uncited Critical Step',
        stepType: RubricStepType.criticalStep,
        authoritativeSourceRef: null, // missing required citation
      );

      final invalidRubric = ProceduralRubricCore(
        id: 'bad-rubric',
        title: 'Invalid Rubric',
        targetDomain: 'Testing',
        criteria: [invalidCritical],
      );

      final errors = ProceduralEvaluatorCore.validateRubric(invalidRubric);
      expect(errors.length, equals(1));
      expect(errors.first, contains('lacks an authoritativeSourceRef citation'));
    });

    test('evaluates passing performance when score >= 80% and zero critical failures', () {
      final evaluations = [
        const RubricStepEvaluation(criterionId: 'cna-crit-1', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-2', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-3', score: 2),
      ];

      final result = ProceduralEvaluatorCore.evaluate(
        rubric: cnaRubric,
        stepEvaluations: evaluations,
        elapsedSeconds: 300,
      );

      expect(result.totalEarnedScore, equals(6.0));
      expect(result.maxPossibleScore, equals(6.0));
      expect(result.scorePercentage, equals(1.0));
      expect(result.passed, isTrue);
      expect(result.criticalFailEncountered, isFalse);
      expect(result.criticalFailureReasons, isEmpty);
    });

    test('critical failure gate causes immediate failure despite high point percentage', () {
      // Learner gets 100% on vitals and documentation, but fails the critical handwashing step
      final evaluations = [
        const RubricStepEvaluation(
          criterionId: 'cna-crit-1',
          score: 0,
          criticalFailed: true,
          notes: 'Touched resident bed without washing hands.',
        ),
        const RubricStepEvaluation(criterionId: 'cna-crit-2', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-3', score: 2),
      ];

      final result = ProceduralEvaluatorCore.evaluate(
        rubric: cnaRubric,
        stepEvaluations: evaluations,
        elapsedSeconds: 300,
      );

      // Score is 4/6 = 66.7%
      expect(result.totalEarnedScore, equals(4.0));
      expect(result.maxPossibleScore, equals(6.0));
      // Must fail despite any points
      expect(result.passed, isFalse);
      expect(result.criticalFailEncountered, isTrue);
      expect(result.criticalFailureReasons.length, equals(1));
      expect(result.criticalFailureReasons.first, contains('Critical step failed: "Hand Hygiene'));
      expect(result.criticalFailureReasons.first, contains('Prometric CNA Clinical Skills'));
    });

    test('omitting a critical step entirely causes automatic failure', () {
      // Learner completes only vitals and documentation, omitting handwashing
      final evaluations = [
        const RubricStepEvaluation(criterionId: 'cna-crit-2', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-3', score: 2),
      ];

      final result = ProceduralEvaluatorCore.evaluate(
        rubric: cnaRubric,
        stepEvaluations: evaluations,
      );

      expect(result.passed, isFalse);
      expect(result.criticalFailEncountered, isTrue);
      expect(result.criticalFailureReasons.first, contains('Critical step omitted'));
    });

    test('exceeding time limit marks failure', () {
      final evaluations = [
        const RubricStepEvaluation(criterionId: 'cna-crit-1', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-2', score: 2),
        const RubricStepEvaluation(criterionId: 'cna-crit-3', score: 2),
      ];

      final result = ProceduralEvaluatorCore.evaluate(
        rubric: cnaRubric,
        stepEvaluations: evaluations,
        elapsedSeconds: 700, // timeLimit is 600s
      );

      expect(result.exceededTimeLimit, isTrue);
      expect(result.passed, isFalse);
    });

    test('PerformanceAssessmentAttempt serializes and deserializes accurately with role', () {
      final attempt = PerformanceAssessmentAttempt(
        rubricId: 'rubric-cna-skills',
        learnerId: 'learner-101',
        evaluatorId: 'instructor-proctor-9',
        role: PerformanceSignoffRole.evaluatorSignoff,
        stepEvaluations: const [
          RubricStepEvaluation(criterionId: 'cna-crit-1', score: 2),
          RubricStepEvaluation(criterionId: 'cna-crit-2', score: 1, notes: 'Counted 30s'),
        ],
        startedAt: DateTime.utc(2026, 11, 6, 10, 0),
        completedAt: DateTime.utc(2026, 11, 6, 10, 8),
        elapsedSeconds: 480,
        evaluatorNotes: 'Proficient hand hygiene technique.',
        evaluatorSignature: 'Evelyn Carter, RN',
      );

      final json = attempt.toJson();
      final roundTrip = PerformanceAssessmentAttempt.fromJson(json);

      expect(roundTrip.rubricId, equals('rubric-cna-skills'));
      expect(roundTrip.evaluatorId, equals('instructor-proctor-9'));
      expect(roundTrip.role, equals(PerformanceSignoffRole.evaluatorSignoff));
      expect(roundTrip.stepEvaluations.length, equals(2));
      expect(roundTrip.elapsedSeconds, equals(480));
      expect(roundTrip.evaluatorSignature, equals('Evelyn Carter, RN'));
    });
  });
}
