
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/core/network_retry.dart';

class ProgressSyncService {
  final _logger = AppLogger('ProgressSyncService');
  final HiveService _hiveService;
  final SupabaseClient _supabase;

  ProgressSyncService(this._hiveService, [SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<void> syncProgress() async {
    try {
      // Get unsynced progress from local storage
      final unsyncedProgress = await _hiveService.getUnsyncedProgress();

      if (unsyncedProgress.isEmpty) {
        _logger.debug('No progress to sync');
        return;
      }

      _logger.info('Syncing ${unsyncedProgress.length} progress records');

      // Upload to Supabase
      final progressData = unsyncedProgress.map((p) => p.toJson()).toList();
      final progressIds = unsyncedProgress.map((p) => p.id).toList();
      
      // CRITICAL: Only mark as synced AFTER successful server write
      // This prevents data loss if upsert fails
      try {
        await retryWithBackoff(
          () => _supabase.from('user_progress').upsert(progressData),
          label: 'Progress sync upsert',
        );
        
        // SUCCESS: Now safe to mark as synced locally
        await _hiveService.markProgressAsSynced(progressIds);
        
        _logger.info('Successfully synced ${unsyncedProgress.length} progress records');
      } catch (serverError, stackTrace) {
        // Server write failed - DO NOT mark as synced
        _logger.error(
          'Server sync failed - progress remains queued for retry',
          error: serverError,
          stackTrace: stackTrace,
          metadata: {'recordCount': unsyncedProgress.length},
        );
        
        throw SyncException(
          'Failed to sync ${unsyncedProgress.length} progress records',
          'user_progress',
          originalError: serverError,
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      if (e is SyncException) rethrow;
      
      _logger.error(
        'Progress sync failed',
        error: e,
        stackTrace: stackTrace,
      );
      
      throw SyncException(
        'Progress sync operation failed',
        'user_progress',
        originalError: e,
        stackTrace: stackTrace,
      );
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
      _logger.info('Downloading progress for user', metadata: {'userId': userId});
      
      final response = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', userId);

      final progressList = (response as List).map((data) => 
        UserProgress.fromJson(data)).toList();

      _logger.info('Downloaded ${progressList.length} progress records');

      // Save to local storage
      for (final progress in progressList) {
        await _hiveService.cacheProgress(progress);
      }
      
      _logger.info('Successfully cached ${progressList.length} progress records locally');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download progress',
        error: e,
        stackTrace: stackTrace,
        metadata: {'userId': userId},
      );
      
      throw SyncException(
        'Failed to download progress for user',
        'user_progress',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
