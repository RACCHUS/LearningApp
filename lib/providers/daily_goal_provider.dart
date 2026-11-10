import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/utils/constants.dart';

/// Provider for the user's configured daily goal in minutes
final dailyGoalMinutesProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('dailyGoalMinutes') ?? StudyConstants.defaultStudyGoalMinutes;
});

/// Provider for today's study progress towards the daily goal
final dailyGoalProgressProvider = FutureProvider<DailyGoalProgress>((ref) async {
  final goalMinutes = await ref.watch(dailyGoalMinutesProvider.future);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    // Guests still have a configurable local goal even without cloud progress.
    return DailyGoalProgress(
      studyMinutesToday: 0,
      goalMinutes: goalMinutes,
      isStudyTimeAvailable: false,
    );
  }

  try {
    // Get today's date range
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Query today's study time from user_progress
    final response = await Supabase.instance.client
        .from('user_progress')
        .select('study_time_seconds')
        .eq('user_id', userId)
        .gte('date', todayStart.toIso8601String())
        .lt('date', todayEnd.toIso8601String());

    // Sum up study time
    int totalSeconds = 0;
    for (final record in response) {
      totalSeconds += (record['study_time_seconds'] as int? ?? 0);
    }

    // Legacy clients could write zero for an unmeasured session. Without a
    // positive duration we cannot distinguish no study from missing telemetry.
    if (totalSeconds <= 0) {
      return DailyGoalProgress(
        studyMinutesToday: 0,
        goalMinutes: goalMinutes,
        isStudyTimeAvailable: false,
      );
    }

    final studyMinutes = totalSeconds ~/ 60;

    return DailyGoalProgress(
      studyMinutesToday: studyMinutes,
      goalMinutes: goalMinutes,
    );
  } catch (e) {
    // An unreadable source is not evidence of zero minutes. Keep the goal
    // setting visible but explicitly mark the measurement unavailable.
    return DailyGoalProgress(
      studyMinutesToday: 0,
      goalMinutes: goalMinutes,
      isStudyTimeAvailable: false,
    );
  }
});

/// Data class for daily goal progress
class DailyGoalProgress {
  final int studyMinutesToday;
  final int goalMinutes;

  /// False when cloud duration is missing or unreadable. Zero is not a
  /// trustworthy observation until measured time is available.
  final bool isStudyTimeAvailable;

  DailyGoalProgress({
    required this.studyMinutesToday,
    required this.goalMinutes,
    this.isStudyTimeAvailable = true,
  });

  factory DailyGoalProgress.empty() {
    return DailyGoalProgress(
      studyMinutesToday: 0,
      goalMinutes: StudyConstants.defaultStudyGoalMinutes,
      isStudyTimeAvailable: false,
    );
  }

  /// Progress as a value between 0.0 and 1.0
  double get progress {
    if (goalMinutes <= 0) return 0.0;
    return (studyMinutesToday / goalMinutes).clamp(0.0, 1.0);
  }

  /// Whether the daily goal has been met
  bool get goalMet => isStudyTimeAvailable && studyMinutesToday >= goalMinutes;

  /// Remaining minutes to reach goal
  int get remainingMinutes => (goalMinutes - studyMinutesToday).clamp(0, goalMinutes);

  /// Formatted time string (e.g., "15m" or "1h 30m")
  String get formattedTime {
    if (!isStudyTimeAvailable) return '—';
    if (studyMinutesToday < 60) {
      return '${studyMinutesToday}m';
    }
    final hours = studyMinutesToday ~/ 60;
    final mins = studyMinutesToday % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
