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

    test('events are retained when RPC returns non-success status', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      // Return status failure
      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          return {
            'status': 'error',
            'processed_count': 0,
          };
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

    test('events are retained when RPC returns success with zero processed_count', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          return {
            'status': 'success',
            'processed_count': 0,
          };
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event1 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-1');
      final event2 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-2');

      await outbox.enqueueAll([event1, event2]);
      final flushed = await outbox.flush();

      expect(flushed, 0);
      expect(await outbox.pendingCount, 2);
    });

    test('events are retained when RPC returns success with missing processed_count', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          return {
            'status': 'success',
          };
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event1 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-1');
      final event2 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-2');

      await outbox.enqueueAll([event1, event2]);
      final flushed = await outbox.flush();

      expect(flushed, 0);
      expect(await outbox.pendingCount, 2);
    });

    test('events are retained when RPC returns success with partial processed_count', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          return {
            'status': 'success',
            'processed_count': 1, // Only 1 of 2 processed
          };
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event1 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-1');
      final event2 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-2');

      await outbox.enqueueAll([event1, event2]);
      final flushed = await outbox.flush();

      expect(flushed, 0);
      expect(await outbox.pendingCount, 2);
    });

    test('events are removed on exact full-batch acknowledgment', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      fakeSupabase.rpcHandler = (fn, {params}) {
        if (fn == 'record_events') {
          return {
            'status': 'success',
            'processed_count': 2, // Exactly matches batch size of 2
          };
        }
        return null;
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);
      final event1 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-1');
      final event2 = LearningEvent(eventType: 'review', itemType: 'term', itemId: 'term-2');

      await outbox.enqueueAll([event1, event2]);
      final flushed = await outbox.flush();

      expect(flushed, 2);
      expect(await outbox.pendingCount, 0);
    });

    test('account isolation: queues are strictly partitioned and not cross-flushed', () async {
      final outbox = LearningEventOutbox(supabase: fakeSupabase);

      // Start offline so events buffer in local queue
      bool isOnline = false;
      List<dynamic>? lastFlushedPayload;
      fakeSupabase.rpcHandler = (fn, {params}) {
        if (!isOnline) {
          throw Exception('Simulated offline network error');
        }
        if (fn == 'record_events') {
          lastFlushedPayload = params?['p_events'] as List<dynamic>?;
          return {
            'status': 'success',
            'processed_count': lastFlushedPayload?.length ?? 0,
            'awarded_xp': 0,
          };
        }
        return null;
      };

      // 1. Account A enqueues event while offline
      fakeSupabase.auth.currentUser = const User(
        id: 'account-a-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );
      final eventA = LearningEvent(
        userId: 'account-a-id',
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-a',
      );
      await outbox.enqueue(eventA);
      expect(await outbox.getPendingCount(userId: 'account-a-id'), 1);

      // 2. Account switches to Account B while still offline
      fakeSupabase.auth.currentUser = const User(
        id: 'account-b-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );
      final eventB = LearningEvent(
        userId: 'account-b-id',
        eventType: 'review',
        itemType: 'term',
        itemId: 'term-b',
      );
      await outbox.enqueue(eventB);

      // Both queues are isolated and held locally
      expect(await outbox.getPendingCount(userId: 'account-b-id'), 1);
      expect(await outbox.getPendingCount(userId: 'account-a-id'), 1);

      // 3. Network comes back online while Account B is active
      isOnline = true;
      final flushedB = await outbox.flush();
      expect(flushedB, 1);
      expect(lastFlushedPayload?.first['item_id'], 'term-b');
      expect(lastFlushedPayload?.first['user_id'], 'account-b-id');

      // Account B queue is drained, Account A queue remains strictly untouched
      expect(await outbox.getPendingCount(userId: 'account-b-id'), 0);
      expect(await outbox.getPendingCount(userId: 'account-a-id'), 1);

      // 4. Switch back to Account A and flush
      fakeSupabase.auth.currentUser = const User(
        id: 'account-a-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

      final flushedA = await outbox.flush();
      expect(flushedA, 1);
      expect(lastFlushedPayload?.first['item_id'], 'term-a');
      expect(lastFlushedPayload?.first['user_id'], 'account-a-id');
      expect(await outbox.getPendingCount(userId: 'account-a-id'), 0);
    });

    test('concurrent enqueue operations do not overwrite or lose events', () async {
      fakeSupabase.auth.currentUser = const User(
        id: 'concurrent-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );
      // Keep offline so they buffer
      fakeSupabase.rpcHandler = (fn, {params}) {
        throw Exception('Offline');
      };

      final outbox = LearningEventOutbox(supabase: fakeSupabase);

      // Launch 20 concurrent enqueues
      await Future.wait(List.generate(20, (i) {
        return outbox.enqueue(
          LearningEvent(
            userId: 'concurrent-user-id',
            eventType: 'review',
            itemType: 'term',
            itemId: 'item-$i',
          ),
        );
      }));

      final queued = await outbox.getQueuedEvents();
      expect(queued.length, 20);
      final itemIds = queued.map((e) => e.itemId).toSet();
      expect(itemIds.length, 20);
    });
  });
}
