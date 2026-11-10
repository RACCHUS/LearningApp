import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';

final offlineProvider =
    StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  final connectivityService = ref.read(connectivityServiceProvider);
  return OfflineNotifier(ref.read(hiveServiceProvider), connectivityService);
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final HiveService _hiveService;
  final ConnectivityService _connectivityService;
  
  // Subscription for cleanup
  StreamSubscription<bool>? _connectivitySubscription;

  OfflineNotifier(this._hiveService, this._connectivityService) : super(const OfflineState()) {
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        syncProgress();
      }
    });
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> init() async {
    await _hiveService.init();
  }

  Future<void> cacheLesson(Lesson lesson) async {
    try {
      await _hiveService.cacheLesson(lesson);
      state = state.copyWith(error: null);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to cache lesson: ${lesson.title}';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(error: errorMsg);
      rethrow;
    }
  }

  Future<Lesson?> getLesson(String lessonId) async {
    try {
      return await _hiveService.getLesson(lessonId);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to retrieve cached lesson: $lessonId';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(error: errorMsg);
      return null;
    }
  }

  Future<void> cacheProgress(UserProgress progress) async {
    try {
      await _hiveService.cacheProgress(progress);
      state = state.copyWith(error: null);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to cache progress for lesson: ${progress.lessonId}';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(error: errorMsg);
      rethrow;
    }
  }

  Future<void> syncProgress() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, error: null);
    try {
      // Share one RPC/ACK implementation across offline and online providers.
      // Never merge local snapshots into a last-write-wins table UPSERT.
      await ProgressSyncService(_hiveService).syncProgress();
      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        error: null,
      );
    } catch (e, stackTrace) {
      debugPrint('Offline progress remains queued: $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isSyncing: false,
        error: 'Failed to sync offline progress',
      );
    }
  }
}

class OfflineState {
  final String? error;
  final bool isSyncing;
  final DateTime? lastSyncTime;

  const OfflineState({
    this.error,
    this.isSyncing = false,
    this.lastSyncTime,
  });

  OfflineState copyWith({
    String? error,
    bool? isSyncing,
    DateTime? lastSyncTime,
  }) {
    return OfflineState(
      error: error,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get hasError => error != null;
}
