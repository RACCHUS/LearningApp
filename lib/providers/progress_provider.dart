import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProgressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  final hiveService = ref.read(hiveServiceProvider);
  return ProgressNotifier(hiveService);
});

final progressHistoryProvider = FutureProvider<List<UserProgress>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  final response = await supabase
      .from('user_progress')
      .select()
      .eq('user_id', userId)
      .order('date', ascending: false)
      .limit(30); // Fetch last 30 days

  return (response as List).map((e) => UserProgress.fromJson(e)).toList();
});

class ProgressNotifier extends StateNotifier<ProgressState> {
  final HiveService _hiveService;
  final _supabase = Supabase.instance.client;
  late final ProgressSyncService _syncService;
  
  ProgressNotifier(this._hiveService) : super(ProgressInitial()) {
    _syncService = ProgressSyncService(_hiveService);
    _init();
  }
  
  Future<void> _init() async {
    // Initial sync if online
    await _syncService.syncProgress();
    
    // Schedule periodic sync
    Timer.periodic(const Duration(minutes: 5), (_) => _syncService.syncProgress());
  }

  Future<void> startLesson({
    required String lessonId,
    required String userId,
    required StudyMode studyMode,
    String? contentId,
  }) async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    final response = await _supabase
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .eq('lesson_id', lessonId)
        .eq('study_mode', studyMode.toString().split('.').last)
        .eq('date', date)
        .maybeSingle();

    if (response != null) {
      state = ProgressLoaded(UserProgress.fromJson(response));
    } else {
      state = ProgressLoaded(
        UserProgress(
          id: '',
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
      final updatedMetadata = {...?progress.metadata, ...?metadata};
      
      final newProgress = progress.copyWith(
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
      };
      
      final newProgress = progress.copyWith(
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
      } catch (e) {
        debugPrint('Background sync failed, will retry later: $e');
        // Sync will be retried on next operation or periodic sync
      }
      
      // Update state with the latest progress
      if (state is ProgressLoaded) {
        state = ProgressLoaded(progress);
      }
    } catch (e) {
      debugPrint('Error saving progress: $e');
      rethrow;
    }
  }
  
  // Track study time in the background
  void trackStudyTime(Duration duration) {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      final newProgress = progress.copyWith(
        studyTimeSeconds: progress.studyTimeSeconds + duration.inSeconds,
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
    } catch (e) {
      debugPrint('Error during manual sync: $e');
      rethrow;
    }
  }
  
  // Debouncing helper to prevent too many rapid saves
  Timer? _saveTimer;
  void _debouncedSave(UserProgress progress) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), () {
      _upsertProgress(progress);
    });
  }
  
  @override
  void dispose() {
    _saveTimer?.cancel();
    // Save any pending changes before disposing
    if (state is ProgressLoaded) {
      _upsertProgress((state as ProgressLoaded).progress);
    }
    super.dispose();
  }
}

abstract class ProgressState {}

class ProgressInitial extends ProgressState {}

class ProgressLoaded extends ProgressState {
  final UserProgress progress;
  ProgressLoaded(this.progress);
}
