import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/rubric/long_answer_evaluator_service.dart';
import 'package:learning_pwa/widgets/rubric/long_answer_grading_widget.dart';

void main() {
  group('LongAnswerGradingWidget Tests', () {
    final rubric = LongAnswerEvaluatorService.defaultRubrics.first;

    testWidgets('renders prompt question, guidance, and text input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LongAnswerGradingWidget(rubric: rubric),
          ),
        ),
      );

      expect(find.text(rubric.title), findsOneWidget);
      expect(find.text('Assignment Prompt'), findsOneWidget);
      expect(find.text(rubric.promptQuestion), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Grade Response'), findsOneWidget);
    });

    testWidgets('submits response and renders scorecard breakdown', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const responseText = '''
To ensure jobsite safety, the 3-tier supported scaffold must be erected with base plates and mud sills, 
maintaining proper plumb and adhering to total load capacity ratings to prevent collapse under 29 CFR 1926.451(a). 
Clearance from overhead power lines must be maintained at all times. 
For fall protection, guardrails with a top rail, midrail, and toeboards are mandatory on all open sides, 
and a personal fall arrest system is required whenever working above 10 feet under 29 CFR 1926.451(g) and 29 CFR 1926.502. 
A designated competent person must conduct a mandatory pre-shift inspection daily under 29 CFR 1926.451(f)(3), 
immediately applying a tagout or red tag to any defective components. 
In the event of an arrested fall, the site safety plan mandates prompt rescue procedures to prevent fatal suspension trauma 
with on-site first aid and emergency response protocols ready.
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LongAnswerGradingWidget(
              rubric: rubric,
              initialText: responseText,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Grade Response'), findsOneWidget);

      await tester.ensureVisible(find.text('Grade Response'));
      await tester.tap(find.text('Grade Response'));
      await tester.pumpAndSettle();

      expect(find.text('Standard Met (Passed)'), findsOneWidget);
      expect(find.text('Criterion Breakdown:'), findsOneWidget);
      expect(find.text('Revise Response'), findsOneWidget);
    });
  });
}
