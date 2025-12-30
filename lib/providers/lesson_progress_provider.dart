import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
