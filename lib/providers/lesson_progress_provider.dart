import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson_progress.dart' as progress_model;
import '../screens/progress/progress_dashboard_screen.dart';
import '../services/hive_service.dart';
import 'next_action_provider.dart';

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

  try {
    final response = await Supabase.instance.client
        .from('user_progress')
        .select('date')
        .eq('user_id', userId)
        .eq('lesson_id', lessonId)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return DateTime.parse(response['date'] as String);
  } catch (e) {
    return null;
  }
});

/// Provider for individual lesson progress (0.0 to 1.0)
/// 
/// Fetches from Supabase user_progress table
final lessonProgressProvider = FutureProvider.family<double, String>((ref, lessonId) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0.0;

  try {
    // Fetch from Supabase
    final response = await Supabase.instance.client
        .from('user_progress')
        .select('lesson_completed, questions_answered')
        .eq('user_id', userId)
        .eq('lesson_id', lessonId)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      final completed = response['lesson_completed'] == true;
      final questionsAnswered = response['questions_answered'] ?? 0;
      
      if (completed) return 1.0;
      if (questionsAnswered > 0) return 0.5; // Started
    }

    return 0.0;
  } catch (e) {
    // Silently fail - progress indicator is non-critical
    return 0.0;
  }
});

/// Provider for the most recent incomplete lesson (for "Continue Learning" feature)
final continueLearningSuggestionProvider = FutureProvider<ContinueLearningSuggestion?>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('user_progress')
        .select('lesson_id, last_position, questions_answered, date')
        .eq('user_id', userId)
        .eq('lesson_completed', false)
        .not('last_position', 'is', null)
        .order('date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      // Get lesson details
      final lessonId = response['lesson_id'] as String;
      final lessonResponse = await Supabase.instance.client
          .from('lessons')
          .select('title')
          .eq('id', lessonId)
          .maybeSingle();

      if (lessonResponse != null) {
        return ContinueLearningSuggestion(
          lessonId: lessonId,
          lessonTitle: lessonResponse['title'] as String,
          lastPosition: response['last_position'] as int?,
          questionsAnswered: response['questions_answered'] as int? ?? 0,
          lastStudiedAt: DateTime.parse(response['date'] as String),
        );
      }
    }

    return null;
  } catch (e) {
    return null;
  }
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

  final now = DateTime.now();
  if (userId != null) {
    try {
      await supabase.from('user_progress').upsert({
        'user_id': userId,
        'lesson_id': lessonId,
        'date': now.toIso8601String().split('T')[0],
        'lesson_completed': newCompleted,
        'questions_answered': newCompleted ? 1 : 0,
        'correct_count': newCompleted ? 1 : 0,
        'study_time_minutes': 0,
        'is_synced': true,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to sync lesson progress to Supabase: $e');
    }
  }

  try {
    final hive = HiveService();
    await hive.init();
    final progress = progress_model.UserProgress(
      id: '${userId ?? "local"}_${lessonId}_${now.millisecondsSinceEpoch}',
      userId: userId ?? 'local',
      lessonId: lessonId,
      studyMode: progress_model.StudyMode.lesson,
      date: now,
      questionsAnswered: newCompleted ? 1 : 0,
      correctCount: newCompleted ? 1 : 0,
      lessonCompleted: newCompleted,
      studyTimeSeconds: 0,
      isSynced: false,
    );
    await hive.cacheProgress(progress);
  } catch (e) {
    debugPrint('⚠️ Failed to cache lesson progress in Hive: $e');
  }

  ref.invalidate(lessonProgressProvider(lessonId));
  ref.invalidate(nextActionProvider);
  ref.invalidate(dashboardProgressProvider);
}
