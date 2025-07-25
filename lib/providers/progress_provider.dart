import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProgressProvider = StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
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

  void startLesson(String lessonId, String userId) {
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

  void answerQuestion(bool isCorrect) {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      state = ProgressLoaded(
        UserProgress(
          id: progress.id,
          userId: progress.userId,
          lessonId: progress.lessonId,
          date: progress.date,
          questionsAnswered: progress.questionsAnswered + 1,
          correctCount: isCorrect ? progress.correctCount + 1 : progress.correctCount,
          lessonCompleted: progress.lessonCompleted,
          studyTimeMinutes: progress.studyTimeMinutes,
        ),
      );
    }
  }

  void completeLesson() {
    if (state is ProgressLoaded) {
      final currentState = state as ProgressLoaded;
      final progress = currentState.progress;
      state = ProgressLoaded(
        UserProgress(
          id: progress.id,
          userId: progress.userId,
          lessonId: progress.lessonId,
          date: progress.date,
          questionsAnswered: progress.questionsAnswered,
          correctCount: progress.correctCount,
          lessonCompleted: true,
          studyTimeMinutes: progress.studyTimeMinutes,
        ),
      );
    }
  }
}

abstract class ProgressState {}

class ProgressInitial extends ProgressState {}

class ProgressLoaded extends ProgressState {
  final UserProgress progress;
  ProgressLoaded(this.progress);
}
