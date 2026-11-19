import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fast_plan_result.dart';
import '../models/learning_context.dart';
import '../models/learning_strategy.dart';
import '../services/planning/content_coverage_service.dart';
import '../services/planning/learning_strategy_planner.dart';
import '../services/planning/overview_planner.dart';
import 'connectivity_provider.dart';
import 'learning_context_provider.dart';
import 'next_action_provider.dart';
import 'site_feature_provider.dart';
import '../services/governance/site_feature_service.dart';
import '../services/fast_preference_store.dart';

export '../services/fast_preference_store.dart';

/// Immutable state for [LearningStrategyNotifier].
class LearningStrategyState {
  final Map<String, FastPreference> preferencesByContextId;
  final Map<String, FastPreferenceConflictException> conflictsByContextId;

  const LearningStrategyState({
    this.preferencesByContextId = const {},
    this.conflictsByContextId = const {},
  });

  FastPreference preferenceFor(String contextId, {String? userId}) {
    return preferencesByContextId[contextId] ??
        FastPreference.defaultStandard(contextId: contextId, userId: userId);
  }

  FastPreferenceConflictException? conflictFor(String contextId) =>
      conflictsByContextId[contextId];

  LearningStrategyState copyWith({
    Map<String, FastPreference>? preferencesByContextId,
    Map<String, FastPreferenceConflictException>? conflictsByContextId,
  }) {
    return LearningStrategyState(
      preferencesByContextId:
          preferencesByContextId ?? this.preferencesByContextId,
      conflictsByContextId: conflictsByContextId ?? this.conflictsByContextId,
    );
  }
}

/// Riverpod notifier managing per-context [FastPreference] with CAS conflict
/// handling, idempotency keys, durable reload hydration, cross-device sync, and
/// context ID re-key support (`TEL-01B`, `TEL-04A`).
class LearningStrategyNotifier extends StateNotifier<LearningStrategyState> {
  final FastPreferenceStore _store;
  final String? _activeUserId;
  int _mutationCounter = 0;
  Future<void>? _hydrationFuture;
  Future<void>? _remoteSyncFuture;

  LearningStrategyNotifier({
    required FastPreferenceStore store,
    required String? activeUserId,
  }) : _store = store,
       _activeUserId = activeUserId,
       super(
         LearningStrategyState(
           preferencesByContextId: store.preferencesForUser(activeUserId),
         ),
       ) {
    _store.addListener(_onStoreChanged);
    _hydrationFuture = _hydrate();
  }

  Future<void> _hydrate() async {
    if (!_store.isHydrated) {
      await _store.hydrateFromPrefs();
    }
    _syncFromStore();
    final fetched = await _store.fetchFromRemoteForUser(_activeUserId);
    if (!mounted) return;
    if (fetched.isNotEmpty) {
      reconcileRemotePreferences(fetched);
    } else {
      // Replay queued offline mutations even when the server has no
      // preferences yet (e.g. the first Fast preference was set offline).
      replayOfflineQueue();
    }
  }

  /// Waits for initial `SharedPreferences` hydration to complete.
  Future<void> ensureHydrated() => _hydrationFuture ?? Future.value();

  /// Waits for any in-flight remote CAS synchronization to complete.
  Future<void> flushRemoteSync() => _remoteSyncFuture ?? Future.value();

  void _onStoreChanged() {
    _syncFromStore();
  }

