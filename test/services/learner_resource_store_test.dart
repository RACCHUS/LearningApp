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

  final sections = <String, List<ResourceSection>>{};

  @override
  Future<void> setSections(String resourceId, List<ResourceSection> s) async => sections[resourceId] = s;

  final studiedSections = <String>[];

  @override
  Future<void> setSectionStudied(String resourceId, int index, bool studied) async =>
      studiedSections.add('$resourceId:$index');

  @override
  Future<List<LearnerResource>> list(String targetId) async => const [];

  @override
  Future<List<LearnerResource>> listAll() async => const [];

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

  test('saving an outline keeps its order, ticks its objectives and marks nothing studied', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.setObjectives(id, {'9.1'});
    await store.setStudied(id, '9.1', true);
    await store.setSections(id, const [
      ResourceSection(title: ' Unit 1 ', objectiveKeys: {'1.1', '1.2'}, source: SectionMapSource.outlineMatch),
      ResourceSection(title: 'Unit 2', objectiveKeys: {'1.2'}, source: SectionMapSource.ownAi),
      ResourceSection(title: 'Unit 3'),
    ]);
    final r = (await LocalLearnerResourceStore().list('t1')).single;
    expect([for (final s in r.sections) s.title], ['Unit 1', 'Unit 2', 'Unit 3']);
    expect([for (final s in r.sections) s.source.wire], ['outline_match', 'own_ai', 'learner']);
    expect(r.sectionTitlesFor('1.2'), ['Unit 1', 'Unit 2']);
    expect(r.objectives.keys.toSet(), {'9.1', '1.1', '1.2'});
    expect(r.studiedCount, 1, reason: 'the earlier studied mark is kept and none is added');

    await store.setSections(id, const []);
    final cleared = (await store.list('t1')).single;
    expect(cleared.sections, isEmpty);
    expect(cleared.objectives.length, 3, reason: 'removing the outline keeps the ticks');
  });

  test('an outline with an empty title or too many parts is refused', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await expectLater(store.setSections(id, const [ResourceSection(title: '  ')]), throwsArgumentError);
    await expectLater(
      store.setSections(id, [for (var i = 0; i < 201; i++) ResourceSection(title: 'S$i')]),
      throwsStateError,
    );
  });

  test('moving to an account carries the outline', () async {
    final local = LocalLearnerResourceStore();
    final id = await local.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await local.setSections(id, const [ResourceSection(title: 'Unit 1', objectiveKeys: {'1.1'})]);
    final account = FakeAccountStore();
    await moveLocalResourcesToAccount(local, account);
    expect(account.sections['acct-1']!.single.title, 'Unit 1');
    expect(account.objectives['acct-1'], {'1.1'});
  });

  test('account rows are read in position order and a blank section is skipped', () {
    final r = LearnerResource.fromJson({
      'id': 'r1',
      'target_id': 't1',
      'title': 'A',
      'kind': 'book',
      'learner_resource_sections': [
        {'position': 2, 'title': 'Second', 'objective_keys': ['1.2'], 'map_source': 'own_ai'},
        {'position': 1, 'title': 'First', 'objective_keys': ['1.1', 7], 'map_source': 'reviewed'},
        {'position': 3, 'title': ' '},
      ],
    });
    expect([for (final s in r.sections) s.title], ['First', 'Second']);
    expect(r.sections.first.objectiveKeys, {'1.1'});
    expect(r.sections.first.source, SectionMapSource.learner, reason: 'an unknown source never reads as reviewed');
  });

  test('marking parts studied is self-report and marks an objective only when all its parts are done', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.setSections(id, const [
      ResourceSection(title: 'Part 1', objectiveKeys: {'1.1'}, minutes: 25),
      ResourceSection(title: 'Part 2', objectiveKeys: {'1.1', '1.2'}, minutes: 40),
      ResourceSection(title: 'Part 3'),
    ]);
    var r = (await store.list('t1')).single;
    expect(r.nextSectionIndex, 0);
    expect(r.remainingMinutes, 65);
    expect(r.remainingWithoutEstimate, 1);

    await store.setSectionStudied(id, 0, true);
    r = (await LocalLearnerResourceStore().list('t1')).single;
    expect(r.nextSectionIndex, 1);
    expect(r.remainingMinutes, 40);
    expect(r.studiedCount, 0);

    await store.setSectionStudied(id, 1, true);
    r = (await store.list('t1')).single;
    expect(r.objectives['1.1'], isNotNull);
    expect(r.objectives['1.2'], isNotNull);

    await store.setSectionStudied(id, 1, false);
    r = (await store.list('t1')).single;
    expect(r.nextSectionIndex, 1);
    expect(r.studiedCount, 2, reason: 'unmarking a part never unmarks an objective');
    await expectLater(store.setSectionStudied(id, 9, true), throwsStateError);
  });

  test('replacing the outline keeps the mark of a part whose title is unchanged', () async {
    final store = LocalLearnerResourceStore();
    final id = await store.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await store.setSections(id, const [ResourceSection(title: 'Part 1'), ResourceSection(title: 'Part 2')]);
    await store.setSectionStudied(id, 0, true);
    await store.setSections(id, const [
      ResourceSection(title: 'Intro'),
      ResourceSection(title: 'Part 1', minutes: 30),
      ResourceSection(title: 'Part 2'),
    ]);
    final r = (await store.list('t1')).single;
    expect([for (final s in r.sections) s.studied], [false, true, false]);
    expect(r.sections[1].minutes, 30);
    expect(r.nextSectionIndex, 0);
  });

  test('moving to an account carries the studied parts and estimates', () async {
    final local = LocalLearnerResourceStore();
    final id = await local.save(targetId: 't1', title: 'A', kind: LearnerResourceKind.book);
    await local.setSections(id, const [ResourceSection(title: 'P1', minutes: 5), ResourceSection(title: 'P2')]);
    await local.setSectionStudied(id, 1, true);
    final account = FakeAccountStore();
    await moveLocalResourcesToAccount(local, account);
    expect(account.sections['acct-1']!.first.minutes, 5);
    expect(account.studiedSections, ['acct-1:1']);
  });

  test('study time is written in hours and minutes, and bad estimates are dropped', () {
    expect(formatStudyMinutes(25), '25 min');
    expect(formatStudyMinutes(60), '1 h');
    expect(formatStudyMinutes(95), '1 h 35 min');
    final s = ResourceSection.fromJson({'title': 'x', 'est_minutes': 9000, 'studied_at': 'nope'});
    expect(s.minutes, isNull);
    expect(s.studied, isFalse);
    expect(const ResourceSection(title: 'x').toRpcJson().containsKey('minutes'), isFalse);
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
