import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:uuid/uuid.dart';
import '../models/lesson_progress.dart' as progress_model;
import '../screens/progress/progress_dashboard_screen.dart';
import '../services/hive_service.dart';
import 'next_action_provider.dart';
import 'available_lessons_provider.dart';

/// Highest SM-2 repetition level treated as fully mastered.
const int kMaxMasteryLevel = 6;

/// Average normalized SM-2 mastery (0.0–1.0) for a set of repetition levels.
///
/// Each item contributes `min(level, kMaxMasteryLevel) / kMaxMasteryLevel`.
/// Returns null when there are no reviewable items (mastery is unknown, which
/// the UI shows differently from 0%).
double? computeMastery(List<int> repetitionLevels) {
  if (repetitionLevels.isEmpty) return null;
  final total = repetitionLevels.fold<double>(
    0.0,
    (sum, level) => sum + (level.clamp(0, kMaxMasteryLevel) / kMaxMasteryLevel),
  );
  return total / repetitionLevels.length;
}

/// Granular mastery for a lesson (0.0–1.0), or null if the user has no review
/// items for it yet. Derived from the spaced-repetition levels of its items.
final lessonMasteryProvider =
    FutureProvider.family<double?, String>((ref, lessonId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('review_items')
        .select('repetition_level')
        .eq('user_id', userId)
        .eq('lesson_id', lessonId);

    final levels = (response as List)
        .map((r) => (r['repetition_level'] as int?) ?? 0)
        .toList();
    return computeMastery(levels);
  } catch (e) {
    // Non-critical — hide the mastery label on failure.
    return null;
  }
});

/// Timestamp of the most recent study session for a lesson, or null if never
/// studied. Used to gently discourage cramming (re-studying too soon).
final lessonLastStudiedProvider =
    FutureProvider.family<DateTime?, String>((ref, lessonId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  final kind = progress_model.isLegacyProgressLessonId(lessonId)
      ? 'legacy_lesson'
      : 'bundled_asset_lesson';
  final response = await Supabase.instance.client
      .from('learner_activity_progress')
      .select('reporting_date_utc')
      .eq('user_id', userId)
      .eq('content_kind', kind)
      .eq('content_id', lessonId)
      .order('reporting_date_utc', ascending: false)
      .limit(1)
      .maybeSingle();
  if (response == null) return null;
  return DateTime.parse('${response['reporting_date_utc']}T00:00:00Z');
});

/// Provider for individual lesson progress (0.0 to 1.0)
/// 
/// Fetches from Supabase user_progress table
final lessonProgressProvider =
    FutureProvider.family<double, String>((ref, lessonId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0.0;
  final kind = progress_model.isLegacyProgressLessonId(lessonId)
      ? 'legacy_lesson'
      : 'bundled_asset_lesson';
  // Network/auth failures surface as AsyncError, not a fabricated 0%.
  final response = await Supabase.instance.client
      .from('learner_activity_progress')
      .select('completed,active_seconds')
      .eq('user_id', userId)
      .eq('content_kind', kind)
      .eq('content_id', lessonId)
      .order('reporting_date_utc', ascending: false)
      .limit(1)
      .maybeSingle();
  if (response == null) return 0.0; // No recorded activity.
  if (response['completed'] == true) return 1.0;
  final seconds = response['active_seconds'] as int?;
  return seconds != null && seconds > 0 ? 0.5 : 0.0;
});

/// Provider for the most recent incomplete lesson (for "Continue Learning" feature)
final continueLearningSuggestionProvider =
    FutureProvider<ContinueLearningSuggestion?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  // Resume position is stored locally, not in the canonical daily projection.
  // The old Supabase query referenced a last_position column that never existed.
  final hive = ref.read(hiveServiceProvider);
  await hive.init();
  final local = await hive.getProgress();
  final candidates = local
      .where((p) => p.userId == userId &&
          !p.lessonCompleted && p.lastPosition != null)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (candidates.isEmpty) return null;
  final lessons = await ref.read(assetLessonsProvider.future);
  for (final p in candidates) {
    String? title;
    if (progress_model.isLegacyProgressLessonId(p.lessonId)) {
      final lessonRow = await Supabase.instance.client
          .from('lessons')
          .select('title')
          .eq('id', p.lessonId)
          .maybeSingle();
      title = lessonRow?['title'] as String?;
    } else {
      for (final asset in lessons) {
        if (asset.id == p.lessonId) {
          title = asset.title;
          break;
        }
      }
    }
    if (title == null) continue;
    return ContinueLearningSuggestion(
      lessonId: p.lessonId,
      lessonTitle: title,
      lastPosition: p.lastPosition,
      questionsAnswered: p.questionsAnswered,
      lastStudiedAt: p.date,
    );
  }
  return null;
});

/// Data class for continue learning suggestion
class ContinueLearningSuggestion {
  final String lessonId;
  final String lessonTitle;
  final int? lastPosition;
  final int questionsAnswered;
  final DateTime lastStudiedAt;

  ContinueLearningSuggestion({
    required this.lessonId,
    required this.lessonTitle,
    this.lastPosition,
    required this.questionsAnswered,
    required this.lastStudiedAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(lastStudiedAt);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}

/// Toggle or set a lesson's completion state manually
Future<void> toggleLessonCompletion(
  WidgetRef ref, {
  required String lessonId,
  required bool currentCompleted,
}) async {
  final newCompleted = !currentCompleted;
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  final hive = HiveService();
  await hive.init();
  final progress = progress_model.UserProgress(
    id: const Uuid().v4(),
    userId: userId ?? 'local',
    lessonId: lessonId,
    studyMode: progress_model.StudyMode.lesson,
    date: DateTime.now(),
    questionsAnswered: 0, // Manual completion is not an exam response.
    correctCount: 0,
    lessonCompleted: newCompleted,
    studyTimeSeconds: 0,
    isSynced: false,
    metadata: {
      'completion_override': !newCompleted,
      'active_time_measured': false,
    },
  );

  // Fail before updating the UI if the local completion cannot be saved.
  await hive.cacheProgress(progress);
  if (userId != null) {
    unawaited(_syncManualCompletion(hive, supabase));
  }
  ref.invalidate(lessonProgressProvider(lessonId));
  ref.invalidate(nextActionProvider);
  ref.invalidate(dashboardProgressProvider);
}

Future<void> _syncManualCompletion(
  HiveService hive,
  SupabaseClient supabase,
) async {
  try {
    await ProgressSyncService(hive, supabase).syncProgress();
  } catch (error) {
    debugPrint('Manual completion saved locally; sync pending: $error');
  }
}
