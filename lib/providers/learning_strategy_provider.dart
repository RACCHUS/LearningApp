import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fast_plan_result.dart';
import '../models/learning_context.dart';
import '../models/learning_strategy.dart';
import '../models/scope.dart';
import '../services/planning/content_coverage_service.dart';
import '../services/planning/learning_strategy_planner.dart';
import '../services/planning/overview_planner.dart';
import 'learning_context_provider.dart';
import 'next_action_provider.dart';
import 'scope_resolver_provider.dart';
import 'site_feature_provider.dart';
import '../services/governance/site_feature_service.dart';

/// Exception thrown when a compare-and-set preference mutation fails due to
/// a stale `expectedRevision` (`TEL-01B`).
class FastPreferenceConflictException implements Exception {
  final String contextId;
  final int expectedRevision;
  final FastPreference authoritativePreference;
  final FastPreference attemptedPreference;

  const FastPreferenceConflictException({
    required this.contextId,
    required this.expectedRevision,
    required this.authoritativePreference,
    required this.attemptedPreference,
  });

  @override
  String toString() =>
      'FastPreferenceConflictException(contextId: $contextId, '
      'expectedRevision: $expectedRevision, '
      'actualRevision: ${authoritativePreference.revision})';
}

/// Queued offline preference mutation awaiting server compare-and-set sync.
class PendingFastPreferenceMutation {
  final String mutationId;
  final String contextId;
  final String? userId;
  final int expectedRevision;
  final PersistedLearningStrategy strategy;
  final int? optionalTotalMinutes;
  final DateTime? optionalDeadline;
  final Set<String> manualSkippedActivityIds;
  final DateTime queuedAt;

  const PendingFastPreferenceMutation({
    required this.mutationId,
    required this.contextId,
    this.userId,
    required this.expectedRevision,
    required this.strategy,
    this.optionalTotalMinutes,
    this.optionalDeadline,
    this.manualSkippedActivityIds = const {},
    required this.queuedAt,
  });

  PendingFastPreferenceMutation copyWithContextId(String newContextId) {
    return PendingFastPreferenceMutation(
      mutationId: mutationId,
      contextId: newContextId,
      userId: userId,
      expectedRevision: expectedRevision,
      strategy: strategy,
      optionalTotalMinutes: optionalTotalMinutes,
      optionalDeadline: optionalDeadline,
      manualSkippedActivityIds: manualSkippedActivityIds,
      queuedAt: queuedAt,
    );
  }
}

/// User-isolated, revision-checked store for per-context [FastPreference] (`TEL-01B`).
///
/// Never mutates `LearningContext.scopeConfig` or participates in whole-context
/// upserts.
class FastPreferenceStore {
  final Map<String, FastPreference> _byStorageKey = {};
  final List<PendingFastPreferenceMutation> _offlineQueue = [];

  static String _storageKey(String? userId, String contextId) {
    final normalizedUser =
        (userId == null || userId.trim().isEmpty) ? '__guest__' : userId.trim();
    return '$normalizedUser::$contextId';
  }

  FastPreference getOrDefault({
    required String contextId,
    String? userId,
  }) {
    final key = _storageKey(userId, contextId);
    return _byStorageKey[key] ??
        FastPreference.defaultStandard(contextId: contextId, userId: userId);
  }

  List<PendingFastPreferenceMutation> get pendingOfflineMutations =>
      List<PendingFastPreferenceMutation>.unmodifiable(_offlineQueue);

  /// Seeds an authoritative server state (e.g., on initial fetch or realtime pull).
  void seedServerPreference(FastPreference preference) {
    final key = _storageKey(preference.userId, preference.contextId);
    _byStorageKey[key] = preference;
  }

