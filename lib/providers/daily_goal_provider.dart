import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/utils/constants.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/analytics/local_study_day.dart';

/// Provider for the user's configured daily goal in minutes
final dailyGoalMinutesProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('dailyGoalMinutes') ?? StudyConstants.defaultStudyGoalMinutes;
});

/// Conservative local-day goal display. This currently measures ONLY this
/// device's confirmed interaction intervals, not synced cross-device totals.
/// It never presents empty legacy progress or network failures as 0 minutes.
final dailyGoalProgressProvider = FutureProvider<DailyGoalProgress>((ref) async {
  final goalMinutes = await ref.watch(dailyGoalMinutesProvider.future);
  final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local-user';

  try {
    final hive = HiveService();
    await hive.init();
    final seconds = measuredStudySecondsForLocalDay(
      progress: await hive.getProgress(),
      learnerId: userId,
      localNow: DateTime.now(),
    );
    if (seconds == null) {
      return DailyGoalProgress(
        studyMinutesToday: 0,
        goalMinutes: goalMinutes,
        isStudyTimeAvailable: false,
      );
    }
    return DailyGoalProgress(
      studyMinutesToday: seconds ~/ 60,
      studySecondsToday: seconds,
      goalMinutes: goalMinutes,
    );
  } catch (error) {
    // Cache unavailable does not mean the learner studied for zero minutes.
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

  /// Measured on this device only; null when no exact interval data exists.
  final int? studySecondsToday;

  /// False when local duration is missing or unreadable. Zero is not a
  /// trustworthy observation until measured time is available.
  final bool isStudyTimeAvailable;

  DailyGoalProgress({
    required this.studyMinutesToday,
    required this.goalMinutes,
    this.studySecondsToday,
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
    if (!isStudyTimeAvailable) return 0.0;
    final seconds = studySecondsToday ?? studyMinutesToday * 60;
    return (seconds / (goalMinutes * 60)).clamp(0.0, 1.0);
  }

  /// Whether the daily goal has been met
  bool get goalMet => isStudyTimeAvailable &&
      (studySecondsToday ?? studyMinutesToday * 60) >= goalMinutes * 60;

  /// Remaining minutes to reach goal
  int get remainingMinutes => (goalMinutes - studyMinutesToday).clamp(0, goalMinutes);

  /// Formatted time string (e.g., "15m" or "1h 30m")
  String get formattedTime {
    if (!isStudyTimeAvailable) return '—';
    if (studySecondsToday != null &&
        studySecondsToday! > 0 && studyMinutesToday == 0) {
      return '<1m';
    }
    if (studyMinutesToday < 60) {
      return '${studyMinutesToday}m';
    }
    final hours = studyMinutesToday ~/ 60;
    final mins = studyMinutesToday % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
