import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final userProgressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  final hiveService = ref.read(hiveServiceProvider);
  return ProgressNotifier(hiveService);
});

final progressHistoryProvider = FutureProvider<List<UserProgress>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return const <UserProgress>[];
  final response = await supabase
      .from('learner_activity_progress')
      .select('content_kind,content_id,version_key,reporting_date_utc,completed,active_seconds')
      .eq('user_id', userId)
      .order('reporting_date_utc', ascending: false)
      .limit(30);
  return response.map((data) =>
      userProgressFromProjection(data, userId: userId)).toList();
});

class ProgressNotifier extends StateNotifier<ProgressState> {
  final HiveService _hiveService;
  final _supabase = Supabase.instance.client;
  late final ProgressSyncService _syncService;
  Timer? _periodicSyncTimer;
  
  ProgressNotifier(this._hiveService) : super(ProgressInitial()) {
    _syncService = ProgressSyncService(_hiveService);
    unawaited(_init());
  }

  Future<void> _init() async {
    await _syncQuietly();
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_syncQuietly()),
    );
  }

  Future<void> _syncQuietly() async {
    try {
      await _syncService.syncProgress();
    } catch (error) {
      debugPrint('Learner progress still queued for retry: $error');
    }
  }

  Future<void> startLesson({
    required String lessonId,
    required String userId,
    required StudyMode studyMode,
    String? contentId,
  }) async {
    final kind = isLegacyProgressLessonId(lessonId)
        ? 'legacy_lesson'
        : 'bundled_asset_lesson';
    final response = await _supabase
        .from('learner_activity_progress')
        .select('content_kind,content_id,version_key,reporting_date_utc,completed,active_seconds')
        .eq('user_id', userId)
        .eq('content_kind', kind)
        .eq('content_id', lessonId)
        .order('reporting_date_utc', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      state = ProgressLoaded(userProgressFromProjection(
        response,
        userId: userId,
        studyMode: studyMode,
      ));
    } else {
      state = ProgressLoaded(
        UserProgress(
          id: const Uuid().v4(),
          userId: userId,
          lessonId: lessonId,
          contentId: contentId,
          studyMode: studyMode,
          date: DateTime.now(),
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: false,
          studyTimeSeconds: 0,
          metadata: {
            'started_at': DateTime.now().toIso8601String(),
            'content_kind': kind,
            'version_key': 'unversioned',
            'active_time_measured': false,
          },
        ),
      );
    }
  }

  Future<void> answerQuestion({
    required bool isCorrect,
    int? studyTimeSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      
      // Calculate study time if not provided
      final elapsedSeconds = studyTimeSeconds ?? 0;
      
      // Merge metadata
      final updatedMetadata = {
        ...?progress.metadata,
        ...?metadata,
        'sync_completion_event': false,
      };
      
      final newProgress = progress.copyWith(
        id: const Uuid().v4(),
        isSynced: false,
        date: DateTime.now(),
        questionsAnswered: progress.questionsAnswered + 1,
        correctCount: isCorrect ? progress.correctCount + 1 : progress.correctCount,
        studyTimeSeconds: progress.studyTimeSeconds + elapsedSeconds,
        metadata: updatedMetadata.isNotEmpty ? updatedMetadata : null,
      );
      
      state = ProgressLoaded(newProgress);
      await _upsertProgress(newProgress);
    }
  }

  Future<void> completeLesson({
    int? studyTimeSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      
      // Calculate study time if not provided
      final elapsedSeconds = studyTimeSeconds ?? 0;
      
      // Merge metadata
      final updatedMetadata = {
        ...?progress.metadata,
        ...?metadata,
        'completed_at': DateTime.now().toIso8601String(),
        'sync_completion_event': true,
      };
      
      final newProgress = progress.copyWith(
        id: const Uuid().v4(),
        isSynced: false,
        date: DateTime.now(),
        lessonCompleted: true,
        studyTimeSeconds: progress.studyTimeSeconds + elapsedSeconds,
        metadata: updatedMetadata,
      );
      
      state = ProgressLoaded(newProgress);
      await _upsertProgress(newProgress);
    }
  }

  Future<void> _upsertProgress(UserProgress progress) async {
    try {
      // Save to local storage first
      await _hiveService.cacheProgress(progress);
      
      // If online, try to sync immediately
      try {
        await _syncService.syncProgress();
      } catch (e, stackTrace) {
        debugPrint('Background sync failed, will retry later: $e');
        debugPrint('Stack trace: $stackTrace');
        // Sync will be retried on next operation or periodic sync
        // Don't fail the save operation if sync fails
      }
      
      // Update state with the latest progress (clear any previous errors)
      state = ProgressLoaded(progress);
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to save progress for lesson: ${progress.lessonId}';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Update state with error but keep the progress
      if (state is ProgressLoaded) {
        state = (state as ProgressLoaded).copyWith(
          progress: progress,
          error: errorMsg,
        );
      } else {
        state = ProgressError(errorMsg);
      }
      rethrow;
    }
  }

  /// Public method to update progress - delegates to private _upsertProgress
  Future<void> updateProgress(UserProgress progress) async {
    await _upsertProgress(progress);
  }
  
  // Track study time in the background
  void trackStudyTime(Duration duration) {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      final newProgress = progress.copyWith(
        studyTimeSeconds: progress.studyTimeSeconds + duration.inSeconds,
        isSynced: false,
        id: const Uuid().v4(),
        metadata: {...?progress.metadata, 'sync_completion_event': false},
      );
      state = ProgressLoaded(newProgress);
      // Debounce the save operation to prevent too many writes
      _debouncedSave(newProgress);
    }
  }
  
  // Force sync all progress data
  Future<void> syncProgress() async {
    try {
      await _syncService.syncProgress();
      // Clear any sync errors on successful sync
      if (state is ProgressLoaded) {
        state = (state as ProgressLoaded).copyWith(error: null);
      }
    } catch (e, stackTrace) {
      const errorMsg = 'Failed to sync progress data';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Update state with error if we have loaded progress
      if (state is ProgressLoaded) {
        state = (state as ProgressLoaded).copyWith(error: errorMsg);
      } else {
        state = ProgressError(errorMsg);
      }
      rethrow;
    }
  }
  
  // Debouncing helper to prevent too many rapid saves
  Timer? _saveTimer;
  void _debouncedSave(UserProgress progress) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_persistQuietly(progress));
    });
  }
  
  Future<void> _persistQuietly(UserProgress progress) async {
    try {
      await _upsertProgress(progress);
    } catch (error) {
      debugPrint('Local progress save failed: $error');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _periodicSyncTimer?.cancel();
    // Save any pending changes before disposing
    if (state is ProgressLoaded) {
      unawaited(_persistQuietly((state as ProgressLoaded).progress));
    }
    super.dispose();
  }
}

abstract class ProgressState {
  const ProgressState();
}

class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

class ProgressLoaded extends ProgressState {
  final UserProgress progress;
  final String? error;
  
  const ProgressLoaded(this.progress, {this.error});
  
  bool get hasError => error != null;
  
  ProgressLoaded copyWith({
    UserProgress? progress,
    String? error,
  }) {
    return ProgressLoaded(
      progress ?? this.progress,
      error: error,
    );
  }
}

class ProgressError extends ProgressState {
  final String message;
  const ProgressError(this.message);
}
