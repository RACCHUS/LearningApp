import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/retired_lesson_context_provider.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_fixtures.dart';

const retiredId = '93bfa731-d581-420f-8b14-2ba5ea041a84';
const droppedId = '11111111-1111-4111-8111-111111111111';
const liveId = 'c24de489-4f43-4f52-90e0-2267a0c77fd8';
const unknownId = '22222222-2222-4222-8222-222222222222';

LearningContext lessonContext(String rootId, {String label = 'A lesson'}) =>
    LearningContext(
      id: 'ctx-$rootId',
      userId: 'local-user',
      label: label,
      rootType: ContextRootType.lesson,
      rootId: rootId,
      lastActiveAt: DateTime(2026, 11, 20),
    );

class RecordingNotifier extends LearningContextsNotifier {
  RecordingNotifier(List<LearningContext> contexts)
      : super.stub(LearningContextsState(contexts: contexts));

  final moves = <String, String?>{};

  void setContexts(List<LearningContext> contexts) =>
      state = LearningContextsState(contexts: contexts);

  @override
  Future<void> replaceRetiredLesson(
    LearningContext stale,
    String? replacementLessonId,
  ) async {
    moves[stale.rootId] = replacementLessonId;
  }
}

class FakeLocalProgress implements LocalLessonProgress {
  FakeLocalProgress(this.ids);
  final Set<String> ids;
  final moved = <String, String>{};

  @override
  Future<Set<String>> lessonIds() async => ids;

  @override
  Future<int> moveLesson(String fromLessonId, String toLessonId) async {
    moved[fromLessonId] = toLessonId;
    return 1;
  }
}

AvailableLessonsCatalog catalogWith(List<String> ids, {String? error}) =>
    AvailableLessonsCatalog(
      lessons: [for (final id in ids) TestFixtures.createTestLesson(id: id, title: id)],
      remoteError: error,
    );

