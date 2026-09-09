import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort remote synchronization for learning contexts.
///
/// Hive remains the local source of truth. A failed sync is reported to the
/// caller but never prevents the Learn screen from rendering offline.
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
      final localContexts = _contexts.values
          .where((context) => context.userId == userId)
          .toList();

      for (final local in localContexts) {
        final remote = remoteByDedupe[local.dedupeKey];
        if (remote == null) {
          await _upsertContext(local);
          pushed++;
        } else if (remote.lastActiveAt.isAfter(local.lastActiveAt)) {
          await _contexts.put(local.id, remote.copyWith(id: local.id));
          pulled++;
        } else {
          await _upsertContext(local.copyWith(id: remote.id));
          if (remote.id != local.id) {
            await _contexts.delete(local.id);
            await _contexts.put(remote.id, local.copyWith(id: remote.id));
          }
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

      return SyncReport(pulled: pulled, pushed: pushed);
    } catch (e, stack) {
      debugPrint('⚠️ Learning context sync unavailable: $e\n$stack');
      return SyncReport.failed(e.toString());
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

  const SyncReport({
    this.pulled = 0,
    this.pushed = 0,
    this.error,
    this.skipped = false,
  });

  const SyncReport.skipped(String reason)
      : pulled = 0,
        pushed = 0,
        error = reason,
        skipped = true;

  const SyncReport.failed(String reason)
      : pulled = 0,
        pushed = 0,
        error = reason,
        skipped = false;

  bool get succeeded => error == null || skipped;
}
