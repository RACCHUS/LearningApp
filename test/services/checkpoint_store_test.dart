import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/generation_error.dart';
import 'package:learning_pwa/services/checkpoint/checkpoint_store.dart';

import '../support/in_memory_checkpoint_store.dart';

void main() {
  final key = CheckpointKey(ownerScope: 'user-a', sessionId: 'job-1');
  late InMemoryCheckpointStore store;
  late CheckpointSaver saver;

  setUp(() {
    store = InMemoryCheckpointStore(clock: () => DateTime.utc(2026, 11, 12));
    saver = CheckpointSaver(store);
  });

  Future<EditorLease> acquire(String editor) async =>
      (await store.tryAcquireExclusiveEditor(key, editor)).lease!;

  group('CheckpointKey', () {
    test('requires owner and session', () {
      expect(
        () => CheckpointKey(ownerScope: '', sessionId: 's'),
        throwsArgumentError,
      );
      expect(
        () => CheckpointKey(ownerScope: 'o', sessionId: ''),
        throwsArgumentError,
      );
    });

    test('different owners are different keys', () {
      expect(
        CheckpointKey(ownerScope: 'user-b', sessionId: 'job-1') == key,
        isFalse,
      );
    });
  });

  group('single editor', () {
    test('a second tab is refused until the first releases', () async {
      final lease = await acquire('tab-1');
      final second = await store.tryAcquireExclusiveEditor(key, 'tab-2');
      expect(second.outcome, EditorAcquireOutcome.heldElsewhere);
      expect(second.canEdit, isFalse);

      await store.release(lease);
      final takeover = await store.tryAcquireExclusiveEditor(key, 'tab-2');
      expect(takeover.canEdit, isTrue);
    });

    test('re-acquiring by the same editor is allowed', () async {
      await acquire('tab-1');
      expect(
        (await store.tryAcquireExclusiveEditor(key, 'tab-1')).canEdit,
        isTrue,
      );
    });

    test('a stale lease cannot write after takeover', () async {
      final old = await acquire('tab-1');
      await store.release(old);
      await acquire('tab-2');
      final r = await saver.save(old, '{"a":1}', expectedRevision: 0);
      expect(r.saved, isFalse);
      expect(r.error!.errorCode, GenerationErrorCode.checkpointConflict);
      expect(store.writeCount, 0);
    });

    test('releasing a lease you do not hold changes nothing', () async {
      await acquire('tab-1');
      await store.release(EditorLease(key: key, editorId: 'tab-2'));
      expect(store.leases[key], 'tab-1');
    });
  });

  group('CheckpointSaver', () {
    test('saves, verifies and increments the revision', () async {
      final lease = await acquire('tab-1');
      final r1 = await saver.save(lease, '{"v":1}', expectedRevision: 0);
      expect(r1.saved, isTrue);
      expect(r1.snapshot!.revision, 1);
      expect(r1.snapshot!.digest, CheckpointSnapshot.digestOf('{"v":1}'));
      final r2 = await saver.save(lease, '{"v":2}', expectedRevision: 1);
      expect(r2.snapshot!.revision, 2);
      expect(store.backups[key]!.payload, '{"v":1}');
      expect(await store.export(key), '{"v":2}');
    });

    test(
      'a stale expected revision is a conflict, not last-writer-wins',
      () async {
        final lease = await acquire('tab-1');
        await saver.save(lease, '{"v":1}', expectedRevision: 0);
        final r = await saver.save(lease, '{"v":"stale"}', expectedRevision: 0);
        expect(r.saved, isFalse);
        expect(r.error!.errorCode, GenerationErrorCode.checkpointConflict);
        expect((await store.readSnapshot(key))!.payload, '{"v":1}');
      },
    );

    test('a storage error is reported and earlier data is kept', () async {
      final lease = await acquire('tab-1');
      await saver.save(lease, '{"v":1}', expectedRevision: 0);
      store.failNextWrite = true;
      final r = await saver.save(lease, '{"v":2}', expectedRevision: 1);
      expect(r.saved, isFalse);
      expect(r.error!.errorCode, GenerationErrorCode.checkpointUnavailable);
      expect(r.error.toString(), isNot(contains('{"v":2}')));
      expect((await store.readSnapshot(key))!.payload, '{"v":1}');
    });

    test('a read-back mismatch is never reported as saved', () async {
      final lease = await acquire('tab-1');
      store.corruptWrites = true;
      final r = await saver.save(lease, '{"v":1}', expectedRevision: 0);
      expect(r.saved, isFalse);
      expect(r.error!.errorCode, GenerationErrorCode.checkpointUnavailable);
    });

    test('nothing is written when a backup cannot be kept', () async {
      final lease = await acquire('tab-1');
      store.failBackup = true;
      final r = await saver.save(lease, '{"v":1}', expectedRevision: 0);
      expect(r.saved, isFalse);
      expect(store.writeCount, 0);
    });

    test('export falls back to the backup copy', () async {
      final lease = await acquire('tab-1');
      await saver.save(lease, '{"v":1}', expectedRevision: 0);
      await store.backup(key);
      store.snapshots.remove(key); // simulated eviction of the main copy
      expect(await store.export(key), '{"v":1}');
    });
  });

  group('ReadOnlyCheckpointStore', () {
    test('guard keeps a verified store and wraps an unverified one', () {
      expect(ReadOnlyCheckpointStore.guard(store), same(store));
      final unverified = InMemoryCheckpointStore(
        lockingSupport: CheckpointLockingSupport.unavailable,
      );
      final guarded = ReadOnlyCheckpointStore.guard(unverified);
      expect(guarded, isA<ReadOnlyCheckpointStore>());
      expect(guarded.lockingSupport, CheckpointLockingSupport.unavailable);
    });

    test('reads and exports, but never edits', () async {
      final lease = await acquire('tab-1');
      await saver.save(lease, '{"v":1}', expectedRevision: 0);
      final ro = ReadOnlyCheckpointStore(store);

      expect((await ro.readSnapshot(key))!.payload, '{"v":1}');
      expect(await ro.export(key), '{"v":1}');
      final acq = await ro.tryAcquireExclusiveEditor(key, 'tab-2');
      expect(acq.outcome, EditorAcquireOutcome.readOnly);

      final r = await CheckpointSaver(
        ro,
      ).save(lease, '{"v":2}', expectedRevision: 1);
      expect(r.saved, isFalse);
      expect(r.error!.errorCode, GenerationErrorCode.checkpointUnavailable);
      expect((await store.readSnapshot(key))!.revision, 1);
      expect(store.writeCount, 1);
    });
  });
}
