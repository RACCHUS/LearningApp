import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment_engine/adaptive_practice_state.dart';
import '../models/assessment_engine/exam_diagnostic_report.dart';
import '../models/assessment_engine/mock_exam_blueprint.dart';
import '../models/assessment_engine/mock_exam_session.dart';
import '../models/assessment_item.dart';
import '../services/assessment/adaptive_practice_service.dart';
import '../services/assessment/exam_evaluation_service.dart';
import '../services/assessment/exam_practice_elapsed_clock.dart';

import '../services/assessment/mock_exam_generator_service.dart';

/// Provider for MockExamGeneratorService
final mockExamGeneratorServiceProvider = Provider<MockExamGeneratorService>((ref) {
  return MockExamGeneratorService();
});

/// Provider for ExamEvaluationService
final examEvaluationServiceProvider = Provider<ExamEvaluationService>((ref) {
  return ExamEvaluationService();
});

/// Provider for AdaptivePracticeService
final adaptivePracticeServiceProvider = Provider<AdaptivePracticeService>((ref) {
  return AdaptivePracticeService();
});

/// Fetches the authoritative blueprint for a given target version
final mockExamBlueprintProvider =
    FutureProvider.family<MockExamBlueprint, String>((ref, targetVersionId) async {
  final generator = ref.watch(mockExamGeneratorServiceProvider);
  return generator.loadBlueprint(targetVersionId);
});

/// State controller for a local, practice-only mock examination.
/// A Stopwatch measures actual active elapsed time; the periodic timer only
/// refreshes display state and cannot be treated as an official exam clock.
class ExamSessionNotifier extends StateNotifier<MockExamSession?> {
  final ExamEvaluationService _evaluationService;
  final ExamPracticeElapsedClock _clock;
  Timer? _timer;
  bool _submitted = false;

  ExamSessionNotifier(
    this._evaluationService, {
    ExamPracticeElapsedClock? clock,
  })  : _clock = clock ?? StopwatchExamPracticeElapsedClock(),
        super(null);

  void _cancelTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncElapsed() {
    final current = state;
    if (current == null || current.status != ExamSessionStatus.inProgress) {
      return;
    }

    // A throttled timer does not grant extra time. Action handlers call this
    // synchronously too, before accepting any post-deadline answer or flag.
    final elapsed = _clock.elapsed.inSeconds;
    if (elapsed >= current.timeLimit.inSeconds) {
      _clock.stop();
      _cancelTicker();
      state = current.copyWith(
        elapsedSeconds: elapsed,
        completedAt: DateTime.now(),
        status: ExamSessionStatus.expired,
      );
    } else if (elapsed != current.elapsedSeconds) {
      state = current.copyWith(elapsedSeconds: elapsed);
    }
  }

  void _startTicker() {
    _cancelTicker();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncElapsed();
    });
  }

  void startSession(MockExamSession session) {
    _cancelTicker();
    _clock.stop();
    _clock.reset();
    _submitted = false;
    state = session.copyWith(
      startedAt: DateTime.now(),
      elapsedSeconds: 0,
      status: ExamSessionStatus.inProgress,
    );
    _clock.start();
    _syncElapsed();
    if (state?.status == ExamSessionStatus.inProgress) {
      _startTicker();
    }
  }

  void recordResponse(String itemId, dynamic response) {
    _syncElapsed();
    if (state?.status != ExamSessionStatus.inProgress) return;

    final updated = Map<String, dynamic>.from(state!.userResponses);
    if (response == null) {
      updated.remove(itemId);
    } else {
      updated[itemId] = response;
    }

    state = state!.copyWith(userResponses: updated);
  }

  void toggleFlag(String itemId) {
    _syncElapsed();
    if (state?.status != ExamSessionStatus.inProgress) return;

    final updated = Set<String>.from(state!.flaggedItemIds);
    if (updated.contains(itemId)) {
      updated.remove(itemId);
    } else {
      updated.add(itemId);
    }

    state = state!.copyWith(flaggedItemIds: updated);
  }

  /// Local educational practice permits pause. It is not official timing.
  void pauseSession() {
    _syncElapsed();
    if (state?.status != ExamSessionStatus.inProgress) return;
    _clock.stop();
    _cancelTicker();
    state = state!.copyWith(status: ExamSessionStatus.paused);
  }

  void resumeSession() {
    if (state?.status != ExamSessionStatus.paused) return;
    // Crucially, do not call startSession: that resets the clock and start time.
    _clock.start();
    state = state!.copyWith(status: ExamSessionStatus.inProgress);
    _syncElapsed();
    if (state?.status == ExamSessionStatus.inProgress) {
      _startTicker();
    }
  }

  /// Only the first submission is evaluated. An expired practice session
  /// remains expired in its result; a late click cannot make it "completed".
  ExamDiagnosticReport? submitExam() {
    if (state == null || _submitted) return null;
    _syncElapsed();
    _cancelTicker();
    _clock.stop();

    final current = state!;
    final finishedSession = current.status == ExamSessionStatus.expired
        ? current
        : current.copyWith(
            completedAt: DateTime.now(),
            status: ExamSessionStatus.completed,
          );
    _submitted = true;
    state = finishedSession;
    return _evaluationService.evaluateExam(finishedSession);
  }

  @override
  void dispose() {
    _cancelTicker();
    _clock.stop();
    super.dispose();
  }
}

final examSessionProvider =
    StateNotifierProvider<ExamSessionNotifier, MockExamSession?>((ref) {
  final evaluationService = ref.watch(examEvaluationServiceProvider);
  return ExamSessionNotifier(evaluationService);
});

/// State controller for an active CAT-style adaptive practice session
class AdaptivePracticeNotifier extends StateNotifier<AdaptivePracticeState?> {
  final AdaptivePracticeService _adaptiveService;

  AdaptivePracticeNotifier(this._adaptiveService) : super(null);

  void startSession({
    required String userId,
    required String targetVersionId,
    int maxItems = 25,
    double targetStandardError = 0.35,
  }) {
    state = _adaptiveService.initSession(
      userId: userId,
      targetVersionId: targetVersionId,
      maxItems: maxItems,
      targetStandardError: targetStandardError,
    );
  }

  void submitResponse({
    required AssessmentItem item,
    required dynamic userResponse,
    required bool isCorrect,
    double? scoreEarned,
    String domainCode = '1.0',
  }) {
    if (state == null || state!.isSessionComplete) return;

    state = _adaptiveService.recordResponse(
      currentState: state!,
      item: item,
      userResponse: userResponse,
      isCorrect: isCorrect,
      scoreEarned: scoreEarned,
      domainCode: domainCode,
    );
  }

  void endSession() {
    if (state == null) return;
    state = state!.copyWith(isFinished: true);
  }
}

final adaptivePracticeProvider =
    StateNotifierProvider<AdaptivePracticeNotifier, AdaptivePracticeState?>((ref) {
  final service = ref.watch(adaptivePracticeServiceProvider);
  return AdaptivePracticeNotifier(service);
});
