import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_event.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local-first outbox for append-only learning events (ARCH-1, ARCH-3, FIX-4).
/// Buffers events locally and drains them via the `record_events` RPC when network is available.
class LearningEventOutbox {
  static const String storageKey = 'learning_events_outbox_queue';
  static const int batchSize = 50;

  final SupabaseClient _supabase;
  final ConnectivityService? _connectivityService;
  final SharedPreferences? _prefsOverride;
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

  /// Get all currently queued outbox events
  Future<List<LearningEvent>> getQueuedEvents() async {
    try {
      final prefs = await _getPrefs();
      final rawList = prefs.getStringList(storageKey) ?? [];
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

  /// Get pending event count in outbox
  Future<int> get pendingCount async {
    final prefs = await _getPrefs();
    return prefs.getStringList(storageKey)?.length ?? 0;
  }

  /// Enqueue a single learning event and attempt to flush
  Future<void> enqueue(LearningEvent event) async {
    await enqueueAll([event]);
  }

  /// Enqueue multiple learning events and attempt to flush
  Future<void> enqueueAll(List<LearningEvent> events) async {
    if (events.isEmpty) return;

    try {
      final prefs = await _getPrefs();
      final currentList = prefs.getStringList(storageKey) ?? [];
      final encodedEvents = events.map((e) => jsonEncode(e.toJson())).toList();
      currentList.addAll(encodedEvents);
      await prefs.setStringList(storageKey, currentList);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error saving learning events to local outbox: $e');
      }
    }

    // Trigger asynchronous drain
    unawaited(flush());
  }

  /// Drain queued events to Supabase via record_events RPC
  Future<int> flush() async {
    if (_activeFlushCompleter != null) {
      return _activeFlushCompleter!.future;
    }
    final completer = Completer<int>();
    _activeFlushCompleter = completer;

    int totalFlushed = 0;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        // Must be authenticated to drain to Supabase; leave in local queue
        completer.complete(0);
        return 0;
      }

      if (_connectivityService != null) {
        final online = await _connectivityService.isConnected;
        if (!online) {
          completer.complete(0);
          return 0;
        }
      }

      final prefs = await _getPrefs();
      var rawList = prefs.getStringList(storageKey) ?? [];

      while (rawList.isNotEmpty) {
        final currentBatchRaw = rawList.take(batchSize).toList();
        final currentBatchEvents = currentBatchRaw
            .map((item) => jsonDecode(item) as Map<String, dynamic>)
            .toList();

        try {
          final res = await _supabase.rpc(
            'record_events',
            params: {'p_events': currentBatchEvents},
          );

          if (kDebugMode) {
            print('✅ Flushed ${currentBatchRaw.length} learning events. Result: $res');
          }

          // Remove the flushed items
          rawList = rawList.skip(currentBatchRaw.length).toList();
          await prefs.setStringList(storageKey, rawList);
          totalFlushed += currentBatchRaw.length;
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to flush learning events batch: $e');
          }
          // Break to prevent rapid spin-fail loop on network or server error
          break;
        }
      }

      completer.complete(totalFlushed);
      return totalFlushed;
    } catch (e) {
      completer.complete(totalFlushed);
      return totalFlushed;
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
