import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/services/notification_service.dart';

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  return StudyNotifier();
});

class StudyNotifier extends StateNotifier<StudyState> {
  final NotificationService _notificationService = NotificationService();
  
  StudyNotifier() : super(StudyState.initial()) {
    // Initialize notification service
    _notificationService.init();
  }

  void markTermAsKnown(String termId) {
    // TODO: Implement marking term as known
    // This will update the term's status in the database
    // and adjust the spaced repetition schedule
  }

  void markTermAsDifficult(String termId) {
    // TODO: Implement marking term as difficult
    // This will update the term's status in the database
    // and adjust the spaced repetition schedule
  }

  void markAnswerCorrect() {
    state = state.copyWith(
      correctAnswers: state.correctAnswers + 1,
      cardsStudied: state.cardsStudied + 1,
    );
  }

  void markAnswerIncorrect() {
    state = state.copyWith(
      incorrectAnswers: state.incorrectAnswers + 1,
      cardsStudied: state.cardsStudied + 1,
    );
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

  StudyState({
    this.isLoading = false,
    this.error,
    this.cardsStudied = 0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    Map<String, bool>? termStatus,
    Map<String, DateTime>? completedLessons,
    this.lastStudied,
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
      
      await _notificationService.scheduleStudyReminder(reminder);
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
