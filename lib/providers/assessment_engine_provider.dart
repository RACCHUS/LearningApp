import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment_engine/adaptive_practice_state.dart';
import '../models/assessment_engine/exam_diagnostic_report.dart';
import '../models/assessment_engine/mock_exam_blueprint.dart';
import '../models/assessment_engine/mock_exam_session.dart';
import '../models/assessment_item.dart';
import '../services/assessment/adaptive_practice_service.dart';
import '../services/assessment/exam_evaluation_service.dart';
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

/// State controller for an active timed mock exam session
class ExamSessionNotifier extends StateNotifier<MockExamSession?> {
  final ExamEvaluationService _evaluationService;
  Timer? _timer;

  ExamSessionNotifier(this._evaluationService) : super(null);

  void startSession(MockExamSession session) {
    _timer?.cancel();
    state = session.copyWith(
      startedAt: DateTime.now(),
      status: ExamSessionStatus.inProgress,
    );

    // Start 1-second ticker for timed simulation
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state == null || !state!.status.isActive) {
        timer.cancel();
        return;
      }

      final newElapsed = state!.elapsedSeconds + 1;
      if (newElapsed >= state!.timeLimit.inSeconds) {
        timer.cancel();
        state = state!.copyWith(
          elapsedSeconds: newElapsed,
          completedAt: DateTime.now(),
          status: ExamSessionStatus.expired,
        );
      } else {
        state = state!.copyWith(elapsedSeconds: newElapsed);
      }
    });
  }

  void recordResponse(String itemId, dynamic response) {
    if (state == null || state!.isCompleted) return;

    final updated = Map<String, dynamic>.from(state!.userResponses);
    if (response == null) {
      updated.remove(itemId);
    } else {
      updated[itemId] = response;
    }

    state = state!.copyWith(userResponses: updated);
  }

  void toggleFlag(String itemId) {
    if (state == null || state!.isCompleted) return;

    final updated = Set<String>.from(state!.flaggedItemIds);
    if (updated.contains(itemId)) {
      updated.remove(itemId);
    } else {
      updated.add(itemId);
    }

    state = state!.copyWith(flaggedItemIds: updated);
  }

  void pauseSession() {
    if (state == null || state!.status != ExamSessionStatus.inProgress) return;
    _timer?.cancel();
    state = state!.copyWith(status: ExamSessionStatus.paused);
  }

  void resumeSession() {
    if (state == null || state!.status != ExamSessionStatus.paused) return;
    startSession(state!);
  }

  ExamDiagnosticReport? submitExam() {
    if (state == null) return null;
    _timer?.cancel();

    final finishedSession = state!.copyWith(
      completedAt: DateTime.now(),
      status: ExamSessionStatus.completed,
    );
    state = finishedSession;

    return _evaluationService.evaluateExam(finishedSession);
  }

  @override
  void dispose() {
    _timer?.cancel();
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
