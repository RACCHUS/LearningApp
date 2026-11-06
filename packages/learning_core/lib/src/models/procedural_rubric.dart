/// Role performing the procedural assessment sign-off (OPP-4).
enum PerformanceSignoffRole {
  selfAssessment,
  peerReview,
  evaluatorSignoff;

  static PerformanceSignoffRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'self_assessment':
      case 'selfassessment':
      case 'self':
        return PerformanceSignoffRole.selfAssessment;
      case 'peer_review':
      case 'peerreview':
      case 'peer':
        return PerformanceSignoffRole.peerReview;
      case 'evaluator_signoff':
      case 'evaluatorsignoff':
      case 'evaluator':
      case 'instructor':
        return PerformanceSignoffRole.evaluatorSignoff;
      default:
        return PerformanceSignoffRole.selfAssessment;
    }
  }

  String toDbString() {
    switch (this) {
      case PerformanceSignoffRole.selfAssessment:
        return 'self_assessment';
      case PerformanceSignoffRole.peerReview:
        return 'peer_review';
      case PerformanceSignoffRole.evaluatorSignoff:
        return 'evaluator_signoff';
    }
  }
}

/// Type of step within a procedural skills checklist or rubric.
enum RubricStepType {
  /// Standard weighted assessment step.
  standardStep,

  /// Critical safety or compliance step. Failure/omission causes immediate task failure
  /// (authoritative_critical_step_gate, e.g. CNA hand hygiene, CDL air brake check).
  criticalStep,

  /// Step enforcing maximum duration constraints.
  timingConstraint;

  static RubricStepType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'critical_step':
      case 'criticalstep':
      case 'critical':
        return RubricStepType.criticalStep;
      case 'timing_constraint':
      case 'timingconstraint':
      case 'timing':
        return RubricStepType.timingConstraint;
      case 'standard_step':
      case 'standardstep':
      default:
        return RubricStepType.standardStep;
    }
  }

  String toDbString() {
    switch (this) {
      case RubricStepType.standardStep:
        return 'standard_step';
      case RubricStepType.criticalStep:
        return 'critical_step';
      case RubricStepType.timingConstraint:
        return 'timing_constraint';
    }
  }
}

/// An individual criterion or operational step in a procedural rubric.
class RubricCriterionCore {
  final String id;
  final int stepOrder;
  final String title;
  final String description;
  final RubricStepType stepType;
  final double weight;
  final int maxScore;
  final String? criticalFailureNotice;
  final Map<int, String> descriptors;
  final String? authoritativeSourceRef;

  const RubricCriterionCore({
    required this.id,
    required this.stepOrder,
    required this.title,
    this.description = '',
    this.stepType = RubricStepType.standardStep,
    this.weight = 1.0,
    this.maxScore = 2,
    this.criticalFailureNotice,
    this.descriptors = const {},
    this.authoritativeSourceRef,
  });

  bool get isCritical => stepType == RubricStepType.criticalStep;

