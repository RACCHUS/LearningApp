/// Models representing the learner-facing Excel pilot practice attempt,
/// single-use lease state, and deterministic criteria assessment results.
///
/// Under the Excel pilot safety architecture, learner attempts are strictly
/// single-use and unverified. No certified skill evidence or permanent badge
/// can be awarded by this practice flow.
library;

enum SoftwareLearningStatus {
  idle,
  selecting,
  uploading,
  evaluating,
  completed,
  rejected,
  expired,
}

class SoftwareLearningCriterion {
  final String id;
  final String title;
  final String description;
  final bool passed;
  final String? feedback;

  const SoftwareLearningCriterion({
    required this.id,
    required this.title,
    required this.description,
    required this.passed,
    this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'passed': passed,
        if (feedback != null) 'feedback': feedback,
      };

  factory SoftwareLearningCriterion.fromJson(Map<String, dynamic> json) =>
      SoftwareLearningCriterion(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        passed: json['passed'] as bool? ?? false,
        feedback: json['feedback'] as String?,
      );
}

class SoftwareLearningResult {
  final String attemptId;
  final String exerciseId;
  final bool overallPassed;
  final String evidenceTrust;
  final bool canAwardSkill;
  final String feedback;
  final List<SoftwareLearningCriterion> criteria;

  const SoftwareLearningResult({
    required this.attemptId,
    required this.exerciseId,
    required this.overallPassed,
    this.evidenceTrust = 'unverified_checker_only',
    this.canAwardSkill = false,
    required this.feedback,
    required this.criteria,
  });

  Map<String, dynamic> toJson() => {
        'attempt_id': attemptId,
        'exercise_id': exerciseId,
        'overall_passed': overallPassed,
        'evidence_trust': evidenceTrust,
        'can_award_skill': canAwardSkill,
        'feedback': feedback,
        'criteria': criteria.map((c) => c.toJson()).toList(),
      };

  factory SoftwareLearningResult.fromJson(Map<String, dynamic> json) =>
      SoftwareLearningResult(
        attemptId: json['attempt_id'] as String,
        exerciseId: json['exercise_id'] as String,
        overallPassed: json['overall_passed'] as bool? ?? false,
        evidenceTrust:
            json['evidence_trust'] as String? ?? 'unverified_checker_only',
        canAwardSkill: json['can_award_skill'] as bool? ?? false,
        feedback: json['feedback'] as String? ?? '',
        criteria: (json['criteria'] as List<dynamic>?)
                ?.map((c) =>
                    SoftwareLearningCriterion.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

