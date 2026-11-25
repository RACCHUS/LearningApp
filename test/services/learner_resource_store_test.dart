import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';
import 'package:learning_pwa/services/companion/learner_resource_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An account store that fails on demand, to test a part-way move.
class FakeAccountStore implements LearnerResourceStore {
  final saved = <String>[];
  final objectives = <String, Set<String>>{};
  final studied = <String>[];
  String? failOnTitle;

  @override
  Future<String> save({
    String? id,
    required String targetId,
    required String title,
    required LearnerResourceKind kind,
    String? url,
    ExternalAccess? access,
  }) async {
    if (title == failOnTitle) throw StateError('offline');
    saved.add(title);
    return 'acct-${saved.length}';
  }

  @override
  Future<void> setObjectives(String resourceId, Set<String> keys) async => objectives[resourceId] = keys;

  @override
  Future<void> setStudied(String resourceId, String key, bool studied) async =>
      this.studied.add('$resourceId:$key');

  @override
  Future<List<LearnerResource>> list(String targetId) async => const [];

  @override
  Future<void> delete(String resourceId) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a guest resource is kept on the device, per goal', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: '  My book ', kind: LearnerResourceKind.book);
    await store.save(targetId: 't2', title: 'Other', kind: LearnerResourceKind.course);
    final list = await LocalLearnerResourceStore().list('t1');
    expect(list.single.id, id);
    expect(list.single.title, 'My book');
    expect(list.single.url, isNull);
  });

  test('editing changes the fields and keeps the ticks', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.setObjectives(id, {'1.1'});
    await store.save(id: id, targetId: 't1', title: 'B', kind: LearnerResourceKind.course, url: 'https://example.org');
    final r = (await store.list('t1')).single;
    expect(r.title, 'B');
    expect(r.url, 'https://example.org');
    expect(r.objectives.keys, ['1.1']);
  });

  test('changing what is covered keeps studied marks on kept objectives', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.setObjectives(id, {'1.1', '1.2'});
    await store.setStudied(id, '1.1', true);
    await store.setObjectives(id, {'1.1', '1.3'});
    final r = (await store.list('t1')).single;
    expect(r.objectives.keys.toSet(), {'1.1', '1.3'});
    expect(r.objectives['1.1'], isNotNull);
    expect(r.objectives['1.3'], isNull);
    await store.setStudied(id, '1.1', false);
    expect((await store.list('t1')).single.studiedCount, 0);
  });

  test('only a covered objective can be marked studied', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await expectLater(store.setStudied(id, '9.9', true), throwsStateError);
  });

  test('an empty title is refused and delete removes the resource', () async {
    final store = LocalLearnerResourceStore();
    await expectLater(
      store.save(targetId: 't1', title: '  ', kind: LearnerResourceKind.book),
      throwsArgumentError,
    );
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.delete(id);
    expect(await store.list('t1'), isEmpty);
  });

  test('unreadable device data reads as empty instead of crashing', () async {
    SharedPreferences.setMockInitialValues({LocalLearnerResourceStore.storageKey: 'not json'});
    expect(await LocalLearnerResourceStore().list('t1'), isEmpty);
  });

  test('moving to an account copies ticks and studied marks, then clears the device', () async {
    final local = LocalLearnerResourceStore();
    final id = await local.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await local.setObjectives(id, {'1.1', '1.2'});
    await local.setStudied(id, '1.2', true);
    final account = FakeAccountStore();
    expect(await moveLocalResourcesToAccount(local, account), 1);
    expect(account.saved, ['A']);
    expect(account.objectives['acct-1'], {'1.1', '1.2'});
    expect(account.studied, ['acct-1:1.2']);
    expect(await local.listAll(), isEmpty);
  });

  test('a failed move leaves the unsaved resources on the device', () async {
    final local = LocalLearnerResourceStore();
    await local.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await local.save(targetId: 't1', title: 'B', kind: LearnerResourceKind.book);
    final account = FakeAccountStore()..failOnTitle = 'B';
    await expectLater(moveLocalResourcesToAccount(local, account), throwsStateError);
    expect((await local.listAll()).map((r) => r.title), ['B']);
  });
}
