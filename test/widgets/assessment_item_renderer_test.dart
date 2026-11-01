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
    });

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

    testWidgets('Anchor option (None of the above) is kept at the end while others shuffle', (tester) async {
      final anchorItem = AssessmentItem(
        id: 'item-anchor-1',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Which protocol operates at the Transport layer?',
        responseSpec: {
          'options': ['HTTP', 'SMTP', 'FTP', 'None of the above'],
        },
        scoringSpec: {
          'correct_index': 3,
        },
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: anchorItem,
              presentationSeed: 42,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
      final presentation = state.presentationOrder as List<int>;

      // Original index 3 ('None of the above') must remain at the last slot
      expect(presentation.last, equals(3));
      expect(presentation.length, equals(4));
    });

    testWidgets('Different presentation seeds yield different permutations for the same item', (tester) async {
      final item = AssessmentItem(
        id: 'item-shuffle-demo',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Pick the correct letter:',
        responseSpec: {
          'options': ['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'],
        },
        scoringSpec: {
          'correct_index': 0,
        },
        createdAt: now,
        updatedAt: now,
      );

      // Render with seed 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              key: const ValueKey('seed-1'),
              item: item,
              presentationSeed: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state1 = tester.state(find.byKey(const ValueKey('seed-1'))) as dynamic;
      final order1 = List<int>.from(state1.presentationOrder as List<int>);

      // Render with seed 250
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              key: const ValueKey('seed-250'),
              item: item,
              presentationSeed: 250,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state2 = tester.state(find.byKey(const ValueKey('seed-250'))) as dynamic;
      final order2 = List<int>.from(state2.presentationOrder as List<int>);

      // Both orders are permutations of [0, 1, 2, 3, 4]
      expect(order1.toSet(), equals({0, 1, 2, 3, 4}));
      expect(order2.toSet(), equals({0, 1, 2, 3, 4}));
      // Different seeds should produce different orderings
      expect(order1, isNot(equals(order2)));
    });

    testWidgets('Grading evaluates correctly regardless of option permutation', (tester) async {
      bool? isCorrectResult;

      final item = AssessmentItem(
        id: 'item-perm-grade',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'What is the capital of France?',
        responseSpec: {
          'options': ['Paris', 'London', 'Berlin', 'Rome'],
        },
        scoringSpec: {
          'correct_index': 0, // 'Paris' is correct
        },
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: item,
              presentationSeed: 99,
              onAnswerSubmitted: (correct, score) {
                isCorrectResult = correct;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
      final order = state.presentationOrder as List<int>;
      // Verify Paris is not necessarily slot 0
      final parisSlot = order.indexOf(0);
      expect(parisSlot, isNotNull);

      // Select Paris
      await tester.tap(find.text('Paris'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Check Answer'));
      await tester.tap(find.text('Check Answer'));
      await tester.pumpAndSettle();

      expect(isCorrectResult, isTrue);
    });

    testWidgets('Same mounted widget regenerates option permutation when presentationSeed changes', (tester) async {
      final item = AssessmentItem(
        id: 'item-seed-change-demo',
        interactionType: AssessmentInteractionType.singleChoice,
        prompt: 'Pick an option:',
        responseSpec: {
          'options': ['Apple', 'Banana', 'Cherry', 'Date', 'Elderberry'],
        },
        scoringSpec: {
          'correct_index': 0,
        },
        createdAt: now,
        updatedAt: now,
      );

      // Mount widget with seed 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: item,
              presentationSeed: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state1 = tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
      final order1 = List<int>.from(state1.presentationOrder as List<int>);

      // Re-pump same widget with new presentationSeed (no key change)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentItemRenderer(
              item: item,
              presentationSeed: 250,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state2 = tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
      final order2 = List<int>.from(state2.presentationOrder as List<int>);

      // Verify permutation changed on the same mounted instance
      expect(order1, isNot(equals(order2)));
    });
  });
}
