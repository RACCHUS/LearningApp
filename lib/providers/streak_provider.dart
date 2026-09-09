import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/progress_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the current user's learning streak
final streakProvider = FutureProvider<LearningStreak>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    return LearningStreak(
      userId: '',
      currentStreak: 0,
      longestStreak: 0,
    );
  }
  return ProgressService.getLearningStreak(userId);
});

/// Provider for just the current streak count (for quick access)
final currentStreakProvider = Provider<int>((ref) {
  final streakAsync = ref.watch(streakProvider);
  return streakAsync.when(
    data: (streak) => streak.currentStreak,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