  factory RubricCriterionCore.fromJson(Map<String, dynamic> json) {
    final rawDescriptors = (json['descriptors'] as Map?) ?? {};
    final parsedDescriptors = <int, String>{};
    for (final entry in rawDescriptors.entries) {
      final key = int.tryParse(entry.key.toString());
      if (key != null) {
        parsedDescriptors[key] = entry.value.toString();
      }
    }

    return RubricCriterionCore(
      id: json['id'] as String? ?? '',
      stepOrder: (json['step_order'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      stepType: RubricStepType.fromString(
          json['step_type'] as String? ?? 'standard_step'),
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 2,
      criticalFailureNotice: json['critical_failure_notice'] as String?,
      descriptors: parsedDescriptors,
      authoritativeSourceRef: json['authoritative_source_ref'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'step_order': stepOrder,
        'title': title,
        'description': description,
        'step_type': stepType.toDbString(),
        'weight': weight,
        'max_score': maxScore,
        if (criticalFailureNotice != null)
          'critical_failure_notice': criticalFailureNotice,
        'descriptors': descriptors.map((k, v) => MapEntry(k.toString(), v)),
        if (authoritativeSourceRef != null)
          'authoritative_source_ref': authoritativeSourceRef,
      };
}

/// A complete procedural rubric for clinical, trade, or hands-on licensure exams.
class ProceduralRubricCore {
  final String id;
  final String title;
  final String description;
  final String targetDomain;
  final double passingScorePercentage;
  final List<RubricCriterionCore> criteria;
  final String? expertDemoVideoUrl;
  final int? timeLimitSeconds;

  const ProceduralRubricCore({
    required this.id,
    required this.title,
    this.description = '',
    required this.targetDomain,
    this.passingScorePercentage = 0.80,
    required this.criteria,
    this.expertDemoVideoUrl,
    this.timeLimitSeconds,
  });

  /// Returns list of all critical fail criteria that must be passed.
  List<RubricCriterionCore> get criticalCriteria =>
      criteria.where((c) => c.isCritical).toList();

  /// Total maximum possible points across all criteria.
  double get maxPossibleScore =>
      criteria.fold<double>(0.0, (sum, c) => sum + (c.maxScore * c.weight));

  factory ProceduralRubricCore.fromJson(Map<String, dynamic> json) {
    final rawCriteria = (json['criteria'] as List?) ?? [];
    final criteriaList = rawCriteria
        .map((c) => RubricCriterionCore.fromJson((c as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return ProceduralRubricCore(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetDomain: json['target_domain'] as String? ?? '',
      passingScorePercentage:
          (json['passing_score_percentage'] as num?)?.toDouble() ?? 0.80,
      criteria: criteriaList,
      expertDemoVideoUrl: json['expert_demo_video_url'] as String?,
      timeLimitSeconds: (json['time_limit_seconds'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'target_domain': targetDomain,
        'passing_score_percentage': passingScorePercentage,
        'criteria': criteria.map((c) => c.toJson()).toList(),
        if (expertDemoVideoUrl != null)
          'expert_demo_video_url': expertDemoVideoUrl,
        if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
      };
}

/// Evaluation score recorded for a single step in a rubric attempt.
class RubricStepEvaluation {
  final String criterionId;
  final int score;
  final bool isCompleted;
  final String? notes;
  final bool criticalFailed;

  const RubricStepEvaluation({
    required this.criterionId,
    required this.score,
    this.isCompleted = true,
    this.notes,
    this.criticalFailed = false,
  });

  factory RubricStepEvaluation.fromJson(Map<String, dynamic> json) {
    return RubricStepEvaluation(
      criterionId: json['criterion_id'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      isCompleted: json['is_completed'] as bool? ?? true,
      notes: json['notes'] as String?,
      criticalFailed: json['critical_failed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'criterion_id': criterionId,
        'score': score,
        'is_completed': isCompleted,
        if (notes != null) 'notes': notes,
        'critical_failed': criticalFailed,
      };
}

/// Recorded attempt and observer sign-off for a procedural assessment.
class PerformanceAssessmentAttempt {
  final String rubricId;
  final String learnerId;
  final String? evaluatorId;
  final PerformanceSignoffRole role;
  final List<RubricStepEvaluation> stepEvaluations;
  final DateTime startedAt;
  final DateTime completedAt;
  final int elapsedSeconds;
  final String? evaluatorNotes;
  final String? evaluatorSignature;

  const PerformanceAssessmentAttempt({
    required this.rubricId,
    required this.learnerId,
    this.evaluatorId,
    this.role = PerformanceSignoffRole.selfAssessment,
    required this.stepEvaluations,
    required this.startedAt,
    required this.completedAt,
    required this.elapsedSeconds,
    this.evaluatorNotes,
    this.evaluatorSignature,
  });

  factory PerformanceAssessmentAttempt.fromJson(Map<String, dynamic> json) {
    final rawEvaluations = (json['step_evaluations'] as List?) ?? [];
    return PerformanceAssessmentAttempt(
      rubricId: json['rubric_id'] as String? ?? '',
      learnerId: json['learner_id'] as String? ?? '',
      evaluatorId: json['evaluator_id'] as String?,
      role: PerformanceSignoffRole.fromString(
          json['role'] as String? ?? 'self_assessment'),
      stepEvaluations: rawEvaluations
          .map((e) =>
              RubricStepEvaluation.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      startedAt: DateTime.parse(
          json['started_at'] as String? ?? DateTime.now().toIso8601String()),
      completedAt: DateTime.parse(
          json['completed_at'] as String? ?? DateTime.now().toIso8601String()),
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      evaluatorNotes: json['evaluator_notes'] as String?,
      evaluatorSignature: json['evaluator_signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'rubric_id': rubricId,
        'learner_id': learnerId,
        if (evaluatorId != null) 'evaluator_id': evaluatorId,
        'role': role.toDbString(),
        'step_evaluations': stepEvaluations.map((e) => e.toJson()).toList(),
        'started_at': startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'elapsed_seconds': elapsedSeconds,
        if (evaluatorNotes != null) 'evaluator_notes': evaluatorNotes,
        if (evaluatorSignature != null) 'evaluator_signature': evaluatorSignature,
      };
}
