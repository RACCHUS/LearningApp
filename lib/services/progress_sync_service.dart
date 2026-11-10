import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/core/network_retry.dart';

/// Synchronizes local, immutable completion actions through the validated RPC.
///
/// Do not upload UserProgress.toJson(): it contains Hive-only fields and an
/// identifier that is not a server UUID. Active study time and question
/// counters stay local until a measured, validated server event exists.
class ProgressSyncService {
  final _logger = AppLogger('ProgressSyncService');
  final HiveService _hiveService;
  final SupabaseClient _supabase;

  ProgressSyncService(this._hiveService, [SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? Supabase.instance.client;

  Future<void> syncProgress() async {
    try {
      // No auth client is required to establish that the offline queue is empty.
      // This also keeps test mocks and local-only operation independent of Auth.
      if ((await _hiveService.getUnsyncedProgress()).isEmpty) return;
      final learnerId = _supabase.auth.currentUser?.id;
      if (learnerId == null) return;

      // Iterate in bounded batches; never sync another account's Hive records.
      while (true) {
        final pending = (await _hiveService.getUnsyncedProgress())
            .where((progress) =>
                progress.userId == learnerId &&
                progress.toServerProgressEvent() != null)
            .take(25)
            .toList();
        if (pending.isEmpty) return;

        final events = pending
            .map((progress) => progress.toServerProgressEvent()!)
            .toList();
        final response = await retryWithBackoff<dynamic>(
          () => _supabase.rpc('record_learner_progress', params: {
            'p_events': events,
          }),
          label: 'Progress event sync',
        );
        if (response is! Map) {
          throw StateError('Progress RPC returned an invalid envelope');
        }
        final result = Map<String, dynamic>.from(response);
        final rawResults = result['results'];
        if (result['status'] != 'success' ||
            rawResults is! List ||
            rawResults.length != pending.length ||
            result['processed_count'] != pending.length) {
          throw StateError('Progress RPC did not acknowledge the complete batch');
        }

        for (var i = 0; i < pending.length; i++) {
          if (rawResults[i] is! Map) {
            throw StateError('Progress RPC returned an invalid event ACK');
          }
          final ack = Map<String, dynamic>.from(rawResults[i] as Map);
          if (ack['idempotency_key'] != pending[i].id ||
              (ack['status'] != 'accepted' &&
                  ack['status'] != 'duplicate_noop')) {
            throw StateError('Progress event rejected; retaining offline queue');
          }
        }

        // Account switches must not mark the previous learner's queue synced.
        if (_supabase.auth.currentUser?.id != learnerId) {
          throw StateError('Account switched during progress synchronization');
        }
        await _hiveService
            .markProgressAsSynced(pending.map((p) => p.id).toList());
        _logger.info('Acknowledged ${pending.length} learner progress events');
      }
    } catch (e, stackTrace) {
      _logger.error('Progress sync failed; local events remain retryable',
          error: e, stackTrace: stackTrace);
      throw SyncException(
        'Progress events could not be synchronized',
        'learner_activity_progress',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  UserProgress mergeProgress(UserProgress existing, UserProgress newProgress) {
    return newProgress.date.isAfter(existing.date) ? newProgress : existing;
  }

  Future<void> downloadProgress(String userId) async {
    if (_supabase.auth.currentUser?.id != userId) {
      throw SyncException(
        'Cannot download another account\'s progress',
        'learner_activity_progress',
      );
    }
    try {
      // Projection rows have a different contract from local UserProgress JSON.
      final response = await _supabase
          .from('learner_activity_progress')
          .select('content_kind,content_id,version_key,reporting_date_utc,completed,active_seconds')
          .eq('user_id', userId)
          .order('reporting_date_utc', ascending: false);

      for (final data in response) {
        if (_supabase.auth.currentUser?.id != userId) {
          throw StateError('Account switched during progress download');
        }
        final contentId = data['content_id'] as String;
        final date = data['reporting_date_utc'] as String;
        final kind = data['content_kind'] as String;
        final version = data['version_key'] as String;
        final seconds = data['active_seconds'] as int?;
        final progress = UserProgress(
          id: 'remote_${userId}_${kind}_${contentId}_${version}_${date}',
          userId: userId,
          lessonId: contentId,
          studyMode: StudyMode.lesson,
          date: DateTime.parse('${date}T00:00:00Z'),
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: data['completed'] == true,
          studyTimeSeconds: seconds ?? 0,
          isSynced: true,
          metadata: {
            'content_kind': kind,
            'version_key': version,
            'active_time_measured': seconds != null,
            'remote_projection': true,
          },
        );
        // Replacement is essential. The normal cacheProgress() merges by
        // summing seconds, and redownloading a projection would double count.
        await _hiveService.cacheRemoteProgress(progress);
      }
      _logger.info('Downloaded learner progress projection successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to download learner progress',
          error: e, stackTrace: stackTrace);
      throw SyncException(
        'Failed to download learner progress',
        'learner_activity_progress',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
