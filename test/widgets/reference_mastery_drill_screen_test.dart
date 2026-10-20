import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/reference_mastery_drill.dart';
import 'package:learning_pwa/screens/assessment/reference_mastery_drill_screen.dart';

ReferenceDrillExercise synthetic(ReferenceDrillMode mode) =>
    ReferenceDrillExercise(
      id: 'fictional-item',
      mode: mode,
      manifestRevisionId: 'fictional-manifest',
      bindingRevisionId: 'fictional-binding',
      scenario: 'This is a fictional reference navigation scenario.',
      syntheticFixture: true,
      steps: mode == ReferenceDrillMode.r1
          ? [
              ReferenceDrillStep.choice(
                skill: ReferenceSkill.chooseReference,
                prompt: 'Which fictional book contains this?',
                options: const ['Manual A', 'Manual B'],
                correctOptionIndex: 1,
                feedback: 'Manual B is the fictional example answer.',
              ),
            ]
          : [
              ReferenceDrillStep.location(
                prompt: 'Find the fictional section.',
                acceptedSectionIdentifiers: const ['2.1'],
                feedback: 'This example uses section 2.1.',
              ),
            ],
    );

void main() {
  testWidgets('R1 UI displays synthetic warning, per-skill correction and no persistence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReferenceMasteryDrillScreen(
        exercise: synthetic(ReferenceDrillMode.r1),
      ),
    ));
    expect(find.byKey(const Key('reference-prototype-warning')),
        findsOneWidget);
    expect(find.textContaining('No answers or progress are saved'),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('reference-choice-0')));
    await tester.pump();
    await tester.tap(find.text('Check step'));
    await tester.pumpAndSettle();
    expect(find.text('Review this step'), findsOneWidget);
    expect(find.text('Manual B is the fictional example answer.'),
        findsOneWidget);
    await tester.tap(find.text('View skill breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('Skill breakdown'), findsOneWidget);
    expect(find.text('Choosing the reference: Needs practice'),
        findsOneWidget);
    expect(find.textContaining('not an official scaled score'), findsOneWidget);
  });

  testWidgets('R2 UI accepts a typed section and labels self-reported time',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReferenceMasteryDrillScreen(
        exercise: synthetic(ReferenceDrillMode.r2),
      ),
    ));
    await tester.enterText(
      find.byKey(const Key('reference-section-input')), ' 2.1 ',
    );
    await tester.pump();
    await tester.tap(find.text('Check step'));
    await tester.pumpAndSettle();
    expect(find.text('Correct for this step'), findsOneWidget);
    await tester.tap(find.text('View skill breakdown'));
    await tester.pumpAndSettle();
    expect(find.text('Locating the section: Correct'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('reference-physical-minutes-input')),
    );
    await tester.enterText(
      find.byKey(const Key('reference-physical-minutes-input')), '7',
    );
    await tester.ensureVisible(find.text('Record self-reported time'));
    await tester.tap(find.text('Record self-reported time'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reference-self-reported-time')),
        findsOneWidget);
    expect(find.text('Self-reported physical-book time: 7 minutes'),
        findsOneWidget);
  });
}
