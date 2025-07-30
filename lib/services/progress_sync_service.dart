import 'dart:async';
import 'dart:developer';

import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressSyncService {
  final _supabase = Supabase.instance.client;
  final HiveService _hiveService;
  
  // Debounce timer for sync operations
  Timer? _syncDebounceTimer;
  
  ProgressSyncService(this._hiveService);
  
  /// Syncs local progress with the remote server
  Future<void> syncProgress() async {
    try {
      // Get all local progress that needs to be synced
      final localProgress = await _hiveService.getUnsyncedProgress();
      
      if (localProgress.isEmpty) {
        log('No local progress to sync');
        return;
      }
      
      log('Syncing ${localProgress.length} progress items...');
      
      // Group progress by user, lesson, and date to merge duplicates
      final Map<String, UserProgress> mergedProgress = {};
      
      for (final progress in localProgress) {
        final key = '${progress.userId}_${progress.lessonId}_${progress.date.toIso8601String().split('T')[0]}';
        
        if (mergedProgress.containsKey(key)) {
          final existing = mergedProgress[key]!;
          mergedProgress[key] = _mergeProgress(existing, progress);
        } else {
          mergedProgress[key] = progress;
        }
      }
      
      // Upload merged progress to Supabase
      await _uploadProgress(mergedProgress.values.toList());
      
      // Mark progress as synced in local storage
      await _hiveService.markProgressAsSynced(mergedProgress.values.map((p) => p.id).toList());
      
      log('Successfully synced ${mergedProgress.length} progress items');
      
    } catch (e, stackTrace) {
      log('Error syncing progress', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Uploads progress to Supabase
  Future<void> _uploadProgress(List<UserProgress> progressList) async {
    if (progressList.isEmpty) return;
    
    final batch = progressList.map((progress) => {
      'user_id': progress.userId,
      'lesson_id': progress.lessonId,
      'content_id': progress.contentId,
      'study_mode': progress.studyMode.toString().split('.').last,
      'date': progress.date.toIso8601String().split('T')[0],
      'questions_answered': progress.questionsAnswered,
      'correct_count': progress.correctCount,
      'lesson_completed': progress.lessonCompleted,
      'study_time_seconds': progress.studyTimeSeconds,
      'metadata': progress.metadata,
    }).toList();
    
    await _supabase.from('user_progress').upsert(batch);
  }
  
  /// Merges two progress objects, keeping the most recent and complete data
  UserProgress _mergeProgress(UserProgress existing, UserProgress newProgress) {
    return UserProgress(
      id: existing.id,
      userId: existing.userId,
      lessonId: existing.lessonId,
      contentId: newProgress.contentId ?? existing.contentId,
      studyMode: newProgress.studyMode,
      date: newProgress.date.isAfter(existing.date) ? newProgress.date : existing.date,
      questionsAnswered: existing.questionsAnswered + newProgress.questionsAnswered,
      correctCount: existing.correctCount + newProgress.correctCount,
      lessonCompleted: existing.lessonCompleted || newProgress.lessonCompleted,
      studyTimeSeconds: existing.studyTimeSeconds + newProgress.studyTimeSeconds,
      metadata: _mergeMetadata(existing.metadata, newProgress.metadata),
    );
  }
  
  /// Merges metadata from two progress objects
  Map<String, dynamic>? _mergeMetadata(
    Map<String, dynamic>? existing,
    Map<String, dynamic>? newData,
  ) {
    if (existing == null) return newData;
    if (newData == null) return existing;
    
    return {...existing, ...newData};
  }
  
  /// Schedules a sync operation with debouncing
  void scheduleSync() {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(const Duration(seconds: 5), () {
      syncProgress().catchError((e, stackTrace) {
        log('Error in scheduled sync', error: e, stackTrace: stackTrace);
      });
    });
  }
  
  void dispose() {
    _syncDebounceTimer?.cancel();
  }
}
