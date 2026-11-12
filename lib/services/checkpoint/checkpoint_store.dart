import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:learning_pwa/models/content_generation/generation_error.dart';

/// Whether a storage substrate has *verified* single-writer exclusivity.
///
/// SharedPreferences and Hive on web do not provide cross-tab
/// compare-and-swap on their own (master plan v2.6 §8 step 4, Appendix
/// D.5). Without verified exclusivity, editing is disabled, not merged.
enum CheckpointLockingSupport { verifiedExclusive, unavailable }

/// Identifies one checkpointed session for one owner. A checkpoint is never
/// read or written under a different owner.
class CheckpointKey {
  CheckpointKey({required this.ownerScope, required this.sessionId}) {
    if (ownerScope.isEmpty) throw ArgumentError.value(ownerScope, 'ownerScope');
    if (sessionId.isEmpty) throw ArgumentError.value(sessionId, 'sessionId');
  }

  final String ownerScope;
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is CheckpointKey &&
      other.ownerScope == ownerScope &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(ownerScope, sessionId);

  @override
  String toString() => '$ownerScope/$sessionId';
}

/// One committed revision. [payload] is the exact stored text; [digest] is
/// its SHA-256 so a read-back can prove the bytes are the ones written.
class CheckpointSnapshot {
  CheckpointSnapshot({
    required this.key,
    required this.revision,
    required this.editorId,
    required this.updatedAt,
    required this.payload,
  }) : digest = digestOf(payload);

  final CheckpointKey key;
  final int revision;
  final String editorId;
  final DateTime updatedAt;
  final String payload;
  final String digest;

  static String digestOf(String payload) =>
      sha256.convert(utf8.encode(payload)).toString();
}

/// Proof that [editorId] holds the single editing right for [key].
class EditorLease {
  const EditorLease({required this.key, required this.editorId});

  final CheckpointKey key;
  final String editorId;
}

enum EditorAcquireOutcome {
  granted,

  /// Another tab or device is editing. Show "open elsewhere", read-only
  /// with export and a request to resume after it lets go.
  heldElsewhere,

  /// This substrate cannot prove exclusivity, so this session is
  /// read-only with export.
  readOnly,
}

class EditorAcquireResult {
  const EditorAcquireResult.granted(EditorLease this.lease)
    : outcome = EditorAcquireOutcome.granted;
  const EditorAcquireResult.heldElsewhere()
    : outcome = EditorAcquireOutcome.heldElsewhere,
      lease = null;
  const EditorAcquireResult.readOnly()
    : outcome = EditorAcquireOutcome.readOnly,
      lease = null;

  final EditorAcquireOutcome outcome;
  final EditorLease? lease;

  bool get canEdit => outcome == EditorAcquireOutcome.granted;
}

enum CommitOutcome {
  committed,

  /// The stored revision is not the one the writer expected.
  revisionConflict,

  /// The caller does not hold the editor lease.
  notEditor,

  /// Writing is not available (read-only substrate, storage full, ...).
  unavailable,
}

class CommitResult {
  const CommitResult.committed(CheckpointSnapshot this.snapshot)
    : outcome = CommitOutcome.committed,
      error = null;
  const CommitResult.failed(this.outcome, GenerationError this.error)
    : snapshot = null;

  final CommitOutcome outcome;
  final CheckpointSnapshot? snapshot;
  final GenerationError? error;

  bool get isCommitted => outcome == CommitOutcome.committed;
}

/// Storage contract for V2 generation checkpoints (master plan v2.6
/// Appendix D.5). A local write followed by a read-back is not assumed to
/// be a transaction: callers must use [readbackVerify] before telling the
/// learner anything was saved, and failures leave earlier data intact.
abstract interface class CheckpointStore {
  CheckpointLockingSupport get lockingSupport;

  /// The latest committed snapshot, or `null` when none exists.
  Future<CheckpointSnapshot?> readSnapshot(CheckpointKey key);

  /// Tries to become the only editor. Never steals a held lease.
  Future<EditorAcquireResult> tryAcquireExclusiveEditor(
    CheckpointKey key,
    String editorId,
  );

