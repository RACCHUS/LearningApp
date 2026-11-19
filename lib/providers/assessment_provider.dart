import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment.dart';
import '../services/skill_assessment_service.dart';
import 'skill_stats_provider.dart';

// ============================================================================
// ASSESSMENT SESSION
// ============================================================================

/// Active assessment session state
class AssessmentSessionState {
  final String? attemptId;
  final SkillAssessment? assessment;
  final List<AssessmentQuestion> questions;
  final int currentQuestionIndex;
  final Map<String, int> answers; // questionId -> answerIndex
  final DateTime? startedAt;
  final bool isSubmitting;
  final AssessmentResult? result;
  final String? error;

  const AssessmentSessionState({
    this.attemptId,
    this.assessment,
    this.questions = const [],
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.startedAt,
    this.isSubmitting = false,
    this.result,
    this.error,
  });

  bool get isActive => attemptId != null && result == null;
  bool get isCompleted => result != null;

  AssessmentQuestion? get currentQuestion =>
      currentQuestionIndex < questions.length
          ? questions[currentQuestionIndex]
          : null;

  int? get currentAnswer =>
      currentQuestion != null ? answers[currentQuestion!.id] : null;

  bool get hasAnsweredCurrent => currentAnswer != null;

  int get answeredCount => answers.length;
  int get totalQuestions => questions.length;
  double get progress =>
      totalQuestions > 0 ? answeredCount / totalQuestions : 0;

  bool get canGoBack => currentQuestionIndex > 0;
  bool get canGoForward => currentQuestionIndex < questions.length - 1;
  bool get isLastQuestion => currentQuestionIndex == questions.length - 1;
  bool get allAnswered => answeredCount == totalQuestions;

  /// Time elapsed since start
  Duration get timeElapsed =>
      startedAt != null ? DateTime.now().difference(startedAt!) : Duration.zero;

  /// Time remaining (null if no limit or overtime)
  Duration? get timeRemaining {
    if (assessment == null || startedAt == null) return null;
    final limit = assessment!.timeLimit;
    final elapsed = timeElapsed;
    if (elapsed >= limit) return Duration.zero;
    return limit - elapsed;
  }

  bool get isOvertime {
    if (assessment == null || startedAt == null) return false;
    return timeElapsed > assessment!.timeLimit;
  }

  AssessmentSessionState copyWith({
    String? attemptId,
    SkillAssessment? assessment,
    List<AssessmentQuestion>? questions,
    int? currentQuestionIndex,
    Map<String, int>? answers,
    DateTime? startedAt,
    bool? isSubmitting,
    AssessmentResult? result,
    String? error,
  }) {
    return AssessmentSessionState(
      attemptId: attemptId ?? this.attemptId,
      assessment: assessment ?? this.assessment,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      startedAt: startedAt ?? this.startedAt,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      error: error,
    );
  }
}

/// Assessment session notifier
final assessmentSessionProvider =
    StateNotifierProvider<AssessmentSessionNotifier, AssessmentSessionState>(
        (ref) {
  final service = ref.read(skillAssessmentServiceProvider);
  return AssessmentSessionNotifier(service, ref);
});

class AssessmentSessionNotifier extends StateNotifier<AssessmentSessionState> {
  final SkillAssessmentService _service;
  final Ref _ref;

  AssessmentSessionNotifier(this._service, this._ref)
      : super(const AssessmentSessionState());

  /// Start a new assessment
  Future<void> startAssessment(String assessmentId) async {
    try {
      // Get assessment with questions
      final assessment =
          await _service.getAssessmentWithQuestions(assessmentId);
      final questions = assessment.questions ?? [];

      // Shuffle questions (optional)
      questions.shuffle();

      // Start attempt
      final attempt = await _service.startAssessment(assessmentId);

      state = AssessmentSessionState(
        attemptId: attempt.id,
        assessment: assessment,
        questions: questions,
        currentQuestionIndex: 0,
        answers: {},
        startedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Answer current question
  void answerQuestion(int answerIndex) {
    if (state.currentQuestion == null) return;

    final newAnswers = Map<String, int>.from(state.answers);
    newAnswers[state.currentQuestion!.id] = answerIndex;

    state = state.copyWith(answers: newAnswers);
  }

  /// Go to next question
  void nextQuestion() {
    if (state.canGoForward) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  /// Go to previous question
  void previousQuestion() {
    if (state.canGoBack) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  /// Jump to specific question
  void goToQuestion(int index) {
    if (index >= 0 && index < state.questions.length) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  /// Submit all answers and complete assessment
  Future<AssessmentResult?> submitAssessment() async {
    if (state.attemptId == null) return null;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      // Submit all answers first
      for (final entry in state.answers.entries) {
        await _service.submitAnswer(
          state.attemptId!,
          entry.key,
          entry.value,
        );
      }

      // Complete the assessment
      final result = await _service.completeAssessment(
        state.attemptId!,
        wasOvertime: state.isOvertime,
      );

      state = state.copyWith(
        isSubmitting: false,
        result: result,
      );

      // Refresh skill stats
      _ref.read(userSkillStatsProvider.notifier).refresh();

      return result;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Reset session (for starting a new assessment)
  void reset() {
    state = const AssessmentSessionState();
  }

  /// Abandon current assessment
  Future<void> abandon() async {
    // Could mark the attempt as abandoned in the future
    reset();
  }
}