  void _syncFromStore() {
    if (!mounted) return;
    final storePrefs = _store.preferencesForUser(_activeUserId);
    final merged = Map<String, FastPreference>.from(
      state.preferencesByContextId,
    );
    var changed = false;
    for (final entry in storePrefs.entries) {
      final current = merged[entry.key];
      if (current == null || entry.value.revision >= current.revision) {
        if (current?.revision != entry.value.revision ||
            current?.strategy != entry.value.strategy ||
            current?.optionalTotalMinutes != entry.value.optionalTotalMinutes ||
            !setEquals(
              current?.manualSkippedActivityIds,
              entry.value.manualSkippedActivityIds,
            )) {
          merged[entry.key] = entry.value;
          changed = true;
        }
      }
    }
    if (changed) {
      state = state.copyWith(preferencesByContextId: merged);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  String _nextMutationId(String contextId) {
    _mutationCounter++;
    return 'mut_${contextId}_${DateTime.now().microsecondsSinceEpoch}_$_mutationCounter';
  }

  void _scheduleRemoteSync(PendingFastPreferenceMutation mutation) {
    final prev = _remoteSyncFuture;
    _remoteSyncFuture = (prev ?? Future.value()).then((_) async {
      try {
        final synced = await _store.syncMutationToRemote(mutation);
        if (!mounted) return;
        final nextPrefs = Map<String, FastPreference>.from(
          state.preferencesByContextId,
        )..[mutation.contextId] = synced;
        state = state.copyWith(preferencesByContextId: nextPrefs);
      } on FastPreferenceConflictException catch (conflict) {
        if (!mounted) return;
        final nextPrefs = Map<String, FastPreference>.from(
          state.preferencesByContextId,
        )..[mutation.contextId] = conflict.authoritativePreference;
        final nextConflicts = Map<String, FastPreferenceConflictException>.from(
          state.conflictsByContextId,
        )..[mutation.contextId] = conflict;
        state = state.copyWith(
          preferencesByContextId: nextPrefs,
          conflictsByContextId: nextConflicts,
        );
      }
    });
  }

  /// Reconciles cross-device [FastPreference] records pulled during context sync
  /// and flushes any pending offline mutations.
  void reconcileRemotePreferences(
    Map<String, FastPreference> remotePreferences,
  ) {
    _store.reconcileServerPreferences(
      remotePreferences,
      fallbackUserId: _activeUserId,
    );
    _syncFromStore();
    _flushOfflineQueue();
  }

  /// Replays queued offline mutations through remote CAS (startup and
  /// reconnection). No-op when remote sync is unavailable so the queue is
  /// kept; failed sends are re-queued.
  void replayOfflineQueue() {
    if (!_store.canSyncRemotely(_activeUserId)) return;
    _flushOfflineQueue();
  }

  void _flushOfflineQueue() {
    if (_store.pendingOfflineMutations.isNotEmpty) {
      final prev = _remoteSyncFuture;
      _remoteSyncFuture = (prev ?? Future.value()).then((_) async {
        final conflicts = await _store.flushOfflineQueueToRemote();
        if (!mounted || conflicts.isEmpty) return;
        final nextPrefs = Map<String, FastPreference>.from(
          state.preferencesByContextId,
        );
        final nextConflicts = Map<String, FastPreferenceConflictException>.from(
          state.conflictsByContextId,
        );
        for (final c in conflicts) {
          nextPrefs[c.contextId] = c.authoritativePreference;
          nextConflicts[c.contextId] = c;
        }
        state = state.copyWith(
          preferencesByContextId: nextPrefs,
          conflictsByContextId: nextConflicts,
        );
      });
    }
  }

  /// Resolves the effective [PersistedLearningStrategy] for [context],
  /// enforcing `Standard` fallback whenever the TEL Fast flag is disabled or
  /// the context is not an eligible target context.
  PersistedLearningStrategy effectiveStrategyFor({
    required LearningContext? context,
    required TelFeatureFlags flags,
  }) {
    if (context == null) return PersistedLearningStrategy.standard;
    final isExamTarget = context.rootType == ContextRootType.target;
    if (!flags.isFastEnabledForTarget(
      context.rootId,
      isExamTarget: isExamTarget,
    )) {
      return PersistedLearningStrategy.standard;
    }
    final pref =
        state.preferencesByContextId[context.id] ??
        _store.getOrDefault(contextId: context.id, userId: _activeUserId);
    return pref.strategy;
  }

  FastPreference preferenceForContext(String contextId) {
    return state.preferencesByContextId[contextId] ??
        _store.getOrDefault(contextId: contextId, userId: _activeUserId);
  }

  /// Updates the learning approach (`Standard` vs `Fast`) and optional budget/skips
  /// for [contextId] using compare-and-set revision validation.
  FastPreference setStrategy({
    required String contextId,
    required PersistedLearningStrategy strategy,
    int? expectedRevision,
    String? mutationId,
    int? optionalTotalMinutes,
    bool clearOptionalTotalMinutes = false,
    DateTime? optionalDeadline,
    bool clearOptionalDeadline = false,
    Set<String>? manualSkippedActivityIds,
  }) {
    final current = preferenceForContext(contextId);
    final rev = expectedRevision ?? current.revision;
    final mutId = mutationId ?? _nextMutationId(contextId);

    try {
      final updated = _store.applyCompareAndSet(
        contextId: contextId,
        userId: _activeUserId,
        expectedRevision: rev,
        mutationId: mutId,
        strategy: strategy,
        optionalTotalMinutes: optionalTotalMinutes,
        clearOptionalTotalMinutes: clearOptionalTotalMinutes,
        optionalDeadline: optionalDeadline,
        clearOptionalDeadline: clearOptionalDeadline,
        manualSkippedActivityIds: manualSkippedActivityIds,
      );
      final nextPrefs = Map<String, FastPreference>.from(
        state.preferencesByContextId,
      )..[contextId] = updated;
      final nextConflicts = Map<String, FastPreferenceConflictException>.from(
        state.conflictsByContextId,
      )..remove(contextId);
      state = state.copyWith(
        preferencesByContextId: nextPrefs,
        conflictsByContextId: nextConflicts,
      );
      _scheduleRemoteSync(
        PendingFastPreferenceMutation(
          mutationId: mutId,
          contextId: contextId,
          userId: _activeUserId,
          expectedRevision: rev,
          strategy: updated.strategy,
          optionalTotalMinutes: updated.optionalTotalMinutes,
          optionalDeadline: updated.optionalDeadline,
          manualSkippedActivityIds: updated.manualSkippedActivityIds,
          queuedAt: updated.updatedAtServer,
        ),
      );
      return updated;
    } on FastPreferenceConflictException catch (conflict) {
      final nextPrefs = Map<String, FastPreference>.from(
        state.preferencesByContextId,
      )..[contextId] = conflict.authoritativePreference;
      final nextConflicts = Map<String, FastPreferenceConflictException>.from(
        state.conflictsByContextId,
      )..[contextId] = conflict;
      state = state.copyWith(
        preferencesByContextId: nextPrefs,
        conflictsByContextId: nextConflicts,
      );
      rethrow;
    }
  }

  /// Updates the optional session/total time budget in minutes for [contextId].
  FastPreference setOptionalBudgetMinutes({
    required String contextId,
    required int? totalMinutes,
    int? expectedRevision,
    String? mutationId,
  }) {
    final current = preferenceForContext(contextId);
    final rev = expectedRevision ?? current.revision;
    final mutId = mutationId ?? _nextMutationId(contextId);

    final updated = _store.applyCompareAndSet(
      contextId: contextId,
      userId: _activeUserId,
      expectedRevision: rev,
      mutationId: mutId,
      strategy: current.strategy,
      optionalTotalMinutes: totalMinutes,
      clearOptionalTotalMinutes: totalMinutes == null || totalMinutes <= 0,
    );
    final nextPrefs = Map<String, FastPreference>.from(
      state.preferencesByContextId,
    )..[contextId] = updated;
    state = state.copyWith(preferencesByContextId: nextPrefs);
    _scheduleRemoteSync(
      PendingFastPreferenceMutation(
        mutationId: mutId,
        contextId: contextId,
        userId: _activeUserId,
        expectedRevision: rev,
        strategy: updated.strategy,
        optionalTotalMinutes: updated.optionalTotalMinutes,
        optionalDeadline: updated.optionalDeadline,
        manualSkippedActivityIds: updated.manualSkippedActivityIds,
        queuedAt: updated.updatedAtServer,
      ),
    );
    return updated;
  }

  /// Toggles manual skip on an activity (marking it `manual_skip`, never mastered).
  FastPreference toggleManualSkip({
    required String contextId,
    required String activityId,
    int? expectedRevision,
    String? mutationId,
  }) {
    final current = preferenceForContext(contextId);
    final rev = expectedRevision ?? current.revision;
    final mutId = mutationId ?? _nextMutationId(contextId);
    final nextSkipped = Set<String>.from(current.manualSkippedActivityIds);
    if (!nextSkipped.add(activityId)) {
      nextSkipped.remove(activityId);
    }

    final updated = _store.applyCompareAndSet(
      contextId: contextId,
      userId: _activeUserId,
      expectedRevision: rev,
      mutationId: mutId,
      strategy: current.strategy,
      manualSkippedActivityIds: nextSkipped,
    );
    final nextPrefs = Map<String, FastPreference>.from(
      state.preferencesByContextId,
    )..[contextId] = updated;
    state = state.copyWith(preferencesByContextId: nextPrefs);
    _scheduleRemoteSync(
      PendingFastPreferenceMutation(
        mutationId: mutId,
        contextId: contextId,
        userId: _activeUserId,
        expectedRevision: rev,
        strategy: updated.strategy,
        optionalTotalMinutes: updated.optionalTotalMinutes,
        optionalDeadline: updated.optionalDeadline,
        manualSkippedActivityIds: updated.manualSkippedActivityIds,
        queuedAt: updated.updatedAtServer,
      ),
    );
    return updated;
  }

  /// Re-keys a preference when a local context ID is replaced by a canonical server UUID.
  void rekeyContext({
    required String oldContextId,
    required String newContextId,
  }) {
    final migrated = _store.rekeyContext(
      oldContextId: oldContextId,
      newContextId: newContextId,
      userId: _activeUserId,
    );
    final nextPrefs = Map<String, FastPreference>.from(
      state.preferencesByContextId,
    )..remove(oldContextId);
    if (migrated != null) {
      nextPrefs[newContextId] = migrated;
    }
    final nextConflicts = Map<String, FastPreferenceConflictException>.from(
      state.conflictsByContextId,
    )..remove(oldContextId);
    state = state.copyWith(
      preferencesByContextId: nextPrefs,
      conflictsByContextId: nextConflicts,
    );
  }

  /// Dismisses a CAS conflict by accepting the authoritative server preference.
  void dismissConflict(String contextId) {
    final nextConflicts = Map<String, FastPreferenceConflictException>.from(
      state.conflictsByContextId,
    )..remove(contextId);
    state = state.copyWith(conflictsByContextId: nextConflicts);
  }
}

/// Feature flags provider for TEL Overview and Fast rollout (`§6`).
final telFeatureFlagsProvider = Provider<TelFeatureFlags>((ref) {
  final snapshot = ref.watch(siteFeatureSnapshotProvider).valueOrNull;
  return TelFeatureFlags(
    // Preserve owner-approved Fast/Overview until runtime bootstrap only.
    // After bootstrap, unavailable snapshots fail closed to Standard/no Tour.
    fastEnabled: isSiteFeatureEnabled(
      snapshot,
      'tel.fast',
      runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      preBootstrapDefault: true,
    ),
    overviewEnabled: isSiteFeatureEnabled(
      snapshot,
      'tel.overview',
      runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      preBootstrapDefault: true,
    ),
  );
});

/// Dedicated store for per-context [FastPreference] records (`TEL-01B`).
final fastPreferenceStoreProvider = Provider<FastPreferenceStore>((ref) {
  final store = FastPreferenceStore();
  try {
    final syncService = ref.watch(learningContextSyncServiceProvider);
    store.setRemoteCasCallback((mutation) {
      return syncService.syncFastPreferenceCompareAndSet(
        contextId: mutation.contextId,
        userId: mutation.userId ?? '',
        expectedRevision: mutation.expectedRevision,
        mutationId: mutation.mutationId,
        strategy: mutation.strategy,
        optionalTotalMinutes: mutation.optionalTotalMinutes,
        optionalDeadline: mutation.optionalDeadline,
        manualSkippedActivityIds: mutation.manualSkippedActivityIds,
        nowUtc: mutation.queuedAt,
      );
    });
    store.setRemoteFetchCallback((userId) {
      return syncService.fetchRemoteFastPreferences(userId);
    });
  } catch (_) {
    // Offline or test environment without Hive/Supabase initialized
  }
  store.hydrateFromPrefs();
  return store;
});

/// StateNotifier provider exposing per-context [FastPreference] and strategy selection.
final learningStrategyProvider =
    StateNotifierProvider<LearningStrategyNotifier, LearningStrategyState>((
      ref,
    ) {
      final store = ref.watch(fastPreferenceStoreProvider);
      final userId = ref.watch(learnerIdProvider);
      final notifier = LearningStrategyNotifier(
        store: store,
        activeUserId: userId,
      );

      try {
        final contextsNotifier = ref.read(learningContextsProvider.notifier);
        void onRekeyed(String oldId, String newId) {
          notifier.rekeyContext(oldContextId: oldId, newContextId: newId);
        }

        void onRemoteSynced(Map<String, FastPreference> remotePrefs) {
          notifier.reconcileRemotePreferences(remotePrefs);
        }

        contextsNotifier.addRekeyListener(onRekeyed);
        contextsNotifier.addRemoteFastPreferencesListener(onRemoteSynced);
        ref.onDispose(() {
          contextsNotifier.removeRekeyListener(onRekeyed);
          contextsNotifier.removeRemoteFastPreferencesListener(onRemoteSynced);
        });
      } catch (_) {}

      try {
        ref.listen<bool>(connectivityProvider, (previous, isOnline) {
          if (isOnline && previous == false) notifier.replayOfflineQueue();
        });
      } catch (_) {}

      return notifier;
    });

/// Pure services for Overview and Fast planning.
final overviewPlannerProvider = Provider<OverviewPlanner>(
  (ref) => const OverviewPlanner(),
);

final contentCoverageServiceProvider = Provider<ContentCoverageService>(
  (ref) => const ContentCoverageService(),
);

final learningStrategyPlannerProvider = Provider<LearningStrategyPlanner>((
  ref,
) {
  return LearningStrategyPlanner(
    coverageService: ref.watch(contentCoverageServiceProvider),
  );
});

/// Computes the deterministic `fast_v1_1` plan for the active target context
/// when TEL Fast is enabled, using real completion state, curriculum node
/// hierarchy, and learner concept/assessment evidence via [ContextSnapshotResolver].
final activeFastPlanProvider = FutureProvider<FastPlanResult?>((ref) async {
  final flags = ref.watch(telFeatureFlagsProvider);
  final activeContext = ref.watch(activeLearningContextProvider);
  if (activeContext == null ||
      activeContext.rootType != ContextRootType.target ||
      !flags.isFastEnabledForTarget(activeContext.rootId, isExamTarget: true)) {
    return null;
  }

  final strategyState = ref.watch(learningStrategyProvider);
  final pref = strategyState.preferenceFor(
    activeContext.id,
    userId: activeContext.userId,
  );

  final resolver = ref.watch(contextSnapshotResolverProvider);
  return resolver.resolveFastPlan(
    activeContext,
    strategyOverride: pref.strategy,
  );
});

/// Resolves the complete primary + secondary action presentation (`RESUME-01`)
/// for the `Learn` screen.
final resolvedActionPresentationProvider =
    FutureProvider<ResolvedActionPresentation>((ref) async {
      final primaryAction = await ref.watch(nextActionProvider.future);
      final flags = ref.watch(telFeatureFlagsProvider);
      final activeContext = ref.watch(activeLearningContextProvider);
      if (activeContext == null ||
          activeContext.rootType != ContextRootType.target ||
          !flags.isFastEnabledForTarget(
            activeContext.rootId,
            isExamTarget: true,
          )) {
        return ResolvedActionPresentation(
          primaryAction: primaryAction,
          activeStrategy: PersistedLearningStrategy.standard,
        );
      }

      final strategyState = ref.watch(learningStrategyProvider);
      final pref = strategyState.preferenceFor(
        activeContext.id,
        userId: activeContext.userId,
      );
      if (pref.strategy != PersistedLearningStrategy.fast) {
        return ResolvedActionPresentation(
          primaryAction: primaryAction,
          activeStrategy: PersistedLearningStrategy.standard,
        );
      }

      final fastPlan = await ref.watch(activeFastPlanProvider.future);
      final planner = ref.watch(learningStrategyPlannerProvider);
      return planner.resolvePresentation(
        primaryAction: primaryAction,
        fastPlan: fastPlan,
        activeStrategy: pref.strategy,
      );
    });