  /// Applies an atomic compare-and-set update for [contextId].
  ///
  /// - If [mutationId] matches `current.lastMutationId`, returns `current`
  ///   idempotently without incrementing `revision`.
  /// - If [expectedRevision] does not match `current.revision`, throws
  ///   [FastPreferenceConflictException] without overwriting `current`.
  FastPreference applyCompareAndSet({
    required String contextId,
    String? userId,
    required int expectedRevision,
    required String mutationId,
    required PersistedLearningStrategy strategy,
    int? optionalTotalMinutes,
    bool clearOptionalTotalMinutes = false,
    DateTime? optionalDeadline,
    bool clearOptionalDeadline = false,
    Set<String>? manualSkippedActivityIds,
    DateTime? nowUtc,
  }) {
    final key = _storageKey(userId, contextId);
    final current = _byStorageKey[key] ??
        FastPreference.defaultStandard(contextId: contextId, userId: userId);

    // Idempotent replay check
    if (mutationId.isNotEmpty && current.lastMutationId == mutationId) {
      return current;
    }

    final resolvedMinutes = clearOptionalTotalMinutes
        ? null
        : (optionalTotalMinutes ?? current.optionalTotalMinutes);
    final resolvedDeadline = clearOptionalDeadline
        ? null
        : (optionalDeadline ?? current.optionalDeadline);
    final resolvedSkipped =
        manualSkippedActivityIds ?? current.manualSkippedActivityIds;

    final attempted = current.copyWith(
      userId: userId ?? current.userId,
      strategy: strategy,
      revision: expectedRevision + 1,
      updatedAtServer: (nowUtc ?? DateTime.now()).toUtc(),
      lastMutationId: mutationId,
      optionalTotalMinutes: resolvedMinutes,
      clearOptionalTotalMinutes: clearOptionalTotalMinutes,
      optionalDeadline: resolvedDeadline,
      clearOptionalDeadline: clearOptionalDeadline,
      manualSkippedActivityIds: resolvedSkipped,
    );

    if (expectedRevision != current.revision) {
      throw FastPreferenceConflictException(
        contextId: contextId,
        expectedRevision: expectedRevision,
        authoritativePreference: current,
        attemptedPreference: attempted,
      );
    }

    _byStorageKey[key] = attempted;
    return attempted;
  }

  /// Queues a mutation while offline and updates local state optimistically
  /// only if local revision matches [expectedRevision].
  void enqueueOfflineMutation(PendingFastPreferenceMutation mutation) {
    final existingIdx = _offlineQueue.indexWhere(
      (m) => m.mutationId == mutation.mutationId,
    );
    if (existingIdx >= 0) {
      return; // Idempotent queue entry
    }
    _offlineQueue.add(mutation);
  }

  /// Flushes queued offline mutations against the authoritative store using CAS.
  ///
  /// Any conflicting mutation is removed from the queue and returned in the
  /// conflict list while preserving the authoritative server state.
  List<FastPreferenceConflictException> flushOfflineQueue({DateTime? nowUtc}) {
    final conflicts = <FastPreferenceConflictException>[];
    final queueSnapshot = List<PendingFastPreferenceMutation>.from(
      _offlineQueue,
    );
    _offlineQueue.clear();

    for (final item in queueSnapshot) {
      try {
        applyCompareAndSet(
          contextId: item.contextId,
          userId: item.userId,
          expectedRevision: item.expectedRevision,
          mutationId: item.mutationId,
          strategy: item.strategy,
          optionalTotalMinutes: item.optionalTotalMinutes,
          clearOptionalTotalMinutes: item.optionalTotalMinutes == null,
          optionalDeadline: item.optionalDeadline,
          clearOptionalDeadline: item.optionalDeadline == null,
          manualSkippedActivityIds: item.manualSkippedActivityIds,
          nowUtc: nowUtc,
        );
      } on FastPreferenceConflictException catch (conflict) {
        conflicts.add(conflict);
      }
    }
    return conflicts;
  }

  /// Migrates preference state and any queued offline mutations when a local
  /// context ID is reconciled with an existing server context UUID (`TEL-01B`).
  FastPreference? rekeyContext({
    required String oldContextId,
    required String newContextId,
    String? userId,
  }) {
    if (oldContextId == newContextId) {
      return getOrDefault(contextId: newContextId, userId: userId);
    }

    final oldKey = _storageKey(userId, oldContextId);
    final newKey = _storageKey(userId, newContextId);
    final oldPref = _byStorageKey.remove(oldKey);

    for (var i = 0; i < _offlineQueue.length; i++) {
      if (_offlineQueue[i].contextId == oldContextId &&
          _offlineQueue[i].userId == userId) {
        _offlineQueue[i] = _offlineQueue[i].copyWithContextId(newContextId);
      }
    }

    if (oldPref == null) {
      return _byStorageKey[newKey];
    }

    final existingNew = _byStorageKey[newKey];
    if (existingNew != null && existingNew.revision > oldPref.revision) {
      // Keep higher-revision authoritative preference on target key
      return existingNew;
    }

    final migrated = oldPref.copyWith(contextId: newContextId);
    _byStorageKey[newKey] = migrated;
    return migrated;
  }

