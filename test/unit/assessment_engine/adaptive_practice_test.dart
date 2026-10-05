import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/services/assessment/adaptive_practice_service.dart';

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
  });
}
