import 'package:learning_core/learning_core.dart';
import '../../models/learning_event.dart';

/// Manages performance assessment execution, rubric evaluations, and sign-offs (OPP-4, OPP-3).
class PerformanceAssessmentService {
  final List<PerformanceAssessmentAttempt> _recordedAttempts = [];
  final List<LearningEvent> _emittedEvents = [];

  List<PerformanceAssessmentAttempt> get recordedAttempts =>
      List.unmodifiable(_recordedAttempts);
  List<LearningEvent> get emittedEvents => List.unmodifiable(_emittedEvents);

  /// Evaluates and records a completed performance assessment attempt.
  PerformanceEvaluationResult recordAttempt({
    required ProceduralRubricCore rubric,
    required String learnerId,
    required PerformanceSignoffRole role,
    required List<RubricStepEvaluation> stepEvaluations,
    required int elapsedSeconds,
    String? evaluatorId,
    String? evaluatorNotes,
    String? evaluatorSignature,
    String? sessionId,
  }) {
    final result = ProceduralEvaluatorCore.evaluate(
      rubric: rubric,
      stepEvaluations: stepEvaluations,
      elapsedSeconds: elapsedSeconds,
    );

    final now = DateTime.now().toUtc();
    final attempt = PerformanceAssessmentAttempt(
      rubricId: rubric.id,
      learnerId: learnerId,
      evaluatorId: evaluatorId,
      role: role,
      stepEvaluations: stepEvaluations,
      startedAt: now.subtract(Duration(seconds: elapsedSeconds)),
      completedAt: now,
      elapsedSeconds: elapsedSeconds,
      evaluatorNotes: evaluatorNotes,
      evaluatorSignature: evaluatorSignature,
    );

    _recordedAttempts.add(attempt);

    final event = LearningEvent(
      userId: learnerId,
      sessionId: sessionId,
      eventType: 'performance_assessment_completed',
      itemType: 'procedural_rubric',
      itemId: rubric.id,
      score: result.scorePercentage,
      latencyMs: elapsedSeconds * 1000,
      metadata: {
        'passed': result.passed,
        'critical_fail': result.criticalFailEncountered,
        'critical_reasons': result.criticalFailureReasons,
        'role': role.toDbString(),
        'evaluator_id': evaluatorId,
        'target_domain': rubric.targetDomain,
        'total_earned': result.totalEarnedScore,
        'max_possible': result.maxPossibleScore,
      },
    );

    _emittedEvents.add(event);
    return result;
  }
}
