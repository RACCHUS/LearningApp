import '../models/procedural_rubric.dart';

/// Comprehensive outcome of evaluating a procedural assessment attempt (OPP-4).
class PerformanceEvaluationResult {
  final double totalEarnedScore;
  final double maxPossibleScore;
  final double scorePercentage;
  final bool passed;
  final bool criticalFailEncountered;
  final List<String> criticalFailureReasons;
  final List<RubricCriterionCore> missedCriteria;
  final int elapsedSeconds;
  final bool exceededTimeLimit;

  const PerformanceEvaluationResult({
    required this.totalEarnedScore,
    required this.maxPossibleScore,
    required this.scorePercentage,
    required this.passed,
    required this.criticalFailEncountered,
    required this.criticalFailureReasons,
    required this.missedCriteria,
    required this.elapsedSeconds,
    required this.exceededTimeLimit,
  });

  Map<String, dynamic> toJson() => {
        'total_earned_score': totalEarnedScore,
        'max_possible_score': maxPossibleScore,
        'score_percentage': scorePercentage,
        'passed': passed,
        'critical_fail_encountered': criticalFailEncountered,
        'critical_failure_reasons': criticalFailureReasons,
        'missed_criteria_ids': missedCriteria.map((c) => c.id).toList(),
        'elapsed_seconds': elapsedSeconds,
        'exceeded_time_limit': exceededTimeLimit,
      };
}

/// Evaluates procedural checklists, critical-fail gates, and authoritatively grounded rubrics.
class ProceduralEvaluatorCore {
  const ProceduralEvaluatorCore._();

  /// Validates that a rubric complies with learning science guardrails.
  ///
  /// In accordance with Task-Specific Delivery § 7.1, any critical step
  /// (`authoritative_critical_step_gate`) MUST cite an authoritative exam rubric
  /// or regulatory standard in [authoritativeSourceRef].
  static List<String> validateRubric(ProceduralRubricCore rubric) {
    final errors = <String>[];

    if (rubric.title.trim().isEmpty) {
      errors.add('Rubric title cannot be empty.');
    }
    if (rubric.criteria.isEmpty) {
      errors.add('Rubric must define at least one criterion.');
    }

    for (final criterion in rubric.criteria) {
      if (criterion.isCritical) {
        if (criterion.authoritativeSourceRef == null ||
            criterion.authoritativeSourceRef!.trim().isEmpty) {
          errors.add(
            'Criterion "${criterion.title}" (${criterion.id}) is designated as a critical step '
            'but lacks an authoritativeSourceRef citation required by delivery policy § 7.1.',
          );
        }
      }
    }

    return errors;
  }

  /// Evaluates an attempt against [rubric].
  ///
  /// CRITICAL STEP RULE: If any critical step is missed or failed, the assessment
  /// automatically fails, even if total points exceed [passingScorePercentage].
  static PerformanceEvaluationResult evaluate({
    required ProceduralRubricCore rubric,
    required List<RubricStepEvaluation> stepEvaluations,
    int elapsedSeconds = 0,
  }) {
    final evalMap = <String, RubricStepEvaluation>{
      for (final eval in stepEvaluations) eval.criterionId: eval,
    };

    double totalEarned = 0.0;
    double maxPossible = 0.0;
    bool criticalFailed = false;
    final criticalReasons = <String>[];
    final missed = <RubricCriterionCore>[];

    for (final criterion in rubric.criteria) {
      final criterionMax = criterion.maxScore * criterion.weight;
      maxPossible += criterionMax;

      final eval = evalMap[criterion.id];
      if (eval == null) {
        // Step was completely omitted
        if (criterion.isCritical) {
          criticalFailed = true;
          criticalReasons.add(
            'Critical step omitted: "${criterion.title}"'
            '${criterion.criticalFailureNotice != null ? ' - ${criterion.criticalFailureNotice}' : ''}'
            ' [Source: ${criterion.authoritativeSourceRef ?? "Unknown"}]',
          );
        }
        missed.add(criterion);
        continue;
      }

      final earned = (eval.score * criterion.weight).clamp(0.0, criterionMax);
      totalEarned += earned;

      // Check for critical failure trigger
      if (criterion.isCritical) {
        if (eval.criticalFailed || eval.score == 0 || !eval.isCompleted) {
          criticalFailed = true;
          criticalReasons.add(
            'Critical step failed: "${criterion.title}"'
            '${criterion.criticalFailureNotice != null ? ' - ${criterion.criticalFailureNotice}' : ''}'
            ' [Source: ${criterion.authoritativeSourceRef ?? "Unknown"}]',
          );
        }
      }

      if (eval.score < criterion.maxScore) {
        missed.add(criterion);
      }
    }

    final percentage = maxPossible > 0 ? (totalEarned / maxPossible) : 0.0;
    final exceededTime = rubric.timeLimitSeconds != null &&
        elapsedSeconds > rubric.timeLimitSeconds!;

    final passed = !criticalFailed &&
        !exceededTime &&
        percentage >= rubric.passingScorePercentage;

    return PerformanceEvaluationResult(
      totalEarnedScore: double.parse(totalEarned.toStringAsFixed(2)),
      maxPossibleScore: double.parse(maxPossible.toStringAsFixed(2)),
      scorePercentage: double.parse(percentage.toStringAsFixed(4)),
      passed: passed,
      criticalFailEncountered: criticalFailed,
      criticalFailureReasons: criticalReasons,
      missedCriteria: missed,
      elapsedSeconds: elapsedSeconds,
      exceededTimeLimit: exceededTime,
    );
  }
}
