import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/community/spam_rate_limiter.dart';

void main() {
  group('SpamRateLimiter (ECO-01, Invariant 4)', () {
    late SpamRateLimiter limiter;

    setUp(() {
      limiter = SpamRateLimiter(
        maxQuestionsPerHour: 3,
        maxAnswersPerHour: 5,
        minContentLength: 20,
        maxContentLength: 200,
      );
    });

    test('allows compliant submissions within bounds', () {
      final result = limiter.validateQuestionSubmission(
        userId: 'user-1',
        title: 'Valid Question Title Here',
        body: 'This is a substantive question body with plenty of character details.',
      );
      expect(result.isAllowed, isTrue);
    });

    test('rejects questions below minimum character length', () {
      final result = limiter.validateQuestionSubmission(
        userId: 'user-1',
        title: 'Too',
        body: 'short',
      );
      expect(result.isAllowed, isFalse);
      expect(result.rejectionReason, contains('Content too brief'));
    });

    test('rejects questions exceeding maximum character length', () {
      final longBody = 'A' * 250;
      final result = limiter.validateQuestionSubmission(
        userId: 'user-1',
        title: 'Valid Title',
        body: longBody,
      );
      expect(result.isAllowed, isFalse);
      expect(result.rejectionReason, contains('exceeds character limit'));
    });

    test('detects and rejects duplicate submissions via fingerprinting', () {
      const title = 'What is an emergency action plan?';
      const body = 'Detailed procedures for workplace fire evacuations under OSHA 29 CFR 1910.38.';

      limiter.recordQuestionSubmission(userId: 'user-1', title: title, body: body);

      final duplicateResult = limiter.validateQuestionSubmission(
        userId: 'user-1',
        title: title,
        body: body,
      );
      expect(duplicateResult.isAllowed, isFalse);
      expect(duplicateResult.rejectionReason, contains('Duplicate submission detected'));
    });

    test('enforces hourly rate limits', () {
      final now = DateTime(2026, 10, 31, 12, 0);

      // Submit 3 allowed questions
      for (int i = 0; i < 3; i++) {
        limiter.recordQuestionSubmission(
          userId: 'user-2',
          title: 'Question Title $i for testing',
          body: 'Distinct substantive body text for question number $i here.',
          now: now.add(Duration(minutes: i * 5)),
        );
      }

      // 4th question exceeds limit
      final blocked = limiter.validateQuestionSubmission(
        userId: 'user-2',
        title: 'Fourth Question Attempt',
        body: 'Another distinct body attempting to exceed the limit.',
        now: now.add(const Duration(minutes: 20)),
      );

      expect(blocked.isAllowed, isFalse);
      expect(blocked.rejectionReason, contains('rate limit exceeded'));
    });
  });
}
