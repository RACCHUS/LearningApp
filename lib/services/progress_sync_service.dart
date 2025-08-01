import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressSyncService {
  final HiveService _hiveService;
  final _supabase = Supabase.instance.client;

  ProgressSyncService(this._hiveService);

  Future<void> syncProgress() async {
    try {
      // Get unsynced progress from local storage
      final unsyncedProgress = await _hiveService.getUnsyncedProgress();

      if (unsyncedProgress.isEmpty) return;

      // Upload to Supabase
      final progressData = unsyncedProgress.map((p) => p.toJson()).toList();
      
      await _supabase.from('user_progress').upsert(progressData);

      // Mark as synced in local storage
      final progressIds = unsyncedProgress.map((p) => p.id).toList();
      await _hiveService.markProgressAsSynced(progressIds);
    } catch (e) {
      throw Exception('Failed to sync progress: $e');
    }
  }

  UserProgress mergeProgress(UserProgress existing, UserProgress newProgress) {
    // Keep the most recent progress based on date
    if (newProgress.date.isAfter(existing.date)) {
      return newProgress;
    }
    return existing;
  }

  Future<void> downloadProgress(String userId) async {
    try {
      final response = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', userId);

      final progressList = (response as List).map((data) => 
        UserProgress.fromJson(data)).toList();

      // Save to local storage
      for (final progress in progressList) {
        await _hiveService.cacheProgress(progress);
      }
    } catch (e) {
      throw Exception('Failed to download progress: $e');
    }
  }
}