  /// Writes [payload] as revision `expectedRevision + 1` only when the
  /// stored revision equals [expectedRevision] (0 when nothing is stored)
  /// and [lease] is current. Never last-writer-wins.
  Future<CommitResult> commitExpectedRevision(
    EditorLease lease,
    String payload, {
    required int expectedRevision,
  });

  /// Re-reads storage and confirms [revision] is stored with [digest].
  Future<bool> readbackVerify(CheckpointKey key, int revision, String digest);

  /// Keeps a recoverable copy of the current snapshot. Returns `true` when
  /// a copy exists afterwards or there was nothing to copy.
  Future<bool> backup(CheckpointKey key);

  /// Gives up the editing right so another tab may take over.
  Future<void> release(EditorLease lease);

  /// Exact stored text for a user export (latest, else the backup).
  Future<String?> export(CheckpointKey key);
}

/// Fail-safe wrapper for substrates without verified exclusivity: reading
/// and export work, editing is refused (master plan v2.6 Appendix D.5
/// "disable second-tab editing when exclusivity is unavailable").
class ReadOnlyCheckpointStore implements CheckpointStore {
  const ReadOnlyCheckpointStore(this._inner);

  final CheckpointStore _inner;

  /// Returns [store] itself only when it has verified exclusivity.
  static CheckpointStore guard(CheckpointStore store) =>
      store.lockingSupport == CheckpointLockingSupport.verifiedExclusive
      ? store
      : ReadOnlyCheckpointStore(store);

  @override
  CheckpointLockingSupport get lockingSupport =>
      CheckpointLockingSupport.unavailable;

  @override
  Future<CheckpointSnapshot?> readSnapshot(CheckpointKey key) =>
      _inner.readSnapshot(key);

  @override
  Future<EditorAcquireResult> tryAcquireExclusiveEditor(
    CheckpointKey key,
    String editorId,
  ) async => const EditorAcquireResult.readOnly();

  @override
  Future<CommitResult> commitExpectedRevision(
    EditorLease lease,
    String payload, {
    required int expectedRevision,
  }) async => const CommitResult.failed(
    CommitOutcome.unavailable,
    GenerationError(
      GenerationErrorCode.checkpointUnavailable,
      detail: 'read-only: exclusive editing is not verified here',
    ),
  );

  @override
  Future<bool> readbackVerify(CheckpointKey key, int revision, String digest) =>
      _inner.readbackVerify(key, revision, digest);

  @override
  Future<bool> backup(CheckpointKey key) async => false;

  @override
  Future<void> release(EditorLease lease) async {}

  @override
  Future<String?> export(CheckpointKey key) => _inner.export(key);
}

class CheckpointSaveResult {
  const CheckpointSaveResult._(this.snapshot, this.error);

  /// Set only when the write was committed *and* read back intact.
  final CheckpointSnapshot? snapshot;
  final GenerationError? error;

  bool get saved => snapshot != null;
}

/// The only path that may report "saved": backup, commit with the expected
/// revision, then verify by read-back.
class CheckpointSaver {
  const CheckpointSaver(this.store);

  final CheckpointStore store;

  Future<CheckpointSaveResult> save(
    EditorLease lease,
    String payload, {
    required int expectedRevision,
  }) async {
    CheckpointSaveResult fail(GenerationErrorCode c, String detail) =>
        CheckpointSaveResult._(null, GenerationError(c, detail: detail));

    try {
      if (!await store.backup(lease.key)) {
        return fail(
          GenerationErrorCode.checkpointUnavailable,
          'could not keep a recoverable copy; nothing was written',
        );
      }
      final commit = await store.commitExpectedRevision(
        lease,
        payload,
        expectedRevision: expectedRevision,
      );
      if (!commit.isCommitted) {
        return CheckpointSaveResult._(null, commit.error);
      }
      final snap = commit.snapshot!;
      if (!await store.readbackVerify(lease.key, snap.revision, snap.digest)) {
        return fail(
          GenerationErrorCode.checkpointUnavailable,
          'read-back did not match revision ${snap.revision}',
        );
      }
      return CheckpointSaveResult._(snap, null);
    } on Object catch (e) {
      return fail(
        GenerationErrorCode.checkpointUnavailable,
        'storage error: ${e.runtimeType}',
      );
    }
  }
}
