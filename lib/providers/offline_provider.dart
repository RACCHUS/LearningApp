import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final offlineProvider =
    StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  return OfflineNotifier(ref.read(hiveServiceProvider));
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final HiveService _hiveService;
  final _supabase = Supabase.instance.client;

  OfflineNotifier(this._hiveService) : super(const OfflineState()) {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (connectivityResult != ConnectivityResult.none) {
        syncProgress();
      }
    });
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
    state = state.copyWith(isSyncing: true, error: null);
    try {
      final offlineProgress = await _hiveService.getProgress();
      if (offlineProgress.isEmpty) {
        state = state.copyWith(isSyncing: false);
        return;
      }

      // Group by userId, lessonId, date
      final Map<String, UserProgress> merged = {};
      for (final p in offlineProgress) {
        final key = '${p.userId}_${p.lessonId}_${p.date.toIso8601String().split('T')[0]}';
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
      
      await _hiveService.clearProgress();
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
