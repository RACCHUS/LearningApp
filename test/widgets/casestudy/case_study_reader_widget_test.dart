import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/casestudy/case_study_scenario.dart';
import 'package:learning_pwa/widgets/casestudy/case_study_reader_widget.dart';

void main() {
  group('CaseStudyReaderWidget Tests', () {
    const testScenario = CaseStudyScenario(
      id: 'case-test-1',
      title: 'Emergency Generator Safety',
      overview: 'Investigating high carbon monoxide readings near an indoor loading dock.',
      domain: 'Industrial Hygiene',
      difficulty: 'Intermediate',
      steps: [
        CaseStudyStep(
          id: 'step_1',
          stepNumber: 1,
          narrative:
              'A portable generator is running 5 feet outside the roll-up door, but exhaust is wafting indoors.',
          choices: [
            CaseStudyDecisionChoice(
              id: 'c1',
              text: 'Shut down the generator immediately and evacuate the dock area.',
              isOptimal: true,
              feedback: 'CO is an odorless asphyxiant that rapidly accumulates.',
              regulatoryCitation: 'OSHA Technical Manual Section III',
            ),
            CaseStudyDecisionChoice(
              id: 'c2',
              text: 'Turn on ceiling fans and continue unloading.',
              isOptimal: false,
              feedback: 'Fans only distribute the poison throughout the facility.',
            ),
          ],
        ),
      ],
    );

    testWidgets('renders step narrative, choices, and overview', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CaseStudyReaderWidget(scenario: testScenario),
          ),
        ),
      );

      expect(find.text('Emergency Generator Safety'), findsOneWidget);
      expect(find.text('Step 1 of 1'), findsOneWidget);
      expect(
        find.text('Shut down the generator immediately and evacuate the dock area.'),
        findsOneWidget,
      );
    });

    testWidgets('selecting choice and submitting displays debrief feedback and citation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CaseStudyReaderWidget(scenario: testScenario),
          ),
        ),
      );

      await tester.tap(
        find.text('Shut down the generator immediately and evacuate the dock area.'),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('case_action_button')));
      await tester.pump();

      expect(find.text('Optimal Regulatory Decision'), findsOneWidget);
      expect(find.text('Citation: OSHA Technical Manual Section III'), findsOneWidget);
    });
  });
}