  /// Clears all cached preferences and queued mutations for a signed-out user
  /// or guest session to guarantee strict account isolation.
  void clearForUser(String? userId) {
    final prefix =
        '${(userId == null || userId.trim().isEmpty) ? '__guest__' : userId.trim()}::';
    _byStorageKey.removeWhere((key, _) => key.startsWith(prefix));
    _offlineQueue.removeWhere((m) => m.userId == userId);
  }

  void clearAll() {
    _byStorageKey.clear();
    _offlineQueue.clear();
  }
}

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
/// handling, idempotency keys, and context ID re-key support (`TEL-01B`).
class LearningStrategyNotifier extends StateNotifier<LearningStrategyState> {
  final FastPreferenceStore _store;
  final String? _activeUserId;
  int _mutationCounter = 0;

  LearningStrategyNotifier({
    required FastPreferenceStore store,
    required String? activeUserId,
  }) : _store = store,
       _activeUserId = activeUserId,
       super(const LearningStrategyState());

  String _nextMutationId(String contextId) {
    _mutationCounter++;
    return 'mut_${contextId}_${DateTime.now().microsecondsSinceEpoch}_$_mutationCounter';
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

  /// Updates the learning approach (`Standard` vs `Fast`) for [contextId] using
  /// compare-and-set revision validation.
  FastPreference setStrategy({
    required String contextId,
    required PersistedLearningStrategy strategy,
    int? expectedRevision,
    String? mutationId,
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
      snapshot, 'tel.fast',
      runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      preBootstrapDefault: true,
    ),
    overviewEnabled: isSiteFeatureEnabled(
      snapshot, 'tel.overview',
      runtimeReady: SiteFeatureRuntime.snapshotEnabled,
      preBootstrapDefault: true,
    ),
  );
});

/// Dedicated store for per-context [FastPreference] records (`TEL-01B`).
final fastPreferenceStoreProvider = Provider<FastPreferenceStore>((ref) {
  return FastPreferenceStore();
});

/// StateNotifier provider exposing per-context [FastPreference] and strategy selection.
final learningStrategyProvider =
    StateNotifierProvider<LearningStrategyNotifier, LearningStrategyState>((
      ref,
    ) {
      final store = ref.watch(fastPreferenceStoreProvider);
      final userId = ref.watch(learnerIdProvider);
      return LearningStrategyNotifier(store: store, activeUserId: userId);
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
/// when TEL Fast is enabled. Returns `null` when no target context is active
/// or when the TEL Fast feature flag is disabled.
final activeFastPlanProvider = FutureProvider<FastPlanResult?>((ref) async {
  final flags = ref.watch(telFeatureFlagsProvider);
  final activeContext = ref.watch(activeLearningContextProvider);
  if (activeContext == null ||
      activeContext.rootType != ContextRootType.target ||
      !flags.isFastEnabledForTarget(activeContext.rootId, isExamTarget: true)) {
    return null;
  }

  final strategyState = ref.watch(learningStrategyProvider);
  final pref = strategyState.preferenceFor(activeContext.id);

  final scopeResolver = ref.watch(scopeResolverProvider);
  final scope = await scopeResolver.resolveScope(activeContext);
  final coverageService = ref.watch(contentCoverageServiceProvider);
  final planner = ref.watch(learningStrategyPlannerProvider);

  final snapshot = await ref
      .watch(contextSnapshotResolverProvider)
      .resolve(activeContext);

  // Derive completed activity IDs from scope vs remaining
  final completedIds = <String>{};
  for (final activity in scope.orderedActivities) {
    // ContextSnapshotResolver marks completed lessons; if nextActivity is null
    // and officialRequirementsComplete is true, all official lessons are complete.
    if (snapshot.officialRequirementsComplete &&
        activity.source == ScopedActivitySource.official &&
        activity.isRequired) {
      completedIds.add(activity.activityId);
    }
  }

  final coverage = coverageService.buildCoverageForScope(scope: scope);
  return planner.plan(
    scope: scope,
    coverage: coverage,
    asOf: scope.resolvedAt,
    activeStrategy: pref.strategy,
    completedActivityIds: completedIds,
    manualSkippedActivityIds: pref.manualSkippedActivityIds,
    optionalTotalMinutes: pref.optionalTotalMinutes,
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
      final pref = strategyState.preferenceFor(activeContext.id);
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
