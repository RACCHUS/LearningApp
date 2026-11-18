import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fast_plan_result.dart';
import '../models/learning_strategy.dart';
import 'learning_context_sync_service.dart';

// Per-context Fast preference store with offline queue and server
// compare-and-set sync (TEL-01B, TEL-04A). Moved unchanged from
// providers/learning_strategy_provider.dart (code-efficiency plan §14,
// Phase 3); that file re-exports it, so importers are unchanged.

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

  /// Whether queued mutations for [userId] can be sent to the server.
  bool canSyncRemotely(String? userId) =>
      _remoteCasCallback != null && _isRemoteEligibleUser(userId);

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
