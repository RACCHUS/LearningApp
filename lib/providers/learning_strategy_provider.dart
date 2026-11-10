import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fast_plan_result.dart';
import '../models/learning_context.dart';
import '../models/learning_strategy.dart';
import '../services/learning_context_sync_service.dart';
import '../services/planning/content_coverage_service.dart';
import '../services/planning/learning_strategy_planner.dart';
import '../services/planning/overview_planner.dart';
import 'learning_context_provider.dart';
import 'next_action_provider.dart';
import 'site_feature_provider.dart';
import '../services/governance/site_feature_service.dart';

/// Callback signature for executing server-backed compare-and-set preference updates.
typedef FastPreferenceRemoteCasCallback =
    Future<FastPreferenceRemoteCasResult> Function(
      PendingFastPreferenceMutation mutation,
    );

/// Callback signature for fetching all server-backed [FastPreference] records for a learner.
typedef FastPreferenceRemoteFetchCallback =
    Future<Map<String, FastPreference>> Function(String userId);

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

  Map<String, dynamic> toJson() => {
        'mutation_id': mutationId,
        'context_id': contextId,
        'user_id': userId,
        'expected_revision': expectedRevision,
        'strategy': strategy.wireValue,
        if (optionalTotalMinutes != null)
          'optional_total_minutes': optionalTotalMinutes,
        if (optionalDeadline != null)
          'optional_deadline': optionalDeadline!.toUtc().toIso8601String(),
        'manual_skipped_activity_ids': manualSkippedActivityIds.toList()..sort(),
        'queued_at': queuedAt.toUtc().toIso8601String(),
      };

  factory PendingFastPreferenceMutation.fromJson(Map<String, dynamic> json) {
    final rawSkipped = json['manual_skipped_activity_ids'];
    final skippedSet = <String>{};
    if (rawSkipped is List) {
      for (final item in rawSkipped) {
        if (item is String && item.trim().isNotEmpty) {
          skippedSet.add(item.trim());
        }
      }
    }
    final rawDeadline = json['optional_deadline'];
    final rawQueued = json['queued_at'];
    return PendingFastPreferenceMutation(
      mutationId: (json['mutation_id'] as String?) ?? '',
      contextId: (json['context_id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      expectedRevision: (json['expected_revision'] as num?)?.toInt() ?? 0,
      strategy: PersistedLearningStrategy.fromWire(json['strategy'] as String?),
      optionalTotalMinutes: (json['optional_total_minutes'] as num?)?.toInt(),
      optionalDeadline: rawDeadline is String && rawDeadline.isNotEmpty
          ? DateTime.tryParse(rawDeadline)?.toUtc()
          : null,
      manualSkippedActivityIds: skippedSet,
      queuedAt: rawQueued is String
          ? (DateTime.tryParse(rawQueued)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// User-isolated, revision-checked store for per-context [FastPreference] (`TEL-01B`, `TEL-04A`).
///
/// Persists locally to `SharedPreferences` across reloads and synchronizes
/// across devices via server-backed compare-and-set (`LearningContextSyncService`).
class FastPreferenceStore {
  static const String prefsStorageKey = 'tel.fast_preferences.v1';
  static const String prefsOfflineQueueKey =
      'tel.fast_preferences_offline_queue.v1';

  final Map<String, FastPreference> _byStorageKey = {};
  final List<PendingFastPreferenceMutation> _offlineQueue = [];
  final List<VoidCallback> _listeners = [];
  FastPreferenceRemoteCasCallback? _remoteCasCallback;
  FastPreferenceRemoteFetchCallback? _remoteFetchCallback;
  Future<void>? _pendingPersistenceFuture;
  bool _isHydrated = false;

  FastPreferenceStore({
    FastPreferenceRemoteCasCallback? remoteCasCallback,
    FastPreferenceRemoteFetchCallback? remoteFetchCallback,
  }) : _remoteCasCallback = remoteCasCallback,
       _remoteFetchCallback = remoteFetchCallback;

  bool get isHydrated => _isHydrated;

  void setRemoteCasCallback(FastPreferenceRemoteCasCallback? callback) {
    _remoteCasCallback = callback;
  }

  void setRemoteFetchCallback(FastPreferenceRemoteFetchCallback? callback) {
    _remoteFetchCallback = callback;
  }

  /// Independently fetches remote [FastPreference] records for [userId] and
  /// reconciles them into local state if a [FastPreferenceRemoteFetchCallback]
  /// is configured.
  Future<Map<String, FastPreference>> fetchFromRemoteForUser(
    String? userId,
  ) async {
    final callback = _remoteFetchCallback;
    if (callback == null || !_isRemoteEligibleUser(userId)) {
      return const <String, FastPreference>{};
    }
    try {
      final fetched = await callback(userId!.trim());
      if (fetched.isNotEmpty) {
        reconcileServerPreferences(fetched, fallbackUserId: userId);
      }
      return fetched;
    } catch (e) {
      debugPrint('⚠️ Independent remote FastPreference fetch failed: $e');
      return const <String, FastPreference>{};
    }
  }

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  static String _userPrefix(String? userId) {
    final normalizedUser =
        (userId == null || userId.trim().isEmpty) ? '__guest__' : userId.trim();
    return '$normalizedUser::';
  }

  static String _storageKey(String? userId, String contextId) {
    return '${_userPrefix(userId)}$contextId';
  }

  static bool _isRemoteEligibleUser(String? userId) {
    if (userId == null) return false;
    final trimmed = userId.trim();
    return trimmed.isNotEmpty &&
        trimmed != 'local-user' &&
        trimmed != '__guest__' &&
        trimmed != 'anonymous' &&
        trimmed != 'guest';
  }

  /// Hydrates stored preferences and queued offline mutations from [SharedPreferences].
  ///
  /// Preserves any higher-revision in-memory preferences written before hydration completed.
  Future<void> hydrateFromPrefs([SharedPreferences? prefs]) async {
    try {
      final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
      final rawPrefsJson = resolvedPrefs.getString(prefsStorageKey);
      var changed = false;
      if (rawPrefsJson != null && rawPrefsJson.isNotEmpty) {
        final decoded = jsonDecode(rawPrefsJson);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString();
            final val = entry.value;
            if (val is Map) {
              final loaded = FastPreference.fromJson(
                Map<String, dynamic>.from(val),
              );
              final existing = _byStorageKey[key];
              if (existing == null || loaded.revision > existing.revision) {
                _byStorageKey[key] = loaded;
                changed = true;
              }
            }
          }
        }
      }

      final rawQueueJson = resolvedPrefs.getString(prefsOfflineQueueKey);
      if (rawQueueJson != null && rawQueueJson.isNotEmpty) {
        final decodedQueue = jsonDecode(rawQueueJson);
        if (decodedQueue is List) {
          for (final item in decodedQueue) {
            if (item is Map) {
              final loadedMut = PendingFastPreferenceMutation.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (loadedMut.mutationId.isNotEmpty &&
                  !_offlineQueue.any(
                    (m) => m.mutationId == loadedMut.mutationId,
                  )) {
                _offlineQueue.add(loadedMut);
                changed = true;
              }
            }
          }
        }
      }

      _isHydrated = true;
      if (changed) {
        _notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Could not hydrate FastPreferenceStore: $e');
      _isHydrated = true;
    }
  }

  /// Persists current preference records and offline queue to [SharedPreferences].
  Future<void> persistToPrefs([SharedPreferences? prefs]) async {
    try {
      final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
      final serializedMap = <String, dynamic>{
        for (final entry in _byStorageKey.entries)
          entry.key: entry.value.toJson(),
      };
      await resolvedPrefs.setString(prefsStorageKey, jsonEncode(serializedMap));

      final serializedQueue =
          _offlineQueue.map((item) => item.toJson()).toList();
      await resolvedPrefs.setString(
        prefsOfflineQueueKey,
        jsonEncode(serializedQueue),
      );
    } catch (e) {
      debugPrint('⚠️ Could not persist FastPreferenceStore: $e');
    }
  }

  void _schedulePersist() {
    final prev = _pendingPersistenceFuture;
    _pendingPersistenceFuture = (prev ?? Future.value()).then(
      (_) => persistToPrefs(),
    );
  }

  /// Waits for any in-flight `SharedPreferences` write to finish.
  Future<void> flushPersistence() => _pendingPersistenceFuture ?? Future.value();

  /// Returns all stored preferences belonging to [userId], keyed by `contextId`.
  Map<String, FastPreference> preferencesForUser(String? userId) {
    final prefix = _userPrefix(userId);
    final result = <String, FastPreference>{};
    for (final entry in _byStorageKey.entries) {
      if (entry.key.startsWith(prefix)) {
        result[entry.value.contextId] = entry.value;
      }
    }
    return result;
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
    _schedulePersist();
    _notifyListeners();
  }

  /// Reconciles a batch of remote [FastPreference] records pulled from the server,
  /// updating local storage whenever the remote `revision` is greater than or equal
  /// to the local revision.
  void reconcileServerPreferences(
    Map<String, FastPreference> remotePreferences, {
    String? fallbackUserId,
  }) {
    if (remotePreferences.isEmpty) return;
    var changed = false;
    for (final remote in remotePreferences.values) {
      final resolvedUserId =
          (remote.userId != null && remote.userId!.trim().isNotEmpty)
              ? remote.userId
              : fallbackUserId;
      final aligned = remote.copyWith(userId: resolvedUserId);
      final key = _storageKey(resolvedUserId, aligned.contextId);
      final local = _byStorageKey[key];
      if (local == null || aligned.revision >= local.revision) {
        _byStorageKey[key] = aligned;
        changed = true;
      }
    }
    if (changed) {
      _schedulePersist();
      _notifyListeners();
    }
  }

  /// Synchronizes [mutation] to the remote backend using compare-and-set.
  ///
  /// - If the remote server reports a revision conflict, updates local state to
  ///    the authoritative server preference and throws [FastPreferenceConflictException].
  /// - If the network call fails with a transient/offline error, queues [mutation]
  ///   in `_offlineQueue` so it will be replayed on the next sync.
  Future<FastPreference> syncMutationToRemote(
    PendingFastPreferenceMutation mutation,
  ) async {
    final callback = _remoteCasCallback;
    if (callback == null || !_isRemoteEligibleUser(mutation.userId)) {
      return getOrDefault(
        contextId: mutation.contextId,
        userId: mutation.userId,
      );
    }

    try {
      final result = await callback(mutation);
      _offlineQueue.removeWhere((m) => m.mutationId == mutation.mutationId);
      final authoritative = result.authoritativePreference.copyWith(
        contextId: mutation.contextId,
        userId: mutation.userId ?? result.authoritativePreference.userId,
      );
      seedServerPreference(authoritative);

      if (result.conflicted) {
        final attempted = FastPreference(
          contextId: mutation.contextId,
          userId: mutation.userId,
          strategy: mutation.strategy,
          revision: mutation.expectedRevision + 1,
          updatedAtServer: mutation.queuedAt,
          lastMutationId: mutation.mutationId,
          optionalTotalMinutes: mutation.optionalTotalMinutes,
          optionalDeadline: mutation.optionalDeadline,
          manualSkippedActivityIds: mutation.manualSkippedActivityIds,
        );
        throw FastPreferenceConflictException(
          contextId: mutation.contextId,
          expectedRevision: mutation.expectedRevision,
          authoritativePreference: authoritative,
          attemptedPreference: attempted,
        );
      }

      return authoritative;
    } on FastPreferenceConflictException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Remote FastPreference sync deferred to offline queue: $e');
      enqueueOfflineMutation(mutation);
      return getOrDefault(
        contextId: mutation.contextId,
        userId: mutation.userId,
      );
    }
  }

  /// Flushes queued offline mutations to the remote server when `_remoteCasCallback`
  /// is configured, or falls back to local CAS reconciliation.
  Future<List<FastPreferenceConflictException>> flushOfflineQueueToRemote({
    DateTime? nowUtc,
  }) async {
    if (_remoteCasCallback == null) {
      return flushOfflineQueue(nowUtc: nowUtc);
    }
    final conflicts = <FastPreferenceConflictException>[];
    final queueSnapshot = List<PendingFastPreferenceMutation>.from(
      _offlineQueue,
    );
    _offlineQueue.clear();

    for (final item in queueSnapshot) {
      if (!_isRemoteEligibleUser(item.userId)) {
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
        continue;
      }

      try {
        await syncMutationToRemote(item);
      } on FastPreferenceConflictException catch (conflict) {
        conflicts.add(conflict);
      }
    }
    _schedulePersist();
    return conflicts;
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
    _schedulePersist();
    _notifyListeners();
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
    _schedulePersist();
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
    _schedulePersist();
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
      _schedulePersist();
      return _byStorageKey[newKey];
    }

    final existingNew = _byStorageKey[newKey];
    if (existingNew != null && existingNew.revision > oldPref.revision) {
      // Keep higher-revision authoritative preference on target key
      _schedulePersist();
      _notifyListeners();
      return existingNew;
    }

    final migrated = oldPref.copyWith(contextId: newContextId);
    _byStorageKey[newKey] = migrated;
    _schedulePersist();
    _notifyListeners();
    return migrated;
  }

  /// Clears all cached preferences and queued mutations for a signed-out user
  /// or guest session to guarantee strict account isolation.
  void clearForUser(String? userId) {
    final prefix = _userPrefix(userId);
    _byStorageKey.removeWhere((key, _) => key.startsWith(prefix));
    _offlineQueue.removeWhere((m) => m.userId == userId);
    _schedulePersist();
    _notifyListeners();
  }

  void clearAll() {
    _byStorageKey.clear();
    _offlineQueue.clear();
    _schedulePersist();
    _notifyListeners();
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
    if (fetched.isNotEmpty && mounted) {
      reconcileRemotePreferences(fetched);
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

