import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/family_abe_pilot.dart';
import 'package:learning_pwa/services/community/outcome_assessment_service.dart';
import 'package:learning_pwa/widgets/community/before_after_assessment_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BeforeAfterAssessmentWidget walks through pre/post tests and saves outcome',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = OutcomeAssessmentService();
    AssessmentOutcomeRecord? submittedRecord;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BeforeAfterAssessmentWidget(
              assessmentService: service,
              participantId: 'learner_test_ui',
              cohortId: 'cohort_b_family_osha',
              topic: 'OSHA Workplace Safety',
              onOutcomeSubmitted: (rec) => submittedRecord = rec,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: Pre-Test Question 1
    expect(find.text('Step 1: Diagnostic Pre-Test'), findsOneWidget);
    expect(find.text('Question 1 of 3'), findsOneWidget);

    // Tap option 1 (correct answer: Physical Elimination)
    await tester.tap(find.byKey(const Key('option_0_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Pre-Test Question 2
    expect(find.text('Question 2 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('option_1_0'))); // Option 0: ANSI Z87.1
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Pre-Test Question 3
    expect(find.text('Question 3 of 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('option_2_1'))); // Option 1: Lockout/Tagout
    await tester.pumpAndSettle();

    // Complete Pre-Test -> Transitions to Post-Study Assessment
    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Step 2: Post-Study Assessment Question 1
    expect(find.text('Step 2: Post-Study Assessment'), findsOneWidget);
    await tester.tap(find.byKey(const Key('option_0_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Post-Study Question 2
    await tester.tap(find.byKey(const Key('option_1_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Post-Study Question 3
    await tester.tap(find.byKey(const Key('option_2_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_next_button')));
    await tester.pumpAndSettle();

    // Gain Summary View
    expect(find.text('Measured Learning Outcome'), findsOneWidget);
    expect(find.text('Learner Pilot Feedback'), findsOneWidget);
    expect(find.byKey(const Key('save_outcome_button')), findsOneWidget);

    // Tap save outcome
    await tester.tap(find.byKey(const Key('save_outcome_button')));
    await tester.pumpAndSettle();

    expect(submittedRecord, isNotNull);
    expect(submittedRecord!.participantId, equals('learner_test_ui'));
  });
}