void main() {
  setUp(resetRetiredLessonChecks);

  group('lessonContextsMissingFromCatalog', () {
    test('only active lesson contexts with server ids missing from the catalog', () {
      final contexts = [
        lessonContext(retiredId),
        lessonContext(liveId),
        lessonContext('asset-lesson-1'), // bundled lessons are not server ids
        LearningContext(
          id: 'ctx-target',
          userId: 'local-user',
          label: 'A target',
          rootType: ContextRootType.target,
          rootId: unknownId,
          lastActiveAt: DateTime(2026, 11, 20),
        ),
      ];
      final missing = lessonContextsMissingFromCatalog(contexts, catalogWith([liveId]));
      expect(missing.map((c) => c.rootId), [retiredId]);
    });

    test('nothing counts as missing while the remote catalog failed', () {
      final missing = lessonContextsMissingFromCatalog(
        [lessonContext(retiredId)],
        catalogWith(const [], error: 'offline'),
      );
      expect(missing, isEmpty);
    });
  });

  test('moves retired contexts, archives dropped ones, ignores the rest', () async {
    final notifier = RecordingNotifier([
      lessonContext(retiredId),
      lessonContext(droppedId),
      lessonContext(unknownId),
      lessonContext(liveId),
    ]);
    final asked = <String>[];
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith([liveId])),
      localLessonProgressProvider.overrideWithValue(FakeLocalProgress({})),
      lessonReplacementLookupProvider.overrideWithValue((id) async {
        asked.add(id);
        return switch (id) {
          retiredId => const LessonReplacement(retired: true, replacementId: liveId),
          droppedId => const LessonReplacement(retired: true),
          _ => const LessonReplacement(retired: false),
        };
      }),
    ]);
    addTearDown(container.dispose);

    await container.read(retiredLessonContextRepairProvider.future);

    expect(asked, unorderedEquals([retiredId, droppedId, unknownId]));
    expect(notifier.moves, {retiredId: liveId, droppedId: null});

    // The same lesson is not asked about again in this session.
    container.invalidate(retiredLessonContextRepairProvider);
    await container.read(retiredLessonContextRepairProvider.future);
    expect(asked, hasLength(3));
  });

  test('a failed lookup leaves the context alone', () async {
    final logged = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    addTearDown(() => debugPrint = original);
    final notifier = RecordingNotifier([lessonContext(retiredId)]);
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith(const [])),
      localLessonProgressProvider.overrideWithValue(FakeLocalProgress({})),
      lessonReplacementLookupProvider.overrideWithValue((id) async => throw Exception('down')),
    ]);
    addTearDown(container.dispose);

    await container.read(retiredLessonContextRepairProvider.future);
    expect(notifier.moves, isEmpty);
    expect(logged.single, contains('Could not check lesson'));
  });

  test('moves local progress for retired lessons, even without a context', () async {
    final notifier = RecordingNotifier(const []);
    final local = FakeLocalProgress({retiredId, droppedId, liveId, 'asset-lesson-1'});
    final asked = <String>[];
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith([liveId])),
      localLessonProgressProvider.overrideWithValue(local),
      lessonReplacementLookupProvider.overrideWithValue((id) async {
        asked.add(id);
        return switch (id) {
          retiredId => const LessonReplacement(retired: true, replacementId: liveId),
          droppedId => const LessonReplacement(retired: true),
          _ => const LessonReplacement(retired: false),
        };
      }),
    ]);
    addTearDown(container.dispose);

    await container.read(retiredLessonContextRepairProvider.future);

    expect(asked, unorderedEquals([retiredId, droppedId]));
    // A dropped section keeps its local history where it is.
    expect(local.moved, {retiredId: liveId});
  });

  test('contexts that load after progress are still moved, with one lookup', () async {
    final notifier = RecordingNotifier(const []);
    final local = FakeLocalProgress({retiredId});
    final asked = <String>[];
    final container = ProviderContainer(overrides: [
      learningContextsProvider.overrideWith((ref) => notifier),
      availableLessonsCatalogProvider.overrideWith((ref) async => catalogWith([liveId])),
      localLessonProgressProvider.overrideWithValue(local),
      lessonReplacementLookupProvider.overrideWithValue((id) async {
        asked.add(id);
        return const LessonReplacement(retired: true, replacementId: liveId);
      }),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(retiredLessonContextRepairProvider, (_, __) {});
    addTearDown(sub.close);

    await container.read(retiredLessonContextRepairProvider.future);
    expect(local.moved, {retiredId: liveId});
    expect(notifier.moves, isEmpty);

    // The learner's goals finish loading a moment later.
    notifier.setContexts([lessonContext(retiredId)]);
    await container.read(retiredLessonContextRepairProvider.future);

    expect(notifier.moves, {retiredId: liveId});
    expect(asked, [retiredId]);
  });

  group('replaceRetiredLesson with real storage', () {
    late Box<LearningContext> contexts;
    late Box<ResumePointer> pointers;
    late LearningContextService service;

    setUpAll(() {
      Hive.init('build/test_hive_retired_lesson');
      if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(LearningContextAdapter());
      if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(ResumePointerAdapter());
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final stamp = DateTime.now().microsecondsSinceEpoch;
      contexts = await Hive.openBox<LearningContext>('ctx_$stamp');
      pointers = await Hive.openBox<ResumePointer>('ptr_$stamp');
      service = LearningContextService(contexts: contexts, pointers: pointers);
    });

    tearDown(() async {
      await contexts.deleteFromDisk();
      await pointers.deleteFromDisk();
    });

    test('carries the resume pointer and archives the old context', () async {
      final stale = await service.createOrGet(
        userId: 'u1',
        label: '6.1 Understand Percent',
        rootType: ContextRootType.lesson,
        rootId: retiredId,
      );
      await service.saveResume(ResumePointer(
        contextId: stale.id,
        kind: ResumableKind.lesson,
        activityId: retiredId,
        itemIndex: 7,
        updatedAt: DateTime(2026, 11, 20),
      ));
      final notifier = LearningContextsNotifier(service, const NextActionEngine(), 'u1', null);
      addTearDown(notifier.dispose);
      await notifier.load();

      await notifier.replaceRetiredLesson(stale, liveId);

      final moved = contexts.values.singleWhere((c) => c.rootId == liveId);
      expect(moved.label, '6.1 Understand Percent');
      expect(contexts.get(stale.id)!.isArchived, isTrue);
      final pointer = service.resumeFor(moved.id)!;
      expect(pointer.activityId, liveId);
      expect(pointer.itemIndex, 7);
    });
  });

  test('parses the server answer', () {
    final a = LessonReplacement.fromJson({'retired': true, 'replacement_id': liveId});
    expect(a.retired, isTrue);
    expect(a.replacementId, liveId);
    final b = LessonReplacement.fromJson({'retired': false, 'replacement_id': null});
    expect(b.retired, isFalse);
    expect(b.replacementId, isNull);
  });
}
