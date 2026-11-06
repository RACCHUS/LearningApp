import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/services/performance/performance_assessment_service.dart';
import 'package:learning_pwa/widgets/performance/procedural_rubric_widget.dart';

void main() {
  group('ProceduralRubricWidget Tests (OPP-4, OPP-3)', () {
    const handwashingStep = RubricCriterionCore(
      id: 'step-handwash',
      stepOrder: 1,
      title: 'Hand Hygiene Protocol',
      description: 'Lather with soap for 20s before patient contact.',
      stepType: RubricStepType.criticalStep,
      weight: 1.0,
      maxScore: 2,
      criticalFailureNotice: 'Immediate failure for infection control violation.',
      authoritativeSourceRef: 'CDC Hand Hygiene / CNA Prometric 2024',
      descriptors: {
        0: 'Failed hand hygiene',
        1: 'Partial sanitization',
        2: 'Full 20s soap scrub',
      },
    );

    const bpStep = RubricCriterionCore(
      id: 'step-bp',
      stepOrder: 2,
      title: 'Measure Blood Pressure',
      description: 'Position cuff 1 inch above antecubital fossa and inflate.',
      stepType: RubricStepType.standardStep,
      weight: 1.0,
      maxScore: 2,
      descriptors: {
        0: 'Incorrect cuff size or positioning',
        1: 'Accurate within 8 mmHg',
        2: 'Exact auscultation within 4 mmHg',
      },
    );

    final sampleRubric = ProceduralRubricCore(
      id: 'rubric-vital-signs',
      title: 'Clinical Skills: Infection Control & Blood Pressure',
      description: 'Standardized practical skills exam checklist.',
      targetDomain: 'Clinical Nursing',
      passingScorePercentage: 0.80,
      criteria: [handwashingStep, bpStep],
    );

    testWidgets('renders rubric steps with CRITICAL STEP badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProceduralRubricWidget(
              rubric: sampleRubric,
              learnerId: 'learner-42',
            ),
          ),
        ),
      );

      expect(find.text('Clinical Skills: Infection Control & Blood Pressure'), findsOneWidget);
      expect(find.text('CLINICAL NURSING'), findsOneWidget);
      expect(find.text('Pass Threshold: 80%'), findsOneWidget);

      // Verify critical step badge is present on step 1
      expect(find.byKey(const Key('critical_badge_step-handwash')), findsOneWidget);
      expect(find.text('CRITICAL STEP'), findsOneWidget);
      expect(find.textContaining('Immediate failure for infection control violation'), findsOneWidget);
    });

    testWidgets('triggers critical failure alert when critical step is scored 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProceduralRubricWidget(
              rubric: sampleRubric,
              learnerId: 'learner-42',
            ),
          ),
        ),
      );

      // Score step 1 (critical) as 0
      final chip0 = find.byKey(const Key('criterion_step-handwash_score_0'));
      await tester.ensureVisible(chip0);
      await tester.tap(chip0);
      await tester.pumpAndSettle();

      // Score step 2 as 2 (100% on standard step)
      final chip2 = find.byKey(const Key('criterion_step-bp_score_2'));
      await tester.ensureVisible(chip2);
      await tester.tap(chip2);
      await tester.pumpAndSettle();

      // Verify critical failure alert banner appears
      expect(find.byKey(const Key('critical_failure_alert')), findsOneWidget);
      expect(find.text('AUTOMATIC CRITICAL FAILURE TRIGGERED'), findsOneWidget);
      expect(find.text('STATUS: NOT PASSING'), findsOneWidget);
    });

    testWidgets('completes passing assessment with evaluator sign-off and emits event',
        (tester) async {
      final service = PerformanceAssessmentService();
      PerformanceEvaluationResult? reportedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProceduralRubricWidget(
              rubric: sampleRubric,
              learnerId: 'learner-42',
              assessmentService: service,
              onAssessmentCompleted: (res) {
                reportedResult = res;
              },
            ),
          ),
        ),
      );

      // Score step 1 (critical) as 2 (perfect)
      final step1Chip = find.byKey(const Key('criterion_step-handwash_score_2'));
      await tester.ensureVisible(step1Chip);
      await tester.tap(step1Chip);
      await tester.pumpAndSettle();

      // Score step 2 as 2 (perfect)
      final step2Chip = find.byKey(const Key('criterion_step-bp_score_2'));
      await tester.ensureVisible(step2Chip);
      await tester.tap(step2Chip);
      await tester.pumpAndSettle();

      // Enter observer signature
      final sigField = find.byKey(const Key('evaluator_signature_field'));
      await tester.ensureVisible(sigField);
      await tester.enterText(sigField, 'Nurse Supervisor Miller, RN');
      await tester.pumpAndSettle();

      // Tap Complete Assessment
      final submitBtn = find.byKey(const Key('submit_assessment_button'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify result
      expect(reportedResult?.passed, isTrue);
      expect(reportedResult?.scorePercentage, equals(1.0));
      expect(reportedResult?.criticalFailEncountered, isFalse);

      // Verify service recorded attempt
      expect(service.recordedAttempts.length, equals(1));
      expect(service.recordedAttempts.first.evaluatorSignature, equals('Nurse Supervisor Miller, RN'));

      // Verify learning event emitted
      expect(service.emittedEvents.length, equals(1));
      expect(service.emittedEvents.first.eventType, equals('performance_assessment_completed'));
      expect(service.emittedEvents.first.score, equals(1.0));

      // Confirmation banner rendered
      expect(find.byKey(const Key('assessment_completed_banner')), findsOneWidget);
      expect(find.textContaining('Assessment Successfully Passed'), findsOneWidget);
    });
  });
}
