import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_event.dart';
import 'package:learning_pwa/services/offline/learning_event_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LearningEventOutbox', () {
    late FakeSupabaseClient fakeSupabase;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeSupabase = FakeSupabaseClient();
    });

    test('enqueue persists event to local storage', () async {
      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event = LearningEvent(
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-1',
      );

      await outbox.enqueue(event);

      final queued = await outbox.getQueuedEvents();
      expect(queued.length, 1);
      expect(queued.first.id, event.id);
      expect(queued.first.itemId, 'term-1');
      expect(await outbox.pendingCount, 1);
    });

    test('flush does not drain when user is unauthenticated', () async {
      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event = LearningEvent(
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-1',
      );

      await outbox.enqueue(event);
      final flushed = await outbox.flush();

      expect(flushed, 0);
      expect(await outbox.pendingCount, 1);
    });

    test('flush drains events via record_events RPC when authenticated', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      List<dynamic>? receivedPayload;
      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          receivedPayload = params?['p_events'] as List<dynamic>?;
          return {
            'status': 'success',
            'processed_count': receivedPayload?.length ?? 0,
            'awarded_xp': 0,
          };
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event1 = LearningEvent(
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-1',
      );
      final event2 = LearningEvent(
        eventType: 'question_answered',
        itemType: 'mcq',
        itemId: 'mcq-2',
      );

      await outbox.enqueueAll([event1, event2]);
      final flushed = await outbox.flush();

      expect(flushed, 2);
      expect(receivedPayload, isNotNull);
      expect(receivedPayload!.length, 2);
      expect(receivedPayload![0]['item_id'], 'term-1');
      expect(receivedPayload![1]['item_id'], 'mcq-2');
      expect(await outbox.pendingCount, 0);
    });

    test('events are retained when RPC encounters an error', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          throw Exception('Simulated network timeout');
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event = LearningEvent(
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-1',
      );

      await outbox.enqueue(event);
      final flushed = await outbox.flush();

      expect(flushed, 0);
      expect(await outbox.pendingCount, 1);
    });
  });
}
