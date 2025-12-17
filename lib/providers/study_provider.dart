import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/reminder.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_progress.dart' as progress_model;
import 'package:learning_pwa/services/notification_service.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';

enum StudyMode { flashcard, mcq, concept, lesson }

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  return StudyNotifier();
});

class StudyNotifier extends StateNotifier<StudyState> {
  final _logger = AppLogger('StudyNotifier');
  final NotificationService _notificationService = NotificationService();
  final LessonService _lessonService = LessonService();
  final _supabase = Supabase.instance.client;

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

      // Validate lesson has content
      if (lesson.terms.isEmpty &&
          lesson.questions.isEmpty &&
          lesson.concepts.isEmpty) {
        throw LessonLoadException(
          lessonId,
          'Lesson has no content to study',
        );
      }

      final content = _getContentForMode(lesson, mode);

      if (content.isEmpty) {
        throw StudySessionException(
          'No content available for selected study mode',
          code: 'EMPTY_CONTENT',
        );
      }

      state = state.copyWith(
        currentContent: content,
        isLoading: false,
        error: null,
      );

      _logger.info(
        'Study session started',
        metadata: {
          'lessonId': lessonId,
          'mode': mode.toString(),
          'contentCount': content.length,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to start study session',
        error: e,
        stackTrace: stackTrace,
        metadata: {'lessonId': lessonId, 'mode': mode.toString()},
      );

      final userMessage = e is AppException
          ? e.getUserMessage()
          : 'Failed to load lesson. Please try again.';

      state = state.copyWith(
        error: userMessage,
        isLoading: false,
      );
    }
  }

  /// Retry failed study session start
  Future<void> retryStudySession() async {
    if (state.currentLessonId == null || state.currentMode == null) {
      _logger.warn('Cannot retry: no previous session context');
      return;
    }

    _logger.info('Retrying study session');
    await startStudySession(state.currentLessonId!, state.currentMode!);
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
    state = state.copyWith(termStatus: {...state.termStatus, termId: true});
  }

  void markTermAsDifficult(String termId) {
    state = state.copyWith(termStatus: {...state.termStatus, termId: false});
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

  void recordQuestionAnswer(String questionId, int selectedAnswer) {
    // Validate answer index (prevent invalid data)
    final currentItem = state.currentContent?[state.currentIndex];
    if (currentItem != null) {
      // Check if it's a question with options
      final hasOptions =
          currentItem is Map && currentItem.containsKey('options');
      if (hasOptions) {
        final options = currentItem['options'] as List?;
        if (options != null &&
            (selectedAnswer < 0 || selectedAnswer >= options.length)) {
          _logger.error(
            'Invalid answer index',
            metadata: {
              'questionId': questionId,
              'selectedAnswer': selectedAnswer,
              'optionsCount': options.length,
            },
          );
          throw InvalidInputException(
            'Invalid answer selection (index out of range)',
          );
        }
      }
    }

    state = state.copyWith(
      questionAnswers: {...state.questionAnswers, questionId: selectedAnswer},
    );
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
    if (state.currentContent != null && state.currentIndex > 0) {
      state = state.copyWith(
        currentIndex: state.currentIndex - 1,
      );
    }
  }

  /// Mark lesson as completed and save progress
  Future<void> markLessonAsCompleted(String lessonId,
      {String? lessonTitle, int? durationMinutes}) async {
    try {
      // CRITICAL: Must cache progress locally BEFORE claiming success
      bool localCacheSuccess = false;
      final userId = _supabase.auth.currentUser?.id;

      // Cache locally first (most important - user's device)
      if (userId != null) {
        try {
          await _cacheProgressLocally(userId, lessonId, durationMinutes);
          localCacheSuccess = true;
          _logger.info('Progress cached locally');
        } catch (cacheError, stackTrace) {
          _logger.fatal(
            'CRITICAL: Local progress cache failed',
            error: cacheError,
            stackTrace: stackTrace,
            metadata: {'lessonId': lessonId, 'userId': userId},
          );

          // Local cache failure is CRITICAL - don't claim success
          state = state.copyWith(
            error: 'Failed to save progress. Please try again.',
          );

          throw CacheException(
            'Failed to save lesson progress locally',
            originalError: cacheError,
            stackTrace: stackTrace,
          );
        }
      }

      // Sync with backend if user is authenticated
      if (userId != null && localCacheSuccess) {
        try {
          // Create or update progress record in Supabase
          final progressData = {
            'user_id': userId,
            'lesson_id': lessonId,
            'study_mode':
                state.currentMode?.toString().split('.').last ?? 'lesson',
            'lesson_completed': true,
            'cards_studied': state.cardsStudied,
            'correct_count': state.correctAnswers,
            'incorrect_count': state.incorrectAnswers,
            'study_time_seconds':
                durationMinutes != null ? durationMinutes * 60 : 0,
            'date': DateTime.now().toIso8601String(),
            'is_synced': true,
          };

          await _supabase.from('user_progress').upsert(progressData);

          _logger.info('Lesson completion synced to backend');
        } catch (syncError, stackTrace) {
          // Sync error is acceptable since we have local cache
          _logger.warn(
            'Backend sync failed but local cache successful',
            error: syncError,
            stackTrace: stackTrace,
          );
          // Progress will sync later - this is OK
        }
      }

      // Schedule next study session reminder if this was a significant study session
      if (durationMinutes != null && durationMinutes >= 15) {
        try {
          await _scheduleNextStudyReminder(lessonTitle);
        } catch (reminderError) {
          // Reminder failure shouldn't block completion
          _logger.warn('Failed to schedule reminder', error: reminderError);
        }
      }

      // Update state to mark lesson as completed
      state = state.copyWith(
        completedLessons: {...state.completedLessons, lessonId: DateTime.now()},
      );
    } catch (e, stackTrace) {
      if (e is CacheException) rethrow;

      _logger.error(
        'Error marking lesson as completed',
        error: e,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        error: 'Failed to complete lesson. Please try again.',
      );
      rethrow;
    }
  }

  /// Cache progress locally for later sync when offline
  Future<void> _cacheProgressLocally(
      String userId, String lessonId, int? durationMinutes) async {
    try {
      final hiveService = HiveService();
      await hiveService.init();

      // Map local StudyMode to progress_model.StudyMode
      progress_model.StudyMode progressStudyMode;
      switch (state.currentMode) {
        case StudyMode.flashcard:
          progressStudyMode = progress_model.StudyMode.flashcard;
          break;
        case StudyMode.mcq:
          progressStudyMode = progress_model.StudyMode.mcq;
          break;
        case StudyMode.concept:
          progressStudyMode = progress_model.StudyMode.concept;
          break;
        case StudyMode.lesson:
        case null:
          progressStudyMode = progress_model.StudyMode.lesson;
          break;
      }

      final progress = progress_model.UserProgress(
        id: '${userId}_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        lessonId: lessonId,
        studyMode: progressStudyMode,
        date: DateTime.now(),
        questionsAnswered: state.cardsStudied,
        correctCount: state.correctAnswers,
        lessonCompleted: true,
        studyTimeSeconds: durationMinutes != null ? durationMinutes * 60 : 0,
        isSynced: false, // Mark as not synced for later upload
      );

      await hiveService.cacheProgress(progress);
      debugPrint('📦 Progress cached locally for later sync');
    } catch (e) {
      debugPrint('⚠️ Failed to cache progress locally: $e');
    }
  }

  /// Schedule a reminder for the next study session
  Future<void> _scheduleNextStudyReminder(String? lessonTitle) async {
    try {
      // Default to 24 hours from now
      final nextDay = DateTime.now().add(const Duration(hours: 24));
      final nextStudyTime =
          TimeOfDay(hour: nextDay.hour, minute: nextDay.minute);

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
  final Map<String, int> questionAnswers; // questionId -> selectedAnswerIndex
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
    Map<String, int>? questionAnswers,
    Map<String, DateTime>? completedLessons,
    this.lastStudied,
    this.currentLessonId,
    this.currentMode,
    this.currentIndex = 0,
    this.currentContent,
  })  : termStatus = termStatus ?? {},
        questionAnswers = questionAnswers ?? {},
        completedLessons = completedLessons ?? {};

  factory StudyState.initial() => StudyState(lastStudied: DateTime.now());

  StudyState copyWith({
    bool? isLoading,
    String? error,
    int? cardsStudied,
    int? correctAnswers,
    int? incorrectAnswers,
    Map<String, bool>? termStatus,
    Map<String, int>? questionAnswers,
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
      questionAnswers: questionAnswers ?? this.questionAnswers,
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
