import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_event.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synchronized/synchronized.dart';

/// Local-first, account-isolated outbox for append-only learning events (ARCH-1, ARCH-3, FIX-4).
/// Buffers events locally in account-scoped queues and drains them via the `record_events` RPC
/// when network is available and the matching user is authenticated.
class LearningEventOutbox {
  static const int batchSize = 50;

  static String storageKeyForUser(String userId) => 'learning_events_outbox_$userId';

  final SupabaseClient _supabase;
  final ConnectivityService? _connectivityService;
  final SharedPreferences? _prefsOverride;
  final Lock _lock = Lock();
  StreamSubscription<bool>? _connectivitySub;
  Completer<int>? _activeFlushCompleter;

  LearningEventOutbox({
    SupabaseClient? supabase,
    ConnectivityService? connectivityService,
    SharedPreferences? prefsOverride,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _connectivityService = connectivityService,
        _prefsOverride = prefsOverride {
    if (_connectivityService != null) {
      _connectivitySub = _connectivityService.onConnectivityChanged.listen((connected) {
        if (connected) {
          flush();
        }
      });
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  String _getUserKey({String? userId}) {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      return storageKeyForUser(uid);
    }
    return 'learning_events_outbox_anonymous';
  }

  /// Get all currently queued outbox events for the current or specified user
  Future<List<LearningEvent>> getQueuedEvents({String? userId}) async {
    try {
      final prefs = await _getPrefs();
      final key = _getUserKey(userId: userId);
      final rawList = prefs.getStringList(key) ?? [];
      return rawList
          .map((item) => LearningEvent.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error reading learning events outbox: $e');
      }
      return [];
    }
  }

  /// Get pending event count in outbox for the current user
  Future<int> get pendingCount => getPendingCount();

  /// Get pending event count in outbox for a specific user or current user
  Future<int> getPendingCount({String? userId}) async {
    final prefs = await _getPrefs();
    final key = _getUserKey(userId: userId);
    return prefs.getStringList(key)?.length ?? 0;
  }

  /// Enqueue a single learning event and attempt to flush
  Future<void> enqueue(LearningEvent event) async {
    await enqueueAll([event]);
  }

  /// Enqueue multiple learning events with synchronization and attempt to flush
  Future<void> enqueueAll(List<LearningEvent> events) async {
    if (events.isEmpty) return;

    await _lock.synchronized(() async {
      try {
        final prefs = await _getPrefs();
        // Group events by target account queue
        final grouped = <String, List<LearningEvent>>{};
        for (final event in events) {
          final key = _getUserKey(userId: event.userId);
          grouped.putIfAbsent(key, () => []).add(event);
        }

        for (final entry in grouped.entries) {
          final key = entry.key;
          final currentList = prefs.getStringList(key) ?? [];
          final encodedEvents = entry.value.map((e) => jsonEncode(e.toJson())).toList();
          currentList.addAll(encodedEvents);
          await prefs.setStringList(key, currentList);
        }
      } catch (error, stackTrace) {
        if (kDebugMode) {
          print('⚠️ Error saving learning events to local outbox: $error');
        }
        // Never report an event as queued when durable local persistence failed.
        // Propagate the failure so the caller can surface/retry it instead of
        // silently losing learning evidence while offline.
        Error.throwWithStackTrace(error, stackTrace);
      }
    });

    // Trigger asynchronous drain for the active user
    unawaited(flush());
  }

  /// Drain queued events for the authenticated user to Supabase via record_events RPC
  Future<int> flush({String? userId}) async {
    if (_activeFlushCompleter != null) {
      return _activeFlushCompleter!.future;
    }
    final completer = Completer<int>();
    _activeFlushCompleter = completer;

    try {
      final flushed = await _lock.synchronized(() async {
        final currentUserId = userId ?? _supabase.auth.currentUser?.id;
        if (currentUserId == null) {
          // Must be authenticated to drain to Supabase; leave in local account queue
          return 0;
        }

        if (_connectivityService != null) {
          final online = await _connectivityService.isConnected;
          if (!online) {
            return 0;
          }
        }

        final key = storageKeyForUser(currentUserId);
        final prefs = await _getPrefs();
        var rawList = prefs.getStringList(key) ?? [];
        int totalFlushed = 0;

        while (rawList.isNotEmpty) {
          final currentBatchRaw = rawList.take(batchSize).toList();
          final currentBatchEvents = currentBatchRaw
              .map((item) => jsonDecode(item) as Map<String, dynamic>)
              .where((eventMap) {
                // Ensure event is attributed to current user or can be attributed
                final eventUserId = eventMap['user_id'] as String?;
                return eventUserId == null || eventUserId == currentUserId;
              })
              .map((eventMap) {
                // Guarantee user_id is populated with the authenticated user
                eventMap['user_id'] = currentUserId;
                return eventMap;
              })
              .toList();

          try {
            final res = await _supabase.rpc(
              'record_events',
              params: {'p_events': currentBatchEvents},
            );

            // Verify the RPC acknowledged success and processed the batch
            final resMap = res is Map ? res : {};
            final status = resMap['status'] as String?;
            final rawProcessed = resMap['processed_count'];
            final processedCount = rawProcessed is int ? rawProcessed : null;

            // Strict acknowledgment requirement (Gate B):
            // The batch is only removed if status is success AND processed_count exactly equals the submitted batch size.
            // Any missing, zero, negative, or partial processed_count retains the events and breaks out.
            if (status != 'success' ||
                processedCount == null ||
                processedCount <= 0 ||
                processedCount != currentBatchRaw.length) {
              if (kDebugMode) {
                print(
                  '⚠️ record_events RPC failed or unacknowledged: status=$status, '
                  'processed_count=$processedCount, expected=${currentBatchRaw.length}',
                );
              }
              break;
            }

            if (kDebugMode) {
              print('✅ Flushed $processedCount learning events for user $currentUserId. Result: $res');
            }

            // Remove only when the full batch is explicitly acknowledged
            rawList = rawList.skip(processedCount).toList();
            await prefs.setStringList(key, rawList);
            totalFlushed += processedCount;
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to flush learning events batch: $e');
            }
            // Break on failure to avoid endless loop
            break;
          }
        }

        return totalFlushed;
      });

      completer.complete(flushed);
      return flushed;
    } catch (e) {
      completer.complete(0);
      return 0;
    } finally {
      _activeFlushCompleter = null;
    }
  }
}

/// Riverpod provider for LearningEventOutbox
final learningEventOutboxProvider = Provider<LearningEventOutbox>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final outbox = LearningEventOutbox(
    connectivityService: connectivity,
  );
  ref.onDispose(() => outbox.dispose());
  return outbox;
});
