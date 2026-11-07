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
      prompt:
          'Analyze side-channel timing attack vulnerabilities in RSA implementations.',
      difficulty: 'advanced',
      createdAt: now,
      updatedAt: now,
    );

    test(
      'Initializes session at neutral ability baseline and uncalibrated SE',
      () {
        final state = service.initSession(
          userId: 'usr-123',
          targetVersionId: 'tv-sy0-701',
        );

        expect(state.theta, equals(0.0));
        expect(state.standardError, equals(1.0));
        expect(state.itemCount, equals(0));
        expect(state.isSessionComplete, isFalse);
      },
    );

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
            responseSpec: const {
              'options': ['SSH', 'Telnet', 'FTP', 'HTTP'],
            },
            scoringSpec: const {'correct_index': 0},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-item-2',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Which layer of the OSI model handles routing?',
            difficulty: 'advanced',
            responseSpec: const {
              'options': ['Network', 'Data Link', 'Transport', 'Session'],
            },
            scoringSpec: const {'correct_index': 0},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-item-3',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Which algorithm is an asymmetric cipher?',
            difficulty: 'beginner',
            responseSpec: const {
              'options': ['RSA', 'AES', 'ChaCha20', '3DES'],
            },
            scoringSpec: const {'correct_index': 0},
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: AdaptivePracticeScreen(
                userId: 'usr-123',
                targetVersionId: 'tv-sy0-701',
                targetTitle: 'Security+ Practice',
                candidatePool: itemPool,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final screenState =
            tester.state(find.byType(AdaptivePracticeScreen)) as dynamic;
        var rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;

        final firstItemId = (screenState.currentItem as AssessmentItem).id;
        final firstNonce = screenState.attemptNonce as int;
        final firstOrder = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );
        expect(firstOrder.length, 4);

        // Retrying or re-presenting the current item must generate a fresh nonce
        // and a distinct option permutation.
        screenState.retryCurrentQuestion();
        await tester.pumpAndSettle();

        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final retryNonce = screenState.attemptNonce as int;
        final retryOrder = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

        expect(retryNonce, isNot(equals(firstNonce)));
        expect(
          McqOptions.listsEqual(firstOrder, retryOrder),
          isFalse,
          reason:
              'Retrying the current item in AdaptivePracticeScreen must produce a new option permutation',
        );

        // Re-presenting the same item via presentItem() also advances the nonce
        // and produces a fresh permutation.
        screenState.presentItem(screenState.currentItem as AssessmentItem);
        await tester.pumpAndSettle();

        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final rePresentedNonce = screenState.attemptNonce as int;
        final rePresentedOrder = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

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
        await tester.ensureVisible(find.text('Check Answer'));
        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();

        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Next Question'), findsOneWidget);

        await tester.ensureVisible(find.text('Next Question'));
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final secondItemId = (screenState.currentItem as AssessmentItem).id;
        final secondNonce = screenState.attemptNonce as int;
        final secondOrder = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

        expect(secondItemId, isNot(equals(firstItemId)));
        expect(secondNonce, isNot(equals(rePresentedNonce)));
        expect(secondOrder.length, 4);

        // Verify across all 3 consecutive 4-option items that effective seeds
        // and permutations are not collapsed by XOR cancellation.
        rendererState.selectOptionByVoice('Option A');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Check Answer'));
        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Next Question'));
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final thirdItemId = (screenState.currentItem as AssessmentItem).id;
        final thirdNonce = screenState.attemptNonce as int;
        final thirdOrder = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

        expect(thirdItemId, isNot(equals(secondItemId)));
        expect(thirdNonce, isNot(equals(secondNonce)));

        final allSameBetweenFirstAndSecond = McqOptions.listsEqual(
          rePresentedOrder,
          secondOrder,
        );
        final allSameBetweenSecondAndThird = McqOptions.listsEqual(
          secondOrder,
          thirdOrder,
        );
        expect(
          allSameBetweenFirstAndSecond,
          isFalse,
          reason:
              'Item 2 in AdaptivePracticeScreen receives avoidOrder from Item 1 and must not share the same permutation',
        );
        expect(
          allSameBetweenSecondAndThird,
          isFalse,
          reason:
              'Item 3 in AdaptivePracticeScreen receives avoidOrder from Item 2 and must not share the same permutation',
        );
      },
    );

    testWidgets(
      'AdaptivePracticeScreen carries previousPresentationOrder into AssessmentItemRenderer avoidOrder and guarantees distinct order across consecutive items with identical option lists',
      (tester) async {
        final now = DateTime.now().toUtc();
        const sharedOptions = ['Allow', 'Deny', 'None of the above'];
        final itemPool = <AssessmentItem>[
          AssessmentItem(
            id: 'cat-shared-1',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Default firewall policy for unmatched inbound traffic?',
            difficulty: 'beginner',
            responseSpec: const {'options': sharedOptions},
            scoringSpec: const {'correct_index': 1},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-shared-2',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Implicit rule at the end of an access control list?',
            difficulty: 'intermediate',
            responseSpec: const {'options': sharedOptions},
            scoringSpec: const {'correct_index': 1},
            createdAt: now,
            updatedAt: now,
          ),
          AssessmentItem(
            id: 'cat-shared-3',
            interactionType: AssessmentInteractionType.singleChoice,
            prompt: 'Zero-trust baseline action before authentication?',
            difficulty: 'advanced',
            responseSpec: const {'options': sharedOptions},
            scoringSpec: const {'correct_index': 1},
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: AdaptivePracticeScreen(
                userId: 'usr-123',
                targetVersionId: 'tv-sy0-701',
                targetTitle: 'Security+ Practice',
                candidatePool: itemPool,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final screenState =
            tester.state(find.byType(AdaptivePracticeScreen)) as dynamic;
        var rendererWidget = tester.widget<AssessmentItemRenderer>(
          find.byType(AssessmentItemRenderer),
        );
        var rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;

        final item1Order = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );
        expect(item1Order.last, 2, reason: 'Anchor option stays pinned at end');
        expect(screenState.lastPresentationOrder, isNotNull);
        expect(
          McqOptions.listsEqual(
            List<int>.from(screenState.lastPresentationOrder as List<int>),
            item1Order,
          ),
          isTrue,
          reason:
              'AdaptivePracticeScreen must record the actual rendered presentationOrder from AssessmentItemRenderer',
        );

        // Advance to Item 2 (new ValueKey creates fresh AssessmentItemRenderer state)
        rendererState.selectOptionByVoice('Option A');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Check Answer'));
        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Next Question'));
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererWidget = tester.widget<AssessmentItemRenderer>(
          find.byType(AssessmentItemRenderer),
        );
        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final item2Order = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

        expect(rendererWidget.avoidOrder, isNotNull);
        expect(
          McqOptions.listsEqual(rendererWidget.avoidOrder!, item1Order),
          isTrue,
          reason:
              'AssessmentItemRenderer for Item 2 must receive Item 1 presentationOrder as avoidOrder',
        );
        expect(
          McqOptions.listsEqual(item1Order, item2Order),
          isFalse,
          reason:
              'Item 2 must render a distinct option permutation from Item 1 even with a fresh ValueKey',
        );
        expect(item2Order.last, 2, reason: 'Anchor option stays pinned at end');
        expect(screenState.lastPresentationOrder, isNotNull);
        expect(
          McqOptions.listsEqual(
            List<int>.from(screenState.lastPresentationOrder as List<int>),
            item2Order,
          ),
          isTrue,
        );

        // Advance to Item 3
        rendererState.selectOptionByVoice('Option A');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Check Answer'));
        await tester.tap(find.text('Check Answer'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Next Question'));
        await tester.tap(find.text('Next Question'));
        await tester.pumpAndSettle();

        rendererWidget = tester.widget<AssessmentItemRenderer>(
          find.byType(AssessmentItemRenderer),
        );
        rendererState =
            tester.state(find.byType(AssessmentItemRenderer)) as dynamic;
        final item3Order = List<int>.from(
          rendererState.presentationOrder as List<int>,
        );

        expect(rendererWidget.avoidOrder, isNotNull);
        expect(
          McqOptions.listsEqual(rendererWidget.avoidOrder!, item2Order),
          isTrue,
          reason:
              'AssessmentItemRenderer for Item 3 must receive Item 2 presentationOrder as avoidOrder',
        );
        expect(
          McqOptions.listsEqual(item2Order, item3Order),
          isFalse,
          reason:
              'Item 3 must render a distinct option permutation from Item 2 even with a fresh ValueKey',
        );
        expect(item3Order.last, 2, reason: 'Anchor option stays pinned at end');
      },
    );
  });
}
