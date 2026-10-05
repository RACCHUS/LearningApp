import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/screens/assessment/mock_exam_screen.dart';

void main() {
  group('Phase E: MockExamScreen Widget Tests', () {
    final now = DateTime.now();

    final blueprint = const MockExamBlueprint(
      targetVersionId: 'tv-test',
      examCode: 'SY0-701',
      title: 'CompTIA Security+ Exam Simulation',
      timeLimitMinutes: 90,
      officialPassingScore: 750,
      domainWeights: [
        DomainWeightConstraint(
          domainId: 'dom-1',
          domainCode: '1.0',
          domainTitle: 'General Security Concepts',
          weight: 1.0,
        ),
      ],
    );

    final item1 = AssessmentItem(
      id: 'exam-item-1',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Which security tenet prevents alteration of confidential data in transit?',
      responseSpec: {
        'options': ['Availability', 'Integrity', 'Non-repudiation'],
        'answer': 'Integrity',
      },
      scoringSpec: {'correct_index': 1},
      explanation: 'Integrity guarantees data remains unaltered.',
      difficulty: 'beginner',
      createdAt: now,
      updatedAt: now,
    );

    final item2 = AssessmentItem(
      id: 'exam-item-2',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Which protocol secures email transmission via opportunistic TLS?',
      responseSpec: {
        'options': ['STARTTLS', 'IMAP4', 'POP3'],
        'answer': 'STARTTLS',
      },
      scoringSpec: {'correct_index': 0},
      explanation: 'STARTTLS upgrades plaintext connections to TLS.',
      difficulty: 'intermediate',
      createdAt: now,
      updatedAt: now,
    );

    final session = MockExamSession(
      id: 'session-sim-1',
      blueprint: blueprint,
      items: [item1, item2],
      itemDomainMap: {
        'exam-item-1': '1.0',
        'exam-item-2': '1.0',
      },
      startedAt: now,
      timeLimit: const Duration(minutes: 90),
      status: ExamSessionStatus.inProgress,
    );

    testWidgets('MockExamScreen renders header, timer, flag, navigation, and matrix sheet', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MockExamScreen(initialSession: session),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify header elements: Exam code, timer, and question indicator
      expect(find.text('SY0-701'), findsOneWidget);
      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('1:30:00'), findsOneWidget);

      // 2. Verify prompt
      expect(find.text('Which security tenet prevents alteration of confidential data in transit?'), findsOneWidget);

      // 3. Flag Question
      expect(find.text('Flag Question'), findsOneWidget);
      await tester.tap(find.text('Flag Question'));
      await tester.pumpAndSettle();
      expect(find.text('Flagged for Review'), findsOneWidget);

      // 4. Select answer: Integrity
      await tester.tap(find.text('Integrity'));
      await tester.pumpAndSettle();

      // 5. Navigate to Next Question
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Question 2 of 2'), findsOneWidget);
      expect(find.text('Which protocol secures email transmission via opportunistic TLS?'), findsOneWidget);

      // 6. Open Question Matrix Navigator
      final matrixButtonFinder = find.byIcon(Icons.grid_view_rounded);
      expect(matrixButtonFinder, findsOneWidget);
      await tester.tap(matrixButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Question Navigator'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded).last);
      await tester.pumpAndSettle();

      // 7. Finish Exam Confirmation Dialog
      await tester.tap(find.text('Finish Exam'));
      await tester.pumpAndSettle();

      expect(find.text('Finish & Submit Exam?'), findsOneWidget);
      // Item 2 is unanswered, so warning should show
      expect(find.text('1 unanswered question'), findsOneWidget);
      // Item 1 is flagged, so flag notice should show
      expect(find.text('1 flagged question for review'), findsOneWidget);

      // Confirm submission
      await tester.tap(find.text('Submit Final Exam'));
      await tester.pumpAndSettle();

      // Should transition to ExamReportScreen
      expect(find.text('Diagnostic Readiness Report'), findsOneWidget);
      expect(find.text('OFFICIAL BLUEPRINT STANDARD'), findsOneWidget);
      expect(find.text('APP READINESS ESTIMATE'), findsOneWidget);
    });
  });
}
