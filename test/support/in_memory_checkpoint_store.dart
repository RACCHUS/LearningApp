import 'package:learning_pwa/models/content_generation/generation_error.dart';
import 'package:learning_pwa/services/checkpoint/checkpoint_store.dart';

/// Single-isolate [CheckpointStore] test double with fault injection.
///
/// Exclusivity is real within one isolate (one map of leases), which is
/// what lets it claim [CheckpointLockingSupport.verifiedExclusive].
class InMemoryCheckpointStore implements CheckpointStore {
  InMemoryCheckpointStore({
    this.lockingSupport = CheckpointLockingSupport.verifiedExclusive,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  final CheckpointLockingSupport lockingSupport;
  final DateTime Function() _clock;

  final Map<CheckpointKey, CheckpointSnapshot> snapshots = {};
  final Map<CheckpointKey, CheckpointSnapshot> backups = {};
  final Map<CheckpointKey, String> leases = {};

  /// Next commit throws, simulating storage-full or quota errors.
  bool failNextWrite = false;

  /// Commits store different bytes than requested (silent corruption).
  bool corruptWrites = false;

  /// Backups fail.
  bool failBackup = false;

  int writeCount = 0;

  @override
  Future<CheckpointSnapshot?> readSnapshot(CheckpointKey key) async =>
      snapshots[key];

  @override
  Future<EditorAcquireResult> tryAcquireExclusiveEditor(
    CheckpointKey key,
    String editorId,
  ) async {
    final holder = leases[key];
    if (holder != null && holder != editorId) {
      return const EditorAcquireResult.heldElsewhere();
    }
    leases[key] = editorId;
    return EditorAcquireResult.granted(
      EditorLease(key: key, editorId: editorId),
    );
  }

  @override
  Future<CommitResult> commitExpectedRevision(
    EditorLease lease,
    String payload, {
    required int expectedRevision,
  }) async {
    if (leases[lease.key] != lease.editorId) {
      return const CommitResult.failed(
        CommitOutcome.notEditor,
        GenerationError(
          GenerationErrorCode.checkpointConflict,
          detail: 'open elsewhere',
        ),
      );
    }
    final current = snapshots[lease.key]?.revision ?? 0;
    if (current != expectedRevision) {
      return CommitResult.failed(
        CommitOutcome.revisionConflict,
        GenerationError(
          GenerationErrorCode.checkpointConflict,
          detail: 'expected $expectedRevision, found $current',
        ),
      );
    }
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('QuotaExceededError');
    }
    final snap = CheckpointSnapshot(
      key: lease.key,
      revision: current + 1,
      editorId: lease.editorId,
      updatedAt: _clock(),
      payload: payload,
    );
    snapshots[lease.key] = corruptWrites
        ? CheckpointSnapshot(
            key: lease.key,
            revision: snap.revision,
            editorId: lease.editorId,
            updatedAt: snap.updatedAt,
            payload: '$payload#',
          )
        : snap;
    writeCount++;
    return CommitResult.committed(snap);
  }

  @override
  Future<bool> readbackVerify(
    CheckpointKey key,
    int revision,
    String digest,
  ) async {
    final s = snapshots[key];
    return s != null && s.revision == revision && s.digest == digest;
  }

  @override
  Future<bool> backup(CheckpointKey key) async {
    if (failBackup) return false;
    final s = snapshots[key];
    if (s != null) backups[key] = s;
    return true;
  }

  @override
  Future<void> release(EditorLease lease) async {
    if (leases[lease.key] == lease.editorId) leases.remove(lease.key);
  }

  @override
  Future<String?> export(CheckpointKey key) async =>
      snapshots[key]?.payload ?? backups[key]?.payload;
}
