import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';
import 'package:learning_pwa/widgets/content_renderers/question_content_renderer.dart';
import 'package:learning_pwa/widgets/lesson_content_renderer.dart';

void main() {
  group('VoiceInputHandler', () {
    final mcq = QuestionContent(
      id: 'q1',
      lessonId: 'l1',
      order: 0,
      questionText: 'Sample question?',
      options: ['Alpha', 'Beta', 'Gamma', 'Delta'],
      correctAnswer: 1,
      explanation: 'Explanation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('translates spoken A without presentationOrder to slot 0', () {
      final result = VoiceInputHandler.handleMcqVoiceInput('option a', mcq);
      expect(result, equals(0));
    });

    test('translates spoken B without presentationOrder to slot 1', () {
      final result = VoiceInputHandler.handleMcqVoiceInput('option b', mcq);
      expect(result, equals(1));
    });

    test(
      'translates spoken A-D with presentationOrder [2, 0, 1, 3] to original indices',
      () {
        // Presented slots:
        // A (slot 0) -> original option 2 ('Gamma')
        // B (slot 1) -> original option 0 ('Alpha')
        // C (slot 2) -> original option 1 ('Beta')
        // D (slot 3) -> original option 3 ('Delta')
        final presentationOrder = [2, 0, 1, 3];

        final resultA = VoiceInputHandler.handleMcqVoiceInput(
          'option a',
          mcq,
          presentationOrder: presentationOrder,
        );
        expect(resultA, equals(2));

        final resultB = VoiceInputHandler.handleMcqVoiceInput(
          'option b',
          mcq,
          presentationOrder: presentationOrder,
        );
        expect(resultB, equals(0));

        final resultC = VoiceInputHandler.handleMcqVoiceInput(
          'option c',
          mcq,
          presentationOrder: presentationOrder,
        );
        expect(resultC, equals(1));

        final resultD = VoiceInputHandler.handleMcqVoiceInput(
          'option d',
          mcq,
          presentationOrder: presentationOrder,
        );
        expect(resultD, equals(3));
      },
    );

    test(
      'handles fallback natural phrases and choice prefixes with presentationOrder',
      () {
        final presentationOrder = [3, 2, 1, 0];
        expect(
          VoiceInputHandler.handleMcqVoiceInput(
            'the first one',
            mcq,
            presentationOrder: presentationOrder,
          ),
          equals(3),
        );
        expect(
          VoiceInputHandler.handleMcqVoiceInput(
            'choose b',
            mcq,
            presentationOrder: presentationOrder,
          ),
          equals(2),
        );
        expect(
          VoiceInputHandler.handleMcqVoiceInput(
            'answer c',
            mcq,
            presentationOrder: presentationOrder,
          ),
          equals(1),
        );
        expect(
          VoiceInputHandler.handleMcqVoiceInput(
            'fourth option',
            mcq,
            presentationOrder: presentationOrder,
          ),
          equals(0),
        );
      },
    );

    test(
      'maps numeric voice commands 1-4 and number one-four through presentationOrder',
      () {
        final presentationOrder = [2, 0, 3, 1];
        const slot0Commands = [
          '1',
          'one',
          'number 1',
          'number one',
          'option 1',
          'choice one',
        ];
        const slot1Commands = [
          '2',
          'two',
          'number 2',
          'number two',
          'option 2',
          'choice two',
        ];
        const slot2Commands = [
          '3',
          'three',
          'number 3',
          'number three',
          'option 3',
          'choice three',
        ];
        const slot3Commands = [
          '4',
          'four',
          'number 4',
          'number four',
          'option 4',
          'choice four',
        ];

        for (final cmd in slot0Commands) {
          expect(
            VoiceInputHandler.handleMcqVoiceInput(
              cmd,
              mcq,
              presentationOrder: presentationOrder,
            ),
            equals(2),
            reason:
                '"$cmd" should select displayed slot 0 -> canonical index 2',
          );
        }
        for (final cmd in slot1Commands) {
          expect(
            VoiceInputHandler.handleMcqVoiceInput(
              cmd,
              mcq,
              presentationOrder: presentationOrder,
            ),
            equals(0),
            reason:
                '"$cmd" should select displayed slot 1 -> canonical index 0',
          );
        }
        for (final cmd in slot2Commands) {
          expect(
            VoiceInputHandler.handleMcqVoiceInput(
              cmd,
              mcq,
              presentationOrder: presentationOrder,
            ),
            equals(3),
            reason:
                '"$cmd" should select displayed slot 2 -> canonical index 3',
          );
        }
        for (final cmd in slot3Commands) {
          expect(
            VoiceInputHandler.handleMcqVoiceInput(
              cmd,
              mcq,
              presentationOrder: presentationOrder,
            ),
            equals(1),
            reason:
                '"$cmd" should select displayed slot 3 -> canonical index 1',
          );
        }
      },
    );

    test(
      'rejects ordinary speech and embedded letters without false-positive selection',
      () {
        final presentationOrder = [2, 0, 1, 3];
        const nonChoiceSpeech = [
          'Maybe',
          'Because',
          'Bad',
          'Good',
          'This is a hard question',
          'I have a doubt about this',
          'Wait a minute',
          'Can you repeat that',
          'I do not know',
          '5',
          'number five',
        ];

        for (final phrase in nonChoiceSpeech) {
          expect(
            VoiceInputHandler.handleMcqVoiceInput(
              phrase,
              mcq,
              presentationOrder: presentationOrder,
            ),
            isNull,
            reason:
                'Ordinary speech "$phrase" must not falsely select an option',
          );
        }
      },
    );

    testWidgets(
      'LessonContentRenderer maps spoken Option A-D through shuffled order and re-randomizes on retry',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canSpeakProvider.overrideWithValue(false),
              canListenProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LessonContentRenderer(content: mcq, onNext: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final state =
            tester.state(find.byType(LessonContentRenderer)) as dynamic;
        final order1 = List<int>.from(state.presentationOrder as List<int>);
        expect(order1.toSet(), equals({0, 1, 2, 3}));

        // Verify spoken "Option A", "Option B", "Option C", "Option D" map to order1[0..3]
        const spokenInputs = ['Option A', 'Option B', 'Option C', 'Option D'];
        for (int slot = 0; slot < 4; slot++) {
          state.handleVoiceInput(spokenInputs[slot]);
          await tester.pumpAndSettle();
          expect(state.selectedMcq, equals(order1[slot]));
        }

        // Select the slot where correctAnswer (index 1, 'Beta') is currently displayed
        final correctSlot1 = order1.indexOf(mcq.correctAnswer);
        state.handleVoiceInput(spokenInputs[correctSlot1]);
        await tester.pumpAndSettle();
        expect(state.selectedMcq, equals(mcq.correctAnswer));

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        expect(find.text('Correct!'), findsOneWidget);

        // Tap 'Try Again' to retry the same item and verify a fresh permutation + updated voice mapping
        await tester.tap(find.text('Try Again'));
        await tester.pumpAndSettle();

        final order2 = List<int>.from(state.presentationOrder as List<int>);
        expect(order2.toSet(), equals({0, 1, 2, 3}));
        expect(order2, isNot(equals(order1)));
        expect(state.selectedMcq, isNull);

        // Spoken "Option A" on retry now selects order2[0]
        state.handleVoiceInput('Option A');
        await tester.pumpAndSettle();
        expect(state.selectedMcq, equals(order2[0]));
      },
    );

    testWidgets(
      'QuestionContentRenderer maps spoken Option A-D through shuffled order and re-randomizes on retry',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              canSpeakProvider.overrideWithValue(false),
              canListenProvider.overrideWithValue(false),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: QuestionContentRenderer(content: mcq, onNext: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final state =
            tester.state(find.byType(QuestionContentRenderer)) as dynamic;
        final order1 = List<int>.from(state.presentationOrder as List<int>);
        expect(order1.toSet(), equals({0, 1, 2, 3}));

        const spokenInputs = ['Option A', 'Option B', 'Option C', 'Option D'];
        for (int slot = 0; slot < 4; slot++) {
          state.handleVoiceInput(spokenInputs[slot]);
          await tester.pumpAndSettle();
          expect(state.selectedMcq, equals(order1[slot]));
        }

        // Retry via retryQuestion() and verify fresh permutation and updated voice mapping
        state.retryQuestion();
        await tester.pumpAndSettle();

        final order2 = List<int>.from(state.presentationOrder as List<int>);
        expect(order2.toSet(), equals({0, 1, 2, 3}));
        expect(order2, isNot(equals(order1)));
        expect(state.selectedMcq, isNull);

        for (int slot = 0; slot < 4; slot++) {
          state.handleVoiceInput(spokenInputs[slot]);
          await tester.pumpAndSettle();
          expect(state.selectedMcq, equals(order2[slot]));
        }
      },
    );
  });
}
