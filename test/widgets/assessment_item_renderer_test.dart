import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/assessment_stimulus.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';
import 'package:learning_pwa/widgets/assessment/stimulus_viewer.dart';

void main() {
  group('Phase D: AssessmentItemRenderer Widget Tests', () {
    final now = DateTime.now();

    final testStimulus = AssessmentStimulus(
      id: 'stim-clinical-1',
      stimulusType: AssessmentStimulusType.clinicalCase,
      title: 'Post-Operative Triage',
      body: '45-year-old male 2 hours post-appendectomy reports sudden dyspnea.',
      structuredData: {
        'heart_rate': '118 bpm',
        'blood_pressure': '138/88 mmHg',
        'sp_o2': '91% on room air',
      },
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('Single-choice item selects option, evaluates, and reveals rationale', (tester) async {
      bool? isCorrectResult;

      final singleChoiceItem = AssessmentItem(
        id: 'item-mcq-1',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Which symmetric cipher utilizes a 128-bit block size?',
        responseSpec: {
          'options': ['DES', 'Blowfish', 'AES', 'RC4'],
        },
        scoringSpec: {
          'correct_index': 2,
        },
        explanation: 'AES uses a fixed block size of 128 bits.',
        difficulty: 'intermediate',
        cognitiveLevel: 'comprehension',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: singleChoiceItem,
              onAnswerSubmitted: (correct, score) {
                isCorrectResult = correct;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Which symmetric cipher utilizes a 128-bit block size?'), findsOneWidget);
      expect(find.text('AES'), findsOneWidget);

      // Select 'AES' (index 2)
      await tester.tap(find.text('AES'));
      await tester.pumpAndSettle();

      // Tap Check Answer
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(isCorrectResult, isTrue);
      expect(find.text('Practice evidence: Correct retrieval'), findsOneWidget);
      expect(find.text('AES uses a fixed block size of 128 bits.'), findsOneWidget);
    });

    testWidgets('Multi-select (SATA) selects multiple options and evaluates correctly', (tester) async {
      bool? isCorrectResult;

      final sataItem = AssessmentItem(
        id: 'item-sata-1',
        interactionType: AssessmentInteractionType.multiSelect,
        prompt: 'Select all symmetric block ciphers below: (Select all that apply)',
        responseSpec: {
          'options': ['AES', 'RSA', '3DES', 'ECC'],
        },
        scoringSpec: {
          'correct_indices': [0, 2],
          'scoring_method': 'all_or_nothing',
        },
        stimulus: testStimulus,
        explanation: 'AES and 3DES are symmetric block ciphers. RSA and ECC are asymmetric.',
        difficulty: 'advanced',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: sataItem,
              onAnswerSubmitted: (correct, score) {
                isCorrectResult = correct;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Exhibit header is present
      expect(find.byType(StimulusViewer), findsOneWidget);
      expect(find.text('Post-Operative Triage'), findsOneWidget);

      // Select AES (index 0) and 3DES (index 2)
      await tester.ensureVisible(find.text('AES'));
      await tester.tap(find.text('AES'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('3DES'));
      await tester.tap(find.text('3DES'));
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Check Answer'));
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(isCorrectResult, isTrue);
      expect(find.text('Practice evidence: All criteria identified'), findsOneWidget);
    });

    testWidgets('Ordered response reorders sequence and submits verification', (tester) async {
      bool? isCorrectResult;

      final orderedItem = AssessmentItem(
        id: 'item-ord-1',
        interactionType: AssessmentInteractionType.orderedResponse,
        prompt: 'Order the incident response lifecycle phases chronologically:',
        responseSpec: {
          'items': ['Preparation', 'Detection & Analysis', 'Containment', 'Post-Incident Activity'],
        },
        scoringSpec: {
          'correct_order': [0, 1, 2, 3],
        },
        explanation: 'Standard NIST SP 800-61 Incident Handling process.',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: orderedItem,
              onAnswerSubmitted: (correct, score) {
                isCorrectResult = correct;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preparation'), findsOneWidget);
      expect(find.text('Containment'), findsOneWidget);

      // Submit pre-ordered sequence
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(isCorrectResult, isTrue);
      expect(find.text('Practice evidence: Sequential protocol validated'), findsOneWidget);

    testWidgets('Matching item uses canonical left/right items and scoring pairs', (tester) async {
      bool? isCorrectResult;

      final matchingItem = AssessmentItem(
        id: 'item-match-1',
        interactionType: AssessmentInteractionType.matching,
        prompt: 'Match each protocol to its default port:',
        responseSpec: {
          'left_items': ['HTTPS', 'SSH'],
          'right_items': ['443', '22'],
        },
        scoringSpec: {
          'correct_pairs': {'HTTPS': '443', 'SSH': '22'},
        },
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: matchingItem,
              onAnswerSubmitted: (correct, score) {
                isCorrectResult = correct;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('HTTPS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('443'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SSH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('22'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Check Answer'));
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(isCorrectResult, isTrue);
      expect(find.text('Practice evidence: All relationships accurately paired'), findsOneWidget);
    });
    });
  });
}
