import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../progress_sync_service_test.mocks.dart';
import '../test_helpers/fake_supabase_client.dart';

/// Progress is marked synced only after the server acknowledges every event
/// of the current learner; anything else keeps the offline queue retryable.
void main() {
  User user(String id) => User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-11-14T00:00:00Z',
      );

  UserProgress completion(String id, {String userId = 'learner-a'}) => UserProgress(
        id: id,
        userId: userId,
        lessonId: 'lesson-$id',
        studyMode: StudyMode.lesson,
        date: DateTime.utc(2026, 11, 14, 10),
        questionsAnswered: 0,
        correctCount: 0,
        lessonCompleted: true,
        studyTimeSeconds: 0,
      );

  late MockHiveService hive;
  late FakeSupabaseClient client;
  late List<UserProgress> queue;
  late Set<String> synced;
  late List<List<Map<String, dynamic>>> batches;

  Map<String, dynamic> ackAll(List events, {String status = 'accepted'}) => {
        'status': 'success',
        'processed_count': events.length,
        'results': [
          for (final e in events) {'idempotency_key': (e as Map)['idempotency_key'], 'status': status},
        ],
      };

  setUp(() {
    hive = MockHiveService();
    client = FakeSupabaseClient(currentUser: user('learner-a'));
    queue = [];
    synced = {};
    batches = [];
    when(hive.getUnsyncedProgress())
        .thenAnswer((_) async => queue.where((p) => !synced.contains(p.id)).toList());
    when(hive.markProgressAsSynced(any)).thenAnswer((inv) async {
      synced.addAll(inv.positionalArguments.first as List<String>);
    });
  });

  void respond(Map<String, dynamic> Function(List events) handler) {
    client.rpcHandler = (fn, {params}) {
      expect(fn, 'record_learner_progress');
      final events = (params!['p_events'] as List).cast<Map<String, dynamic>>();
      batches.add(events);
      return handler(events);
    };
  }

  test('uploads only the signed-in learner\'s events, in batches of at most 25', () async {
    queue = [
      for (var i = 0; i < 30; i++) completion('a$i'),
      completion('b1', userId: 'learner-b'),
    ];
    respond(ackAll);

    await ProgressSyncService(hive, client).syncProgress();

    expect(batches.map((b) => b.length), [25, 5]);
    expect(batches.expand((b) => b).map((e) => e['idempotency_key']), isNot(contains('b1')));
    expect(synced, {for (var i = 0; i < 30; i++) 'a$i'});
    expect(batches.first.first['event_type'], 'lesson_completed');
  });

  test('duplicate_noop acknowledgements also count as synced', () async {
    queue = [completion('a1')];
    respond((events) => ackAll(events, status: 'duplicate_noop'));

    await ProgressSyncService(hive, client).syncProgress();

    expect(synced, {'a1'});
  });

  final failures = <String, Map<String, dynamic> Function(List events)>{
    'a rejected event': (events) => ackAll(events, status: 'rejected'),
    'a partial batch': (events) => {...ackAll(events), 'processed_count': events.length - 1},
    'a mismatched idempotency key': (events) => {
          ...ackAll(events),
          'results': [
            {'idempotency_key': 'someone-else', 'status': 'accepted'},
            ...ackAll(events)['results'].skip(1),
          ],
        },
    'a non-success envelope': (events) => {...ackAll(events), 'status': 'error'},
  };
  for (final entry in failures.entries) {
    test('${entry.key} keeps the whole queue unsynced and reports a SyncException', () async {
      queue = [completion('a1'), completion('a2')];
      respond(entry.value);

      await expectLater(
        ProgressSyncService(hive, client).syncProgress(),
        throwsA(isA<SyncException>()),
      );
      expect(synced, isEmpty);
      verifyNever(hive.markProgressAsSynced(any));
    });
  }

  test('an account switch during sync does not mark the previous learner\'s queue', () async {
    queue = [completion('a1')];
    respond((events) {
      client.auth.currentUser = user('learner-b');
      return ackAll(events);
    });

    await expectLater(
      ProgressSyncService(hive, client).syncProgress(),
      throwsA(isA<SyncException>()),
    );
    expect(synced, isEmpty);
  });

  test('signed out: nothing is sent and nothing is marked', () async {
    client = FakeSupabaseClient();
    queue = [completion('a1')];
    respond(ackAll);

    await ProgressSyncService(hive, client).syncProgress();

    expect(batches, isEmpty);
    expect(synced, isEmpty);
  });

  test('downloading another account\'s progress is refused before any query', () async {
    await expectLater(
      ProgressSyncService(hive, client).downloadProgress('learner-b'),
      throwsA(isA<SyncException>()),
    );
    expect(batches, isEmpty);
    verifyNever(hive.getUnsyncedProgress());
  });
}
