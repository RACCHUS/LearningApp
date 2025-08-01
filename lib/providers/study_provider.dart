import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/notification_service.dart';
import 'package:learning_pwa/services/lesson_service.dart';

enum StudyMode {
  flashcard,
  mcq,
  concept,
  lesson
}

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  return StudyNotifier();
});

class StudyNotifier extends StateNotifier<StudyState> {
  final NotificationService _notificationService = NotificationService();
  final LessonService _lessonService = LessonService();
  
  StudyNotifier() : super(StudyState.initial()) {
    // Initialize notification service
    _notificationService.init();
  }

  Future<void> startStudySession(String lessonId, StudyMode mode) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentLessonId: lessonId,
      currentMode: mode,
      currentIndex: 0,
    );

    try {
      final lesson = await _lessonService.getLesson(lessonId);
      final content = _getContentForMode(lesson, mode);
      state = state.copyWith(
        currentContent: content,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  List<dynamic> _getContentForMode(Lesson lesson, StudyMode mode) {
    switch (mode) {
      case StudyMode.flashcard:
        return lesson.terms;
      case StudyMode.mcq:
        return lesson.questions;
      case StudyMode.concept:
        return lesson.concepts;
      case StudyMode.lesson:
        final content = [
          ...lesson.terms,
          ...lesson.questions,
          ...lesson.concepts,
        ];
        content.shuffle();
        return content;
    }
  }

  void markTermAsKnown(String termId) {
    state = state.copyWith(
      termStatus: {...state.termStatus, termId: true}
    );
  }

  void markTermAsDifficult(String termId) {
    state = state.copyWith(
      termStatus: {...state.termStatus, termId: false}
    );
  }

  void markAnswerCorrect() {
    state = state.copyWith(
      correctAnswers: state.correctAnswers + 1,
      cardsStudied: state.cardsStudied + 1,
    );
    next();
  }

  void markAnswerIncorrect() {
    state = state.copyWith(
      incorrectAnswers: state.incorrectAnswers + 1,
      cardsStudied: state.cardsStudied + 1,
    );
    next();
  }
  
  void next() {
    if (state.currentContent != null && 
        state.currentIndex < state.currentContent!.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
      );
    }
  }

  void previous() {
    if (state.currentIndex > 0) {
      state = state.copyWith(
        currentIndex: state.currentIndex - 1,
      );
    }
  }

  Future<void> markLessonAsCompleted(String lessonId, {String? lessonTitle, int? durationMinutes}) async {
    try {
      // Update local state
      state = state.copyWith(
        completedLessons: {...state.completedLessons, lessonId: DateTime.now()},
      );
      
      // Schedule next study session reminder if this was a significant study session
      if (durationMinutes != null && durationMinutes >= 15) {
        await _scheduleNextStudyReminder(lessonTitle);
      }
      
      // TODO: Sync with backend
      // await _supabaseService.updateLessonProgress(lessonId, true);
    } catch (e) {
      debugPrint('Error marking lesson as completed: $e');
      rethrow;
    }
  }
  
  /// Schedule a reminder for the next study session
  Future<void> _scheduleNextStudyReminder(String? lessonTitle) async {
    try {
      // Default to 24 hours from now
      final nextDay = DateTime.now().add(const Duration(hours: 24));
      final nextStudyTime = TimeOfDay(hour: nextDay.hour, minute: nextDay.minute);
      
      final reminder = Reminder(
        id: 'next_study_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current_user', // This should be replaced with actual user ID
        title: 'Continue Learning',
        message: lessonTitle != null 
            ? 'Time to continue with "$lessonTitle"' 
            : 'Time for your next study session!',
        timeOfDay: nextStudyTime,
        frequency: ReminderFrequency.daily,
        type: ReminderType.study,
        isActive: true,
        isRepeating: false,
      );
      
      await _notificationService.scheduleStudyReminder(reminder);
    } catch (e) {
      debugPrint('Error scheduling next study reminder: $e');
      // Don't throw, as this shouldn't block the main operation
    }
  }

  void resetStudySession() {
    state = StudyState.initial();
  }
}

class StudyState {
  final bool isLoading;
  final String? error;
  final int cardsStudied;
  final int correctAnswers;
  final int incorrectAnswers;
  final Map<String, bool> termStatus; // termId -> isKnown
  final Map<String, DateTime> completedLessons; // lessonId -> completionTime
  final DateTime? lastStudied;
  final String? currentLessonId;
  final StudyMode? currentMode;
  final int currentIndex;
  final List<dynamic>? currentContent;

  StudyState({
    this.isLoading = false,
    this.error,
    this.cardsStudied = 0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    Map<String, bool>? termStatus,
    Map<String, DateTime>? completedLessons,
    this.lastStudied,
    this.currentLessonId,
    this.currentMode,
    this.currentIndex = 0,
    this.currentContent,
  }) : 
    termStatus = termStatus ?? {},
    completedLessons = completedLessons ?? {};

  factory StudyState.initial() => StudyState(lastStudied: DateTime.now());

  StudyState copyWith({
    bool? isLoading,
    String? error,
    int? cardsStudied,
    int? correctAnswers,
    int? incorrectAnswers,
    Map<String, bool>? termStatus,
    Map<String, DateTime>? completedLessons,
    DateTime? lastStudied,
    String? currentLessonId,
    StudyMode? currentMode,
    int? currentIndex,
    List<dynamic>? currentContent,
  }) {
    return StudyState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cardsStudied: cardsStudied ?? this.cardsStudied,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      incorrectAnswers: incorrectAnswers ?? this.incorrectAnswers,
      termStatus: termStatus ?? this.termStatus,
      completedLessons: completedLessons ?? this.completedLessons,
      lastStudied: lastStudied ?? this.lastStudied,
      currentLessonId: currentLessonId ?? this.currentLessonId,
      currentMode: currentMode ?? this.currentMode,
      currentIndex: currentIndex ?? this.currentIndex,
      currentContent: currentContent ?? this.currentContent,
    );
  }

  // Helper methods
  bool isTermKnown(String termId) => termStatus[termId] ?? false;
  
  /// Schedule a reminder for a specific term
  Future<void> scheduleTermReminder(String term, String definition) async {
    try {
      final reminder = Reminder(
        id: 'term_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current_user', // This should be replaced with actual user ID
        title: 'Review Term: $term',
        message: 'Remember: $definition',
        timeOfDay: TimeOfDay.now().replacing(
          minute: (TimeOfDay.now().minute + 30) % 60,
        ),
        frequency: ReminderFrequency.daily,
        type: ReminderType.study,
        isActive: true,
        isRepeating: true,
      );
      
      await NotificationService().scheduleStudyReminder(reminder);
    } catch (e) {
      debugPrint('Error scheduling term reminder: $e');
      rethrow;
    }
  }
  
  double get accuracy {
    final total = correctAnswers + incorrectAnswers;
    return total > 0 ? correctAnswers / total : 0.0;
  }

  int get totalQuestions => correctAnswers + incorrectAnswers;
}
