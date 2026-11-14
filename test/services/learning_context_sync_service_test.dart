import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/learning_context_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test_helpers/fake_supabase_client.dart';

/// Cross-device sync of learning contexts and resume pointers: newer side
/// wins, conflicting ids are re-keyed with their pointers, another user's
/// data is never pushed, and a network failure leaves local data untouched.
void main() {
  const testPath = 'build/test_hive_learning_context_sync';
  late Box<LearningContext> contexts;
  late Box<ResumePointer> pointers;
  late _SyncClient client;

  final older = DateTime.utc(2026, 11, 1);
  final newer = DateTime.utc(2026, 11, 10);

  LearningContext ctx(String id, String rootId, DateTime at, {String userId = 'u1', String label = 'Goal'}) =>
      LearningContext(
        id: id,
        userId: userId,
        label: label,
        rootType: ContextRootType.target,
        rootId: rootId,
        lastActiveAt: at,
      );

  ResumePointer ptr(String contextId, String activity, DateTime at) => ResumePointer(
        contextId: contextId,
        kind: ResumableKind.lesson,
        activityId: activity,
        updatedAt: at,
      );

  LearningContextSyncService service() =>
      LearningContextSyncService(client: client, contexts: contexts, pointers: pointers);

  setUpAll(() {
    final dir = Directory(testPath);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Hive.init(testPath);
    if (!Hive.isAdapterRegistered(LearningContextAdapter().typeId)) {
      Hive.registerAdapter(LearningContextAdapter());
    }
    if (!Hive.isAdapterRegistered(ResumePointerAdapter().typeId)) {
      Hive.registerAdapter(ResumePointerAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    final dir = Directory(testPath);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    contexts = await Hive.openBox<LearningContext>('ctx_$stamp');
    pointers = await Hive.openBox<ResumePointer>('ptr_$stamp');
    client = _SyncClient();
  });

  tearDown(() async {
    await contexts.deleteFromDisk();
    await pointers.deleteFromDisk();
  });

  test('signed-out users are skipped with no network calls', () async {
    for (final userId in ['local-user', '']) {
      final report = await service().sync(userId);
      expect(report.skipped, isTrue, reason: userId);
      expect(report.succeeded, isTrue);
    }
    expect(client.calls, isEmpty);
  });

  test('local-only contexts are pushed; remote-only contexts are pulled', () async {
    await contexts.put('local-1', ctx('local-1', 'target-a', older));
    client.rows['learning_contexts'] = [ctx('remote-1', 'target-b', newer).toJson()];

    final report = await service().sync('u1');

    expect(report.succeeded, isTrue);
    expect(report.pushed, 1);
    expect(report.pulled, 1);
    expect(client.upserts['learning_contexts']!.map((r) => r['id']), ['local-1']);
    expect(contexts.get('remote-1')?.rootId, 'target-b');
  });

  test('a newer remote copy wins: local is re-keyed and its resume pointer moves', () async {
    await contexts.put('local-1', ctx('local-1', 'target-a', older, label: 'Old label'));
    await pointers.put('local-1', ptr('local-1', 'lesson-7', older));
    client.rows['learning_contexts'] = [ctx('server-1', 'target-a', newer, label: 'New label').toJson()];

    final report = await service().sync('u1');

    expect(report.rekeyedContextIds, {'local-1': 'server-1'});
    expect(contexts.get('local-1'), isNull);
    expect(contexts.get('server-1')?.label, 'New label');
    expect(pointers.get('local-1'), isNull);
    expect(pointers.get('server-1')?.activityId, 'lesson-7');
    expect(client.upserts['learning_contexts'], isNull, reason: 'the older local copy is not pushed');
  });

  test('a newer local copy wins: it is pushed under the server id', () async {
    await contexts.put('local-1', ctx('local-1', 'target-a', newer, label: 'Local edit'));
    client.rows['learning_contexts'] = [ctx('server-1', 'target-a', older, label: 'Stale').toJson()];

    final report = await service().sync('u1');

    final pushed = client.upserts['learning_contexts']!.single;
    expect(pushed['id'], 'server-1');
    expect(pushed['label'], 'Local edit');
    expect(report.rekeyedContextIds, {'local-1': 'server-1'});
    expect(contexts.get('server-1')?.label, 'Local edit');
  });

  test('another user\'s local contexts and pointers are never pushed', () async {
    await contexts.put('mine', ctx('mine', 'target-a', newer));
    await contexts.put('theirs', ctx('theirs', 'target-z', newer, userId: 'u2'));
    await pointers.put('mine', ptr('mine', 'lesson-1', newer));
    await pointers.put('theirs', ptr('theirs', 'lesson-9', newer));

    await service().sync('u1');

    expect(client.upserts['learning_contexts']!.map((r) => r['id']), ['mine']);
    final pushedPointers = client.upserts['resume_pointers']!;
    expect(pushedPointers.map((r) => r['context_id']), ['mine']);
    expect(pushedPointers.single['user_id'], 'u1');
  });

  test('a newer remote resume pointer replaces the local one; an older one does not', () async {
    await contexts.put('c-new', ctx('c-new', 'target-a', newer));
    await contexts.put('c-old', ctx('c-old', 'target-b', newer));
    await pointers.put('c-new', ptr('c-new', 'local-lesson', older));
    await pointers.put('c-old', ptr('c-old', 'local-lesson', newer));
    client.rows['learning_contexts'] = [
      ctx('c-new', 'target-a', older).toJson(),
      ctx('c-old', 'target-b', older).toJson(),
    ];
    client.rows['resume_pointers'] = [
      {...ptr('c-new', 'remote-lesson', newer).toJson(), 'user_id': 'u1'},
      {...ptr('c-old', 'remote-lesson', older).toJson(), 'user_id': 'u1'},
    ];

    await service().sync('u1');

    expect(pointers.get('c-new')?.activityId, 'remote-lesson');
    expect(pointers.get('c-old')?.activityId, 'local-lesson');
  });

  test('malformed remote rows are ignored without failing the sync', () async {
    client.rows['learning_contexts'] = [
      {'id': '', 'root_id': 'x', 'user_id': 'u1'},
      ctx('good', 'target-a', newer).toJson(),
    ];
    client.rows['resume_pointers'] = [
      {'context_id': 'good', 'activity_id': '', 'user_id': 'u1'},
    ];

    final report = await service().sync('u1');

    expect(report.succeeded, isTrue);
    expect(contexts.keys, ['good']);
    expect(pointers.isEmpty, isTrue);
  });

  test('a network failure reports failure and leaves local data untouched', () async {
    await contexts.put('local-1', ctx('local-1', 'target-a', older));
    await pointers.put('local-1', ptr('local-1', 'lesson-1', older));
    client.failSelects = true;

    final report = await service().sync('u1');

    expect(report.succeeded, isFalse);
    expect(report.error, contains('offline'));
    expect(contexts.keys, ['local-1']);
    expect(pointers.get('local-1')?.activityId, 'lesson-1');
    expect(client.upserts, isEmpty);
  });
}

/// Supports exactly what the sync service uses: `from(t).select().eq().timeout()`
/// and `from(t).upsert(row)`. Records every call and upsert.
class _SyncClient extends FakeSupabaseClient {
  final Map<String, List<Map<String, dynamic>>> rows = {};
  final Map<String, List<Map<String, dynamic>>> upserts = {};
  final List<String> calls = [];
  bool failSelects = false;

  @override
  SupabaseQueryBuilder from(String table) {
    calls.add(table);
    return _Table(this, table);
  }
}

class _Table implements SupabaseQueryBuilder {
  _Table(this.client, this.table);
  final _SyncClient client;
  final String table;

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) =>
      _Rows(client.failSelects ? null : List.of(client.rows[table] ?? const []));

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    client.upserts.putIfAbsent(table, () => []).add(Map<String, dynamic>.from(values as Map));
    return _Rows(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Table.${invocation.memberName}');
}

// Test double with mutable recording state.
// ignore: must_be_immutable
class _Rows implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _Rows(this.data);

  /// null means the request fails as if offline.
  List<Map<String, dynamic>>? data;

  Future<List<Map<String, dynamic>>> get _future => data == null
      ? Future.error(const SocketException('offline'))
      : Future.value(data);

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) {
    data = data?.where((row) => row[column] == value).toList();
    return this;
  }

  @override
  Future<List<Map<String, dynamic>>> timeout(Duration timeLimit,
          {FutureOr<List<Map<String, dynamic>>> Function()? onTimeout}) =>
      _future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue,
          {Function? onError}) =>
      _future.then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Rows.${invocation.memberName}');
}
