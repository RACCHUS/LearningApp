import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/screens/assessment/adaptive_practice_screen.dart';
import 'package:learning_pwa/services/assessment/adaptive_practice_service.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';

void main() {
  group('Phase E: AdaptivePracticeService (CAT-Style Testing) Tests', () {
    final now = DateTime.now();
    final service = AdaptivePracticeService();

    final beginnerItem = AssessmentItem(
      id: 'item-easy',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'What does CIA stand for?',
      difficulty: 'beginner',
      createdAt: now,
      updatedAt: now,
    );

    final intermediateItem = AssessmentItem(
      id: 'item-med',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Compare symmetric vs asymmetric cryptography.',
      difficulty: 'intermediate',
      createdAt: now,
      updatedAt: now,
    );

    final advancedItem = AssessmentItem(
      id: 'item-hard',
      interactionType: AssessmentInteractionType.singleChoice,
      prompt: 'Analyze side-channel timing attack vulnerabilities in RSA implementations.',
      difficulty: 'advanced',
      createdAt: now,
      updatedAt: now,
    );

    test('Initializes session at neutral ability baseline and uncalibrated SE', () {
      final state = service.initSession(
        userId: 'usr-123',
        targetVersionId: 'tv-sy0-701',
      );

      expect(state.theta, equals(0.0));
      expect(state.standardError, equals(1.0));
      expect(state.itemCount, equals(0));
      expect(state.isSessionComplete, isFalse);
    });

    test('Correct response increases theta and reduces standard error', () {
      var state = service.initSession(
        userId: 'usr-123',
        targetVersionId: 'tv-sy0-701',
      );

      state = service.recordResponse(
        currentState: state,
        item: intermediateItem,
        userResponse: 'correct_ans',
        isCorrect: true,
      );

      // Theta should increase from 0.0
      expect(state.theta, greaterThan(0.0));
      // Standard error should decrease below initial 1.0
      expect(state.standardError, lessThan(1.0));
      expect(state.itemCount, equals(1));
      expect(state.correctCount, equals(1));
    });

    test('Incorrect response decreases theta', () {
      var state = service.initSession(
        userId: 'usr-123',
        targetVersionId: 'tv-sy0-701',
      );

      state = service.recordResponse(
        currentState: state,
        item: intermediateItem,
        userResponse: 'wrong_ans',
        isCorrect: false,
      );

      // Theta should decrease below 0.0
      expect(state.theta, lessThan(0.0));
      expect(state.standardError, lessThan(1.0));
      expect(state.itemCount, equals(1));
      expect(state.correctCount, equals(0));
    });

    test('Selects next item targeting difficulty closest to current theta', () {
      final pool = [beginnerItem, intermediateItem, advancedItem];

      // At baseline theta = 0.0, intermediate item (b = 0.0) is the closest
      var state = service.initSession(
        userId: 'usr-123',
        targetVersionId: 'tv-sy0-701',
      );

      var nextItem = service.selectNextItem(state: state, pool: pool);
      expect(nextItem?.id, equals('item-med'));

      // If theta rises to +1.2 after high performance, advanced item should be selected
      state = state.copyWith(theta: 1.2, responses: []);
      nextItem = service.selectNextItem(state: state, pool: pool);
      expect(nextItem?.id, equals('item-hard'));

      // If theta drops to -1.5, beginner item should be selected
      state = state.copyWith(theta: -1.5, responses: []);
      nextItem = service.selectNextItem(state: state, pool: pool);
      expect(nextItem?.id, equals('item-easy'));
    });

    testWidgets(
      'AdaptivePracticeScreen generates fresh attempt nonces across consecutive items and on retry/re-presentation',
      (WidgetTester tester) async {
        final itemPool = [
          AssessmentItem(
            id: 'cat-item-1',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Which protocol provides encrypted remote terminal access?',
            difficulty: 'intermediate',
            options: const ['SSH', 'Telnet', 'FTP', 'HTTP'],
            correctAnswer: {'index': 0},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-item-2',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Which layer of the OSI model handles routing?',
            difficulty: 'advanced',
            options: const ['Network', 'Data Link', 'Transport', 'Session'],
            correctAnswer: {'index': 0},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-item-3',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Which algorithm is an asymmetric cipher?',
            difficulty: 'beginner',
            options: const ['RSA', 'AES', 'ChaCha20', '3DES'],
            correctAnswer: {'index': 0},
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: AdaptivePracticeScreen(
                targetVersionId: 'tv-sy0-701',
                targetTitle: 'Security+ Practice',
                itemPool: itemPool,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final screenState = tester.state<AdaptivePracticeScreenState>(
          find.byType(AdaptivePracticeScreen),
        );
        var rendererState = tester.state<AssessmentItemRendererState>(
          find.byType(AssessmentItemRenderer),
        );

        final firstItemId = screenState.currentItem!.id;
        final firstNonce = screenState.attemptNonce;
        final firstOrder = List<int>.from(rendererState.presentationOrder);
        expect(firstOrder.length, 4);

        // Retrying or re-presenting the current item must generate a fresh nonce
        // and a distinct option permutation.
        screenState.retryCurrentQuestion();
        await tester.pumpAndSettle();

        rendererState = tester.state<AssessmentItemRendererState>(
          find.byType(AssessmentItemRenderer),
        );
        final retryNonce = screenState.attemptNonce;
        final retryOrder = List<int>.from(rendererState.presentationOrder);

        expect(retryNonce, isNot(equals(firstNonce)));
        expect(
          McqOptions.listsEqual(firstOrder, retryOrder),
          isFalse,
          reason:
              'Retrying the current item in AdaptivePracticeScreen must produce a new option permutation',
        );

        // Re-presenting the same item via presentItem() also advances the nonce
        // and produces a fresh permutation.
        screenState.presentItem(screenState.currentItem!);
        await tester.pumpAndSettle();

        rendererState = tester.state<AssessmentItemRendererState>(
          find.byType(AssessmentItemRenderer),
        );
        final rePresentedNonce = screenState.attemptNonce;
        final rePresentedOrder = List<int>.from(rendererState.presentationOrder);

        expect(rePresentedNonce, isNot(equals(retryNonce)));
        expect(
          McqOptions.listsEqual(retryOrder, rePresentedOrder),
          isFalse,
          reason:
              'Re-presenting the same item in AdaptivePracticeScreen must produce a fresh permutation',
        );

        // Advancing to the next item in the session must also advance the nonce
        // and never suffer from XOR cancellation across consecutive items.
        rendererState.selectOptionByVoice('Option A');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit Answer'));
        await tester.pumpAndSettle();

        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Next Question'), findsOneWidget);

        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererState = tester.state<AssessmentItemRendererState>(
          find.byType(AssessmentItemRenderer),
        );
        final secondItemId = screenState.currentItem!.id;
        final secondNonce = screenState.attemptNonce;
        final secondOrder = List<int>.from(rendererState.presentationOrder);

        expect(secondItemId, isNot(equals(firstItemId)));
        expect(secondNonce, isNot(equals(rePresentedNonce)));
        expect(secondOrder.length, 4);

        // Verify across all 3 consecutive 4-option items that effective seeds
        // and permutations are not collapsed by XOR cancellation.
        rendererState.selectOptionByVoice('Option A');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit Answer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererState = tester.state<AssessmentItemRendererState>(
          find.byType(AssessmentItemRenderer),
        );
        final thirdItemId = screenState.currentItem!.id;
        final thirdNonce = screenState.attemptNonce;
        final thirdOrder = List<int>.from(rendererState.presentationOrder);

        expect(thirdItemId, isNot(equals(secondItemId)));
        expect(thirdNonce, isNot(equals(secondNonce)));

        final allSameBetweenFirstAndSecond =
            McqOptions.listsEqual(rePresentedOrder, secondOrder);
        final allSameBetweenSecondAndThird =
            McqOptions.listsEqual(secondOrder, thirdOrder);
        expect(
          allSameBetweenFirstAndSecond && allSameBetweenSecondAndThird,
          isFalse,
          reason:
              'Consecutive 4-option items in AdaptivePracticeScreen must not collapse to identical permutations',
        );
      },
    );
  });
}

