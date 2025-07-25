import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProgressProvider =
    StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});

final progressHistoryProvider = FutureProvider<List<UserProgress>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;
  final response = await supabase
      .from('user_progress')
      .select()
      .eq('user_id', userId)
      .order('date', ascending: false)
      .limit(30); // Fetch last 30 days

  return (response as List).map((e) => UserProgress.fromJson(e)).toList();
});

class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(ProgressInitial());

  final _supabase = Supabase.instance.client;

  Future<void> startLesson(String lessonId, String userId) async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    final response = await _supabase
        .from('user_progress')
        .select()
        .eq('user_id', userId)
        .eq('lesson_id', lessonId)
        .eq('date', date)
        .maybeSingle();

    if (response != null) {
      state = ProgressLoaded(UserProgress.fromJson(response));
    } else {
      state = ProgressLoaded(
        UserProgress(
          id: '',
          userId: userId,
          lessonId: lessonId,
          date: DateTime.now(),
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: false,
          studyTimeMinutes: 0,
        ),
      );
    }
  }

  Future<void> answerQuestion(bool isCorrect) async {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      final newProgress = UserProgress(
        id: progress.id,
        userId: progress.userId,
        lessonId: progress.lessonId,
        date: progress.date,
        questionsAnswered: progress.questionsAnswered + 1,
        correctCount: isCorrect ? progress.correctCount + 1 : progress.correctCount,
        lessonCompleted: progress.lessonCompleted,
        studyTimeMinutes: progress.studyTimeMinutes,
      );
      state = ProgressLoaded(newProgress);
      await _upsertProgress(newProgress);
    }
  }

  Future<void> completeLesson() async {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      final newProgress = UserProgress(
        id: progress.id,
        userId: progress.userId,
        lessonId: progress.lessonId,
        date: progress.date,
        questionsAnswered: progress.questionsAnswered,
        correctCount: progress.correctCount,
        lessonCompleted: true,
        studyTimeMinutes: progress.studyTimeMinutes,
      );
      state = ProgressLoaded(newProgress);
      await _upsertProgress(newProgress);
    }
  }

  Future<void> _upsertProgress(UserProgress progress) async {
    final response = await _supabase.from('user_progress').upsert({
      'user_id': progress.userId,
      'lesson_id': progress.lessonId,
      'date': progress.date.toIso8601String().split('T')[0],
      'questions_answered': progress.questionsAnswered,
      'correct_count': progress.correctCount,
      'lesson_completed': progress.lessonCompleted,
      'study_time_minutes': progress.studyTimeMinutes,
    }).select();

    if ((state as ProgressLoaded).progress.id.isEmpty) {
      final newProgress = UserProgress.fromJson(response[0]);
      state = ProgressLoaded(newProgress);
    }
  }
}

abstract class ProgressState {}

class ProgressInitial extends ProgressState {}

class ProgressLoaded extends ProgressState {
  final UserProgress progress;
  ProgressLoaded(this.progress);
}
