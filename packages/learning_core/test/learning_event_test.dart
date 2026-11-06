import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('LearningEventCore', () {
    test('computes deterministic canonical payload SHA-256 independent of key order', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0, 0);

      final event1 = LearningEventCore(
        id: 'evt-1',
        idempotencyKey: 'idem-1',
        sessionId: 'sess-1',
        clientSeq: 1,
        eventType: 'review_completed',
        clientOccurredAt: now,
        payload: {
          'item_id': 'card-101',
          'rating': 3,
          'latency_ms': 1420,
        },
      );

      // Same semantic payload, inverted key order
      final event2 = LearningEventCore(
        id: 'evt-2',
        idempotencyKey: 'idem-1',
        sessionId: 'sess-1',
        clientSeq: 1,
        eventType: 'review_completed',
        clientOccurredAt: now,
        payload: {
          'latency_ms': 1420,
          'item_id': 'card-101',
          'rating': 3,
        },
      );

      final hash1 = event1.computeCanonicalPayloadSha256();
      final hash2 = event2.computeCanonicalPayloadSha256();

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // 32-byte hex
    });

    test('serializes and deserializes cleanly through JSON', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0, 0);
      final event = LearningEventCore(
        id: 'evt-3',
        idempotencyKey: 'idem-2',
        sessionId: 'sess-2',
        clientSeq: 5,
        userId: 'user-77',
        eventType: 'assessment_completed',
        clientOccurredAt: now,
        payload: {'score': 85},
      );

      final json = event.toJson();
      final deserialized = LearningEventCore.fromJson(json);

      expect(deserialized.id, equals(event.id));
      expect(deserialized.idempotencyKey, equals(event.idempotencyKey));
      expect(deserialized.sessionId, equals(event.sessionId));
      expect(deserialized.clientSeq, equals(event.clientSeq));
      expect(deserialized.userId, equals('user-77'));
      expect(deserialized.payload['score'], equals(85));
    });
  });

  group('ManifestValidatorCore', () {
    late ManifestValidatorCore validator;

    setUp(() {
      validator = ManifestValidatorCore();
    });

    test('valid YAML manifest passes with zero errors', () {
      const validYaml = '''
manifest_version: "2.1.0"
title: "General Contractor Carpentry Mastery"
authoritative_source: "Florida DBPR Chapter 489"
modules:
  - id: "carp-01"
    title: "Rough Framing"
assessments:
  - id: "q1"
    options: ["A", "B", "C", "D"]
    correct_index: 0
  - id: "q2"
    options: ["A", "B", "C", "D"]
    correct_index: 1
  - id: "q3"
    options: ["A", "B", "C", "D"]
    correct_index: 2
  - id: "q4"
    options: ["A", "B", "C", "D"]
    correct_index: 3
''';

      final result = validator.validateYaml(validYaml);

      expect(result.isValid, isTrue);
      expect(result.errorCount, equals(0));
      expect(result.warningCount, equals(0));
    });

    test('flags missing manifest_version and empty modules list', () {
      const invalidYaml = '''
title: "Empty Manifest"
modules: []
''';

      final result = validator.validateYaml(invalidYaml);

      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.path == 'manifest_version'), isTrue);
      expect(result.issues.any((i) => i.path == 'modules'), isTrue);
    });

    test('warns when single option index exceeds 75% of answers', () {
      const biasedYaml = '''
manifest_version: "2.1.0"
title: "Biased Quiz"
modules:
  - id: "m1"
    title: "M1"
assessments:
  - id: "q1"
    options: ["A", "B", "C", "D"]
    correct_index: 0
  - id: "q2"
    options: ["A", "B", "C", "D"]
    correct_index: 0
  - id: "q3"
    options: ["A", "B", "C", "D"]
    correct_index: 0
  - id: "q4"
    options: ["A", "B", "C", "D"]
    correct_index: 0
''';

      final result = validator.validateYaml(biasedYaml);

      expect(result.warningCount, greaterThan(0));
      expect(result.issues.any((i) => i.message.contains('Answer position bias')), isTrue);
    });
  });
}

