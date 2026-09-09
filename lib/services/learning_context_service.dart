import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:uuid/uuid.dart';

/// Local-first store for [LearningContext] and [ResumePointer].
///
/// Hive is the source of truth; Supabase sync is layered on separately so a
/// network failure can never block the Learn screen from resolving an action.
class LearningContextService {
  final Box<LearningContext> _contexts;
  final Box<ResumePointer> _pointers;
  final Uuid _uuid;

  LearningContextService({
    required Box<LearningContext> contexts,
    required Box<ResumePointer> pointers,
    Uuid? uuid,
  })  : _contexts = contexts,
        _pointers = pointers,
        _uuid = uuid ?? const Uuid();

  List<LearningContext> all({required String userId, bool includeArchived = false}) {
    return _contexts.values
        .where((c) => c.userId == userId)
        .where((c) => includeArchived || !c.isArchived)
        .toList();
  }

  LearningContext? byId(String id) => _contexts.get(id);

  /// Creates a context, or returns the existing one for the same root.
  ///
  /// De-duplication is by [LearningContext.dedupeKey], which makes both
  /// creation and backfill safe to run repeatedly.
  Future<LearningContext> createOrGet({
    required String userId,
    required String label,
    required ContextRootType rootType,
    required String rootId,
    String? emoji,
    DateTime? lastActiveAt,
  }) async {
    if (rootId.isEmpty) {
      throw ArgumentError.value(rootId, 'rootId', 'must not be empty');
    }

    final key = '$userId::${rootType.name}::$rootId';
    final existing = _contexts.values.where((c) => c.dedupeKey == key);
    if (existing.isNotEmpty) {
      final found = existing.first;
      // Un-archive rather than duplicating if the learner returns to it.
      if (found.isArchived) {
        final revived = found.copyWith(isArchived: false);
        await _contexts.put(revived.id, revived);
        return revived;
      }
      return found;
    }

    final context = LearningContext(
      id: _uuid.v4(),
      userId: userId,
      label: label.trim().isEmpty ? 'Untitled' : label.trim(),
      rootType: rootType,
      rootId: rootId,
      emoji: emoji,
      lastActiveAt: lastActiveAt ?? DateTime.now(),
    );
    await _contexts.put(context.id, context);
    return context;
  }

  Future<void> touch(String contextId) async {
    final existing = _contexts.get(contextId);
    if (existing == null) return;
    await _contexts.put(
      contextId,
      existing.copyWith(lastActiveAt: DateTime.now()),
    );
  }

  Future<void> setArchived(String contextId, {required bool archived}) async {
    final existing = _contexts.get(contextId);
    if (existing == null) return;
    await _contexts.put(contextId, existing.copyWith(isArchived: archived));
  }

  Future<void> setPinned(String contextId, {required int sortOrder}) async {
    final existing = _contexts.get(contextId);
    if (existing == null) return;
    await _contexts.put(contextId, existing.copyWith(sortOrder: sortOrder));
  }

  Future<void> rename(String contextId, String label) async {
    final existing = _contexts.get(contextId);
    if (existing == null || label.trim().isEmpty) return;
    await _contexts.put(contextId, existing.copyWith(label: label.trim()));
  }

  // -- Resume pointers ------------------------------------------------------

  ResumePointer? resumeFor(String contextId) => _pointers.get(contextId);

  Future<void> saveResume(ResumePointer pointer) =>
      _pointers.put(pointer.contextId, pointer);

  Future<void> clearResume(String contextId) => _pointers.delete(contextId);

  // -- Backfill -------------------------------------------------------------

  /// Creates one context per thing the learner already started.
  ///
  /// Idempotent by construction: every write goes through [createOrGet], so
  /// re-running after a crash, on a second device, or when Hive and Supabase
  /// disagree cannot produce duplicates. This is the only irreversible step in
  /// the migration, so it never deletes or rewrites existing content.
  Future<BackfillReport> backfill({
    required String userId,
    List<BackfillSeed> seeds = const [],
  }) async {
    var created = 0;
    var skipped = 0;
    final failures = <String>[];

    for (final seed in seeds) {
      try {
        final before = _contexts.length;
        await createOrGet(
          userId: userId,
          label: seed.label,
          rootType: seed.rootType,
          rootId: seed.rootId,
          emoji: seed.emoji,
          lastActiveAt: seed.lastActiveAt,
        );
        if (_contexts.length > before) {
          created++;
        } else {
          skipped++;
        }
      } catch (e) {
        // One bad seed must not abort the whole migration.
        failures.add('${seed.rootType.name}:${seed.rootId} — $e');
        debugPrint('⚠️ Backfill skipped ${seed.rootId}: $e');
      }
    }

    return BackfillReport(
      created: created,
      skipped: skipped,
      failures: failures,
    );
  }
}

class BackfillSeed {
  final String label;
  final ContextRootType rootType;
  final String rootId;
  final String? emoji;
  final DateTime? lastActiveAt;

  const BackfillSeed({
    required this.label,
    required this.rootType,
    required this.rootId,
    this.emoji,
    this.lastActiveAt,
  });
}

class BackfillReport {
  final int created;
  final int skipped;
  final List<String> failures;

  const BackfillReport({
    required this.created,
    required this.skipped,
    this.failures = const [],
  });

  bool get hasFailures => failures.isNotEmpty;

  @override
  String toString() =>
      'BackfillReport(created: $created, skipped: $skipped, failures: ${failures.length})';
}
