import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/learning_context_service.dart';

/// Backfill is the only irreversible step in the migration, so idempotency is
/// tested directly rather than assumed.
void main() {
  late Box<LearningContext> contexts;
  late Box<ResumePointer> pointers;
  late LearningContextService service;

  setUpAll(() {
    Hive.init('build/test_hive_learning_context');
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(LearningContextAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(ResumePointerAdapter());
    }
  });

  setUp(() async {
    contexts = await Hive.openBox<LearningContext>(
        'ctx_${DateTime.now().microsecondsSinceEpoch}');
    pointers = await Hive.openBox<ResumePointer>(
        'ptr_${DateTime.now().microsecondsSinceEpoch}');
    service = LearningContextService(contexts: contexts, pointers: pointers);
  });

  tearDown(() async {
    await contexts.deleteFromDisk();
    await pointers.deleteFromDisk();
  });

  group('createOrGet', () {
    test('creates a context', () async {
      final created = await service.createOrGet(
        userId: 'u1',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      expect(created.rootId, 'course-1');
      expect(contexts.length, 1);
    });

    test('is idempotent for the same root', () async {
      final a = await service.createOrGet(
        userId: 'u1',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      final b = await service.createOrGet(
        userId: 'u1',
        label: 'Flutter renamed',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      expect(a.id, b.id);
      expect(contexts.length, 1);
    });

    test('same rootId under a different rootType is a different context', () async {
      await service.createOrGet(
        userId: 'u1',
        label: 'As course',
        rootType: ContextRootType.course,
        rootId: 'shared-id',
      );
      await service.createOrGet(
        userId: 'u1',
        label: 'As lesson',
        rootType: ContextRootType.lesson,
        rootId: 'shared-id',
      );
      expect(contexts.length, 2);
    });

    test('different users never collide', () async {
      await service.createOrGet(
        userId: 'u1',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      await service.createOrGet(
        userId: 'u2',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      expect(contexts.length, 2);
    });

    test('revives an archived context instead of duplicating it', () async {
      final created = await service.createOrGet(
        userId: 'u1',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      await service.setArchived(created.id, archived: true);

      final again = await service.createOrGet(
        userId: 'u1',
        label: 'Flutter',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      );
      expect(again.id, created.id);
      expect(again.isArchived, isFalse);
      expect(contexts.length, 1);
    });

    test('rejects an empty rootId rather than writing junk', () async {
      expect(
        () => service.createOrGet(
          userId: 'u1',
          label: 'Broken',
          rootType: ContextRootType.course,
          rootId: '',
        ),
        throwsArgumentError,
      );
    });
  });

  group('backfill', () {
    final seeds = [
      const BackfillSeed(
        label: 'Flutter Developer',
        rootType: ContextRootType.path,
        rootId: 'path-1',
      ),
      const BackfillSeed(
        label: 'Dart Fundamentals',
        rootType: ContextRootType.course,
        rootId: 'course-1',
      ),
      const BackfillSeed(
        label: 'Spanish Verbs',
        rootType: ContextRootType.studySet,
        rootId: 'set-1',
      ),
    ];

    test('creates one context per seed', () async {
      final report = await service.backfill(userId: 'u1', seeds: seeds);
      expect(report.created, 3);
      expect(report.skipped, 0);
      expect(contexts.length, 3);
    });

    test('SHIP GATE: re-running produces no duplicates', () async {
      await service.backfill(userId: 'u1', seeds: seeds);
      final second = await service.backfill(userId: 'u1', seeds: seeds);

      expect(second.created, 0);
      expect(second.skipped, 3);
      expect(contexts.length, 3);
    });

    test('running three times is still stable', () async {
      for (var i = 0; i < 3; i++) {
        await service.backfill(userId: 'u1', seeds: seeds);
      }
      expect(contexts.length, 3);
    });

    test('one bad seed does not abort the migration', () async {
      final report = await service.backfill(userId: 'u1', seeds: [
        ...seeds,
        const BackfillSeed(
          label: 'Broken',
          rootType: ContextRootType.course,
          rootId: '',
        ),
      ]);
      expect(report.created, 3);
      expect(report.hasFailures, isTrue);
      expect(contexts.length, 3);
    });

    test('never deletes existing content', () async {
      await service.createOrGet(
        userId: 'u1',
        label: 'Hand made',
        rootType: ContextRootType.lesson,
        rootId: 'lesson-9',
      );
      await service.backfill(userId: 'u1', seeds: seeds);
      expect(contexts.length, 4);
    });
  });

  group('resume pointers', () {
    test('round-trips through Hive', () async {
      final pointer = ResumePointer(
        contextId: 'c1',
        kind: ResumableKind.studySet,
        activityId: 'set-1',
        itemIndex: 4,
        updatedAt: DateTime(2026, 3, 1),
      );
      await service.saveResume(pointer);

      final read = service.resumeFor('c1');
      expect(read, isNotNull);
      expect(read!.kind, ResumableKind.studySet);
      expect(read.activityId, 'set-1');
      expect(read.itemIndex, 4);
      expect(read.courseId, isNull);
    });

    test('clearing removes it', () async {
      await service.saveResume(ResumePointer(
        contextId: 'c1',
        kind: ResumableKind.lesson,
        activityId: 'l1',
        updatedAt: DateTime(2026, 3, 1),
      ));
      await service.clearResume('c1');
      expect(service.resumeFor('c1'), isNull);
    });
  });

  group('context queries', () {
    test('archived contexts are excluded by default', () async {
      final a = await service.createOrGet(
        userId: 'u1',
        label: 'A',
        rootType: ContextRootType.course,
        rootId: 'a',
      );
      await service.createOrGet(
        userId: 'u1',
        label: 'B',
        rootType: ContextRootType.course,
        rootId: 'b',
      );
      await service.setArchived(a.id, archived: true);

      expect(service.all(userId: 'u1').length, 1);
      expect(service.all(userId: 'u1', includeArchived: true).length, 2);
    });

    test('pinning is persisted', () async {
      final c = await service.createOrGet(
        userId: 'u1',
        label: 'A',
        rootType: ContextRootType.course,
        rootId: 'a',
      );
      await service.setPinned(c.id, sortOrder: 0);
      expect(service.byId(c.id)!.isPinned, isTrue);
    });
  });
}
