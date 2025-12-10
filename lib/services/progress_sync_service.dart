import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressSyncService {
  final HiveService _hiveService;
  final SupabaseClient _supabase;

  ProgressSyncService(this._hiveService, [SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<void> syncProgress() async {
    try {
      // Get unsynced progress from local storage
      final unsyncedProgress = await _hiveService.getUnsyncedProgress();

      if (unsyncedProgress.isEmpty) {
        debugPrint('✅ No progress to sync');
        return;
      }

      debugPrint('🔄 Syncing ${unsyncedProgress.length} progress records...');

      // Upload to Supabase
      final progressData = unsyncedProgress.map((p) => p.toJson()).toList();
      
      await _supabase.from('user_progress').upsert(progressData);

      // Mark as synced in local storage
      final progressIds = unsyncedProgress.map((p) => p.id).toList();
      await _hiveService.markProgressAsSynced(progressIds);
      
      debugPrint('✅ Successfully synced ${unsyncedProgress.length} progress records');
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to sync ${(await _hiveService.getUnsyncedProgress()).length} progress records';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception(errorMsg);
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
      debugPrint('🔄 Downloading progress for user: $userId');
      
      final response = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', userId);

      final progressList = (response as List).map((data) => 
        UserProgress.fromJson(data)).toList();

      debugPrint('📥 Downloaded ${progressList.length} progress records');

      // Save to local storage
      for (final progress in progressList) {
        await _hiveService.cacheProgress(progress);
      }
      
      debugPrint('✅ Successfully cached ${progressList.length} progress records locally');
    } catch (e, stackTrace) {
      final errorMsg = 'Failed to download progress for user: $userId';
      debugPrint('$errorMsg - $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception(errorMsg);
    }
  }
}
