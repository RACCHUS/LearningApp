import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_event.dart';

void main() {
  group('LearningEvent', () {
    test('constructs with defaults and auto-generated id/timestamp', () {
      final before = DateTime.now().toUtc();
      final event = LearningEvent(
        eventType: 'review',
        itemType: 'term',
        itemId: 'item-123',
      );
      final after = DateTime.now().toUtc();

      expect(event.id, isNotEmpty);
      expect(event.eventType, 'review');
      expect(event.itemType, 'term');
      expect(event.itemId, 'item-123');
      expect(event.occurredAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(event.occurredAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      expect(event.hintsUsed, 0);
      expect(event.metadata, isEmpty);
    });

    test('serializes to and from JSON preserving all fields', () {
      final now = DateTime.utc(2026, 11, 2, 14, 30, 0);
      final event = LearningEvent(
        id: 'event-uuid-1',
        userId: 'user-uuid-1',
        occurredAt: now,
        eventType: 'question_answered',
        itemType: 'mcq',
        itemId: 'question-456',
        itemVersion: 'v1.0',
        contextId: 'lesson-789',
        sessionId: 'session-abc',
        rating: 3,
        score: 1.0,
        response: {'selected_option': 2},
        presentedOrder: [2, 0, 1, 3],
        latencyMs: 1450,
        hintsUsed: 1,
        confidence: 2,
        schedulerStateBefore: {'stability': 2.5, 'difficulty': 4.0},
        schedulerStateAfter: {'stability': 5.8, 'difficulty': 3.8},
        metadata: {'platform': 'web'},
        appVersion: '2.0.0',
      );

      final json = event.toJson();
      expect(json['id'], 'event-uuid-1');
      expect(json['user_id'], 'user-uuid-1');
      expect(json['occurred_at'], now.toIso8601String());
      expect(json['event_type'], 'question_answered');
      expect(json['item_type'], 'mcq');
      expect(json['item_id'], 'question-456');
      expect(json['presented_order'], [2, 0, 1, 3]);
      expect(json['score'], 1.0);
      expect(json['latency_ms'], 1450);

      final parsed = LearningEvent.fromJson(json);
      expect(parsed.id, event.id);
      expect(parsed.userId, event.userId);
      expect(parsed.occurredAt, event.occurredAt);
      expect(parsed.eventType, event.eventType);
      expect(parsed.itemType, event.itemType);
      expect(parsed.itemId, event.itemId);
      expect(parsed.presentedOrder, [2, 0, 1, 3]);
      expect(parsed.score, 1.0);
      expect(parsed.latencyMs, 1450);
      expect(parsed.hintsUsed, 1);
      expect(parsed.schedulerStateBefore?['stability'], 2.5);
      expect(parsed.schedulerStateAfter?['difficulty'], 3.8);
      expect(parsed.metadata['platform'], 'web');
      expect(parsed.appVersion, '2.0.0');
    });
  });
}
