import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/fast_plan_result.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a server-backed compare-and-set update for [FastPreference].
class FastPreferenceRemoteCasResult {
  final bool conflicted;
  final FastPreference authoritativePreference;

  const FastPreferenceRemoteCasResult({
    required this.conflicted,
    required this.authoritativePreference,
  });
}

/// Best-effort remote synchronization for learning contexts and cross-device
/// Fast preferences (`TEL-01B`, `TEL-04A`).
///
/// Hive remains the local source of truth for [LearningContext] and
/// [ResumePointer]. Cross-device [FastPreference] records live in the dedicated
/// `context_fast_preferences` table and are mutated exclusively via the atomic
/// `update_context_fast_preferences` RPC so `learning_contexts.scope_config`
/// remains strictly isolated.
class LearningContextSyncService {
  final SupabaseClient _client;
  final Box<LearningContext> _contexts;
  final Box<ResumePointer> _pointers;

  const LearningContextSyncService({
    required SupabaseClient client,
    required Box<LearningContext> contexts,
    required Box<ResumePointer> pointers,
  })  : _client = client,
        _contexts = contexts,
        _pointers = pointers;

  Future<SyncReport> sync(String userId) async {
    if (userId == 'local-user' || userId.isEmpty) {
      return const SyncReport.skipped('signed out');
    }

    try {
      final remoteContexts = await _client
          .from('learning_contexts')
          .select()
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 8));
      final remotePointers = await _client
          .from('resume_pointers')
          .select()
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 8));

      final remoteByDedupe = <String, LearningContext>{};
      for (final row in remoteContexts) {
        try {
          final context = LearningContext.fromJson(row);
          remoteByDedupe[context.dedupeKey] = context;
        } catch (e) {
          debugPrint('⚠️ Ignoring malformed remote context: $e');
        }
      }

      var pulled = 0;
      var pushed = 0;
      final rekeyedContextIds = <String, String>{};
      final localContexts = _contexts.values
          .where((context) => context.userId == userId)
          .toList();

      for (final local in localContexts) {
        final remote = remoteByDedupe[local.dedupeKey];
        if (remote == null) {
          await _upsertContext(local);
          pushed++;
        } else if (remote.lastActiveAt.isAfter(local.lastActiveAt)) {
          if (remote.id != local.id) {
            rekeyedContextIds[local.id] = remote.id;
            await _contexts.delete(local.id);
            await _migrateLocalPointerKey(local.id, remote.id);
          }
          await _contexts.put(remote.id, remote);
          pulled++;
        } else {
          final mergedLocal = local.copyWith(id: remote.id);
          await _upsertContext(mergedLocal);
          if (remote.id != local.id) {
            rekeyedContextIds[local.id] = remote.id;
            await _contexts.delete(local.id);
            await _migrateLocalPointerKey(local.id, remote.id);
          }
          await _contexts.put(mergedLocal.id, mergedLocal);
          pushed++;
        }
      }

      final localKeys = localContexts.map((c) => c.dedupeKey).toSet();
      for (final remote in remoteByDedupe.values) {
        if (!localKeys.contains(remote.dedupeKey)) {
          await _contexts.put(remote.id, remote);
          pulled++;
        }
      }

      for (final row in remotePointers) {
        try {
          final pointer = ResumePointer.fromJson(row);
          final local = _pointers.get(pointer.contextId);
          if (local == null || pointer.updatedAt.isAfter(local.updatedAt)) {
            await _pointers.put(pointer.contextId, pointer);
            pulled++;
          }
        } catch (e) {
          debugPrint('⚠️ Ignoring malformed remote resume pointer: $e');
        }
      }

      for (final pointer in _pointers.values) {
        final context = _contexts.get(pointer.contextId);
        if (context?.userId == userId) {
          await _upsertPointer(pointer, userId);
          pushed++;
        }
      }

      final remoteFastPreferences = await fetchRemoteFastPreferences(userId);

      return SyncReport(
        pulled: pulled,
        pushed: pushed,
        rekeyedContextIds: Map<String, String>.unmodifiable(rekeyedContextIds),
        remoteFastPreferences: Map<String, FastPreference>.unmodifiable(
          remoteFastPreferences,
        ),
      );
    } catch (e, stack) {
      debugPrint('⚠️ Learning context sync unavailable: $e\n$stack');
      return SyncReport.failed(e.toString());
    }
  }

  /// Fetches all remote [FastPreference] records for [userId] from
  /// `public.context_fast_preferences` (`TEL-01B`, `TEL-04A`).
  Future<Map<String, FastPreference>> fetchRemoteFastPreferences(
    String userId,
  ) async {
    if (userId == 'local-user' || userId.isEmpty) {
      return const <String, FastPreference>{};
    }
    final remoteFastPreferences = <String, FastPreference>{};
    try {
      final remotePrefsRows = await _client
          .from('context_fast_preferences')
          .select()
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 8));
      for (final row in remotePrefsRows) {
        try {
          final pref = FastPreference.fromJson(
            Map<String, dynamic>.from(row),
          );
          remoteFastPreferences[pref.contextId] = pref;
        } catch (e) {
          debugPrint('⚠️ Ignoring malformed remote FastPreference: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not pull context_fast_preferences: $e');
    }
    return remoteFastPreferences;
  }

  /// Performs an atomic server-backed compare-and-set update for a context's
  /// [FastPreference] via `public.update_context_fast_preferences` (`TEL-01B`).
  ///
  /// Never writes Fast preferences into `learning_contexts.scope_config`.
  Future<FastPreferenceRemoteCasResult> syncFastPreferenceCompareAndSet({
    required String contextId,
    required String userId,
    required int expectedRevision,
    required String mutationId,
    required PersistedLearningStrategy strategy,
    int? optionalTotalMinutes,
    DateTime? optionalDeadline,
    Set<String> manualSkippedActivityIds = const {},
    DateTime? nowUtc,
  }) async {
    final rpcRes = await _client
        .rpc(
          'update_context_fast_preferences',
          params: {
            'p_context_id': contextId,
            'p_expected_revision': expectedRevision,
            'p_mutation_id': mutationId,
            'p_strategy': strategy.wireValue,
            'p_optional_total_minutes': optionalTotalMinutes,
            'p_optional_deadline': optionalDeadline?.toUtc().toIso8601String(),
            'p_manual_skipped_activity_ids': manualSkippedActivityIds.toList()
              ..sort(),
          },
        )
        .timeout(const Duration(seconds: 8));

    if (rpcRes is! Map) {
      throw StateError(
        'Unexpected response from update_context_fast_preferences RPC: $rpcRes',
      );
    }

    final map = Map<String, dynamic>.from(rpcRes);
    final conflicted = map['conflict'] == true;
    final prefJson = map['preference'] is Map
        ? Map<String, dynamic>.from(map['preference'] as Map)
        : map;
    prefJson['context_id'] ??= contextId;
    prefJson['user_id'] ??= userId;
    final pref = FastPreference.fromJson(prefJson);

    return FastPreferenceRemoteCasResult(
      conflicted: conflicted,
      authoritativePreference: pref,
    );
  }

  Future<void> _migrateLocalPointerKey(String oldId, String newId) async {
    final oldPointer = _pointers.get(oldId);
    if (oldPointer == null) return;
    await _pointers.delete(oldId);
    final existingNew = _pointers.get(newId);
    if (existingNew == null ||
        oldPointer.updatedAt.isAfter(existingNew.updatedAt)) {
      await _pointers.put(
        newId,
        ResumePointer(
          contextId: newId,
          kind: oldPointer.kind,
          activityId: oldPointer.activityId,
          itemIndex: oldPointer.itemIndex,
          courseId: oldPointer.courseId,
          moduleId: oldPointer.moduleId,
          updatedAt: oldPointer.updatedAt,
        ),
      );
    }
  }

  Future<void> _upsertContext(LearningContext context) async {
    await _client.from('learning_contexts').upsert({
      ...context.toJson(),
      'created_at': context.lastActiveAt.toIso8601String(),
    });
  }

  Future<void> _upsertPointer(ResumePointer pointer, String userId) async {
    await _client.from('resume_pointers').upsert({
      ...pointer.toJson(),
      'user_id': userId,
    });
  }
}

class SyncReport {
  final int pulled;
  final int pushed;
  final String? error;
  final bool skipped;
  final Map<String, String> rekeyedContextIds;
  final Map<String, FastPreference> remoteFastPreferences;

  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.error,
    this.skipped = false,
    this.rekeyedContextIds = const {},
    this.remoteFastPreferences = const {},
  });

  const SyncReport.skipped(String reason)
      : pulled = 0,
        pushed = 0,
        error = reason,
        skipped = true,
        rekeyedContextIds = const {},
        remoteFastPreferences = const {};

  const SyncReport.failed(String reason)
      : pulled = 0,
        pushed = 0,
        error = reason,
        skipped = false,
        rekeyedContextIds = const {},
        remoteFastPreferences = const {};

  bool get succeeded => error == null || skipped;
}
