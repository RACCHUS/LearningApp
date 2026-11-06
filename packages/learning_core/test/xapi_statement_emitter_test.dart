import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('XApiStatementEmitter (ADL xAPI 1.0.3)', () {
    final timestamp = DateTime.parse('2026-11-06T12:00:00Z');

    test('emits compliant xAPI statement from review_completed event with FSRS context', () {
      final event = LearningEventCore(
        id: 'evt-xapi-001',
        idempotencyKey: 'idem-key-999',
        sessionId: 'sess-abc-123',
        clientSeq: 4,
        userId: 'user-learner-555',
        eventType: 'review_completed',
        clientOccurredAt: timestamp,
        payload: {
          'item_id': 'item-math-integral-01',
          'lesson_id': 'lesson-calculus-foundations',
          'is_correct': true,
          'response_time_ms': 12500,
          'fsrs_stability': 4.25,
          'fsrs_difficulty': 5.10,
          'fsrs_retrievability': 0.94,
        },
      );

      final statement = XApiStatementEmitter.emitStatement(event);

      expect(statement['id'], equals('evt-xapi-001'));
      expect(statement['timestamp'], equals('2026-11-06T12:00:00.000Z'));

      // Actor
      final actor = statement['actor'] as Map<String, dynamic>;
      expect(actor['objectType'], equals('Agent'));
      expect(actor['account']['name'], equals('user-learner-555'));

      // Verb
      final verb = statement['verb'] as Map<String, dynamic>;
      expect(verb['id'], equals('http://adlnet.gov/expapi/verbs/answered'));
      expect(verb['display']['en-US'], equals('answered'));

      // Object
      final object = statement['object'] as Map<String, dynamic>;
      expect(object['id'], equals('https://learningapp.org/activities/items/item-math-integral-01'));
      expect(object['definition']['type'], equals('http://adlnet.gov/expapi/activities/cmi.interaction'));

      // Result
      final result = statement['result'] as Map<String, dynamic>;
      expect(result['success'], isTrue);
      expect(result['completion'], isTrue);
      expect(result['score']['scaled'], equals(1.0));
      expect(result['duration'], equals('PT13S'));

      // Context & Extensions
      final context = statement['context'] as Map<String, dynamic>;
      final extensions = context['extensions'] as Map<String, dynamic>;
      expect(extensions['https://learningapp.org/xapi/ext/session-id'], equals('sess-abc-123'));
      expect(extensions['https://learningapp.org/xapi/ext/client-seq'], equals(4));
      expect(extensions['https://learningapp.org/xapi/ext/idempotency-key'], equals('idem-key-999'));
      expect(extensions['https://learningapp.org/xapi/ext/fsrs-stability'], equals(4.25));
      expect(extensions['https://learningapp.org/xapi/ext/fsrs-retrievability'], equals(0.94));

      // Parent Lesson Context Activity
      final parentActivities = context['contextActivities']['parent'] as List;
      expect(parentActivities.length, equals(1));
      expect(parentActivities[0]['id'], equals('https://learningapp.org/activities/lessons/lesson-calculus-foundations'));
    });

    test('maps assessment_passed and assessment_failed verbs accurately', () {
      final passedEvent = LearningEventCore(
        id: 'evt-pass-01',
        idempotencyKey: 'idem-pass',
        sessionId: 'sess-1',
        clientSeq: 10,
        eventType: 'assessment_passed',
        clientOccurredAt: timestamp,
        payload: {
          'assessment_id': 'asmt-florida-civics',
          'score': 0.88,
          'is_correct': true,
        },
      );

      final passStatement = XApiStatementEmitter.emitStatement(passedEvent);
      expect(passStatement['verb']['id'], equals('http://adlnet.gov/expapi/verbs/passed'));
      expect(passStatement['result']['score']['scaled'], equals(0.88));

      final failedEvent = LearningEventCore(
        id: 'evt-fail-01',
        idempotencyKey: 'idem-fail',
        sessionId: 'sess-1',
        clientSeq: 11,
        eventType: 'assessment_failed',
        clientOccurredAt: timestamp,
        payload: {
          'assessment_id': 'asmt-florida-civics',
          'score': 0.52,
          'is_correct': false,
        },
      );

      final failStatement = XApiStatementEmitter.emitStatement(failedEvent);
      expect(failStatement['verb']['id'], equals('http://adlnet.gov/expapi/verbs/failed'));
      expect(failStatement['result']['success'], isFalse);
    });

    test('formatIsoDuration formats durations conforming to ISO 8601', () {
      expect(XApiStatementEmitter.formatIsoDuration(seconds: 0), equals('PT0S'));
      expect(XApiStatementEmitter.formatIsoDuration(seconds: 45), equals('PT45S'));
      expect(XApiStatementEmitter.formatIsoDuration(seconds: 120), equals('PT2M'));
      expect(XApiStatementEmitter.formatIsoDuration(seconds: 125), equals('PT2M5S'));
      expect(XApiStatementEmitter.formatIsoDuration(seconds: 3661), equals('PT1H1M1S'));
      expect(XApiStatementEmitter.formatIsoDuration(milliseconds: 14200), equals('PT14S'));
    });
  });
}

