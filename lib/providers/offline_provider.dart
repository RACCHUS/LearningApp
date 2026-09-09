import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/connectivity_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final offlineProvider =
    StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  final connectivityService = ref.read(connectivityServiceProvider);
  return OfflineNotifier(ref.read(hiveServiceProvider), connectivityService);
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final HiveService _hiveService;
  final ConnectivityService _connectivityService;
  final _supabase = Supabase.instance.client;
  
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
    // Prevent concurrent sync operations
    if (state.isSyncing) return;
    
    state = state.copyWith(isSyncing: true, error: null);
    try {
      // Only push records that haven't been confirmed by the server yet.
      final offlineProgress = await _hiveService.getUnsyncedProgress();
      if (offlineProgress.isEmpty) {
        state = state.copyWith(isSyncing: false, lastSyncTime: DateTime.now());
        return;
      }

      // Group by userId, lessonId, date. Track which source record IDs feed
      // each merged row so we can mark exactly those as synced afterwards.
      final Map<String, UserProgress> merged = {};
      final Map<String, List<String>> sourceIds = {};
      for (final p in offlineProgress) {
        final key = '${p.userId}_${p.lessonId}_${p.date.toIso8601String().split('T')[0]}';
        (sourceIds[key] ??= <String>[]).add(p.id);
        if (!merged.containsKey(key)) {
          merged[key] = p;
        } else {
          final existing = merged[key]!;
          merged[key] = UserProgress(
            id: p.id.isNotEmpty ? p.id : existing.id,
            userId: p.userId,
            lessonId: p.lessonId,
            contentId: p.contentId,
            studyMode: p.studyMode,
            date: p.date,
            questionsAnswered: existing.questionsAnswered + p.questionsAnswered,
            correctCount: existing.correctCount + p.correctCount,
            lessonCompleted: existing.lessonCompleted || p.lessonCompleted,
            studyTimeSeconds: existing.studyTimeSeconds + p.studyTimeSeconds,
            isSynced: existing.isSynced && p.isSynced,
            metadata: p.metadata ?? existing.metadata,
          );
        }
      }

      await _supabase.from('user_progress').upsert(
        merged.values.map((e) => {
          'user_id': e.userId,
          'lesson_id': e.lessonId,
          'date': e.date.toIso8601String().split('T')[0],
          'questions_answered': e.questionsAnswered,
          'correct_count': e.correctCount,
          'lesson_completed': e.lessonCompleted,
          'study_time_seconds': e.studyTimeSeconds,
        }).toList(),
      );

      // Only after the server confirms the upsert, mark the contributing local
      // records as synced. We keep the data locally (no destructive clear) so a
      // mid-flight failure can never lose progress — it is simply retried.
      final syncedIds = [
        for (final ids in sourceIds.values) ...ids,
      ].where((id) => id.isNotEmpty).toList();
      await _hiveService.markProgressAsSynced(syncedIds);

      state = state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        error: null,
      );

      debugPrint('✅ Successfully synced ${merged.length} progress records');
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to sync offline progress';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      state = state.copyWith(
        isSyncing: false,
        error: errorMsg,
      );
      // Don't rethrow - sync will be retried on next connectivity change
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
