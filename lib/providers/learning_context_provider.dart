import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/learning_context_service.dart';
import 'package:learning_pwa/services/learning_context_sync_service.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final learningContextServiceProvider = Provider<LearningContextService>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return LearningContextService(
    contexts: hive.learningContextBox,
    pointers: hive.resumePointerBox,
  );
});

final learningContextSyncServiceProvider =
    Provider<LearningContextSyncService>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return LearningContextSyncService(
    client: Supabase.instance.client,
    contexts: hive.learningContextBox,
    pointers: hive.resumePointerBox,
  );
});

final nextActionEngineProvider =
    Provider<NextActionEngine>((ref) => const NextActionEngine());

/// Signed-in user id, or a stable local id so the app works signed-out.
final learnerIdProvider = Provider<String>((ref) {
  return Supabase.instance.client.auth.currentUser?.id ?? 'local-user';
});

class LearningContextsState {
  final List<LearningContext> contexts;
  final String? activeId;
  final bool isLoading;
  final String? error;

  const LearningContextsState({
    this.contexts = const [],
    this.activeId,
    this.isLoading = false,
    this.error,
  });

  LearningContext? get active {
    if (contexts.isEmpty) return null;
    for (final c in contexts) {
      if (c.id == activeId) return c;
    }
    return contexts.first;
  }

  bool get hasAny => contexts.isNotEmpty;

  /// A one-item switcher is noise; render the label as plain text instead.
  bool get showSwitcherControl => contexts.length >= 2;

  LearningContextsState copyWith({
    List<LearningContext>? contexts,
    String? activeId,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LearningContextsState(
      contexts: contexts ?? this.contexts,
      activeId: activeId ?? this.activeId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LearningContextsNotifier extends StateNotifier<LearningContextsState> {
  final LearningContextService? _service;
  final LearningContextSyncService? _sync;
  final NextActionEngine _engine;
  final String _userId;

  static const _kDefaultContext = 'learning.defaultContextId';

  LearningContextsNotifier(
    LearningContextService service,
    this._engine,
    this._userId,
    LearningContextSyncService? sync,
  )   : _service = service,
        _sync = sync,
        super(const LearningContextsState(isLoading: true)) {
    load();
  }

  /// Fixed state with no storage behind it, for widget tests.
  @visibleForTesting
  LearningContextsNotifier.stub(LearningContextsState initial)
      : _service = null,
        _sync = null,
        _engine = const NextActionEngine(),
        _userId = 'test-user',
        super(initial);

  Future<void> load() async {
    final service = _service;
    if (service == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _sync?.sync(_userId);
      final ordered = _engine.orderForSwitcher(service.all(userId: _userId));
      final savedId = await _readDefaultContextId();
      final activeId = ordered.any((c) => c.id == savedId)
          ? savedId
          : (ordered.isNotEmpty ? ordered.first.id : null);
      state = LearningContextsState(contexts: ordered, activeId: activeId);
    } catch (e, stack) {
      debugPrint('❌ Failed to load learning contexts: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your learning. Pull to retry.',
      );
    }
  }

  Future<void> setActive(String contextId) async {
    state = state.copyWith(activeId: contextId);
    try {
      await _service?.touch(contextId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDefaultContext, contextId);
    } catch (e) {
      debugPrint('⚠️ Could not persist active context: $e');
    }
    await load();
  }

  Future<LearningContext?> add({
    required String label,
    required ContextRootType rootType,
    required String rootId,
    String? emoji,
  }) async {
    final service = _service;
    if (service == null) return null;
    try {
      final created = await service.createOrGet(
        userId: _userId,
        label: label,
        rootType: rootType,
        rootId: rootId,
        emoji: emoji,
      );
      await load();
      await setActive(created.id);
      return created;
    } catch (e) {
      debugPrint('❌ Could not start learning "$label": $e');
      state = state.copyWith(error: 'Could not start "$label". Please retry.');
      return null;
    }
  }

  Future<void> archive(String contextId) async {
    try {
      await _service?.setArchived(contextId, archived: true);
      await load();
    } catch (e) {
      debugPrint('⚠️ Could not archive context: $e');
    }
  }

  Future<void> setPinned(String contextId, int sortOrder) async {
    try {
      await _service?.setPinned(contextId, sortOrder: sortOrder);
      await load();
    } catch (e) {
      debugPrint('⚠️ Could not pin context: $e');
    }
  }

  Future<BackfillReport?> runBackfill(List<BackfillSeed> seeds) async {
    final service = _service;
    if (service == null) return null;
    try {
      final report = await service.backfill(userId: _userId, seeds: seeds);
      await load();
      return report;
    } catch (e) {
      debugPrint('❌ Backfill failed: $e');
      return null;
    }
  }

  Future<String?> _readDefaultContextId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kDefaultContext);
    } catch (_) {
      return null;
    }
  }
}

final learningContextsProvider =
    StateNotifierProvider<LearningContextsNotifier, LearningContextsState>((ref) {
  return LearningContextsNotifier(
    ref.watch(learningContextServiceProvider),
    ref.watch(nextActionEngineProvider),
    ref.watch(learnerIdProvider),
    ref.watch(learningContextSyncServiceProvider),
  );
});

final activeLearningContextProvider = Provider<LearningContext?>((ref) {
  return ref.watch(learningContextsProvider).active;
});

final resumePointerProvider =
    Provider.family<ResumePointer?, String>((ref, contextId) {
  return ref.watch(learningContextServiceProvider).resumeFor(contextId);
});
