/// Comprehensive QA readiness audit report for a target version.
class TargetVersionAuditReport {
  final String targetVersionId;
  final String versionCode;
  final String status;
  final String targetTitle;
  final int domainCount;
  final int objectiveCount;
  final int leafObjectiveCount;
  final double domainWeightSum;
  final bool isDomainWeightBalanced;
  final int lessonCount;
  final int lessonBlockCount;
  final int stimulusCount;
  final int assessmentItemCount;
  final int emptyObjectivesCount;
  final int conceptCoverageCount;
  final int unassessedConceptsCount;
  final int provenanceCitationsCount;
  final int missingProvenanceCount;
  final int crossVersionMappingsCount;
  final bool canStageReview;
  final bool canPublish;
  final List<String> blockingIssues;
  final List<String> warnings;

  const TargetVersionAuditReport({
    required this.targetVersionId,
    required this.versionCode,
    required this.status,
    required this.targetTitle,
    required this.domainCount,
    required this.objectiveCount,
    required this.leafObjectiveCount,
    required this.domainWeightSum,
    required this.isDomainWeightBalanced,
    required this.lessonCount,
    required this.lessonBlockCount,
    required this.stimulusCount,
    required this.assessmentItemCount,
    required this.emptyObjectivesCount,
    required this.conceptCoverageCount,
    required this.unassessedConceptsCount,
    required this.provenanceCitationsCount,
    required this.missingProvenanceCount,
    required this.crossVersionMappingsCount,
    required this.canStageReview,
    required this.canPublish,
    this.blockingIssues = const [],
    this.warnings = const [],
  });

  bool get isClean => blockingIssues.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  int get totalContentItems => lessonCount + stimulusCount + assessmentItemCount;

  double get assessmentToObjectiveRatio =>
      leafObjectiveCount > 0 ? assessmentItemCount / leafObjectiveCount : 0.0;

  double get conceptAssessmentCoveragePct => conceptCoverageCount > 0
      ? ((conceptCoverageCount - unassessedConceptsCount) / conceptCoverageCount) * 100
      : 100.0;

  factory TargetVersionAuditReport.fromJson(Map<String, dynamic> json) {
    return TargetVersionAuditReport(
      targetVersionId: json['target_version_id'] as String,
      versionCode: json['version_code'] as String? ?? '',
      status: json['status'] as String? ?? 'draft',
      targetTitle: json['target_title'] as String? ?? '',
      domainCount: (json['domain_count'] as num?)?.toInt() ?? 0,
      objectiveCount: (json['objective_count'] as num?)?.toInt() ?? 0,
      leafObjectiveCount: (json['leaf_objective_count'] as num?)?.toInt() ?? 0,
      domainWeightSum: (json['domain_weight_sum'] as num?)?.toDouble() ?? 0.0,
      isDomainWeightBalanced: json['is_domain_weight_balanced'] as bool? ?? false,
      lessonCount: (json['lesson_count'] as num?)?.toInt() ?? 0,
      lessonBlockCount: (json['lesson_block_count'] as num?)?.toInt() ?? 0,
      stimulusCount: (json['stimulus_count'] as num?)?.toInt() ?? 0,
      assessmentItemCount: (json['assessment_item_count'] as num?)?.toInt() ?? 0,
      emptyObjectivesCount:
          (json['empty_objectives_count'] as num?)?.toInt() ?? 0,
      conceptCoverageCount:
          (json['concept_coverage_count'] as num?)?.toInt() ?? 0,
      unassessedConceptsCount:
          (json['unassessed_concepts_count'] as num?)?.toInt() ?? 0,
      provenanceCitationsCount:
          (json['provenance_citations_count'] as num?)?.toInt() ?? 0,
      missingProvenanceCount:
          (json['missing_provenance_count'] as num?)?.toInt() ?? 0,
      crossVersionMappingsCount:
          (json['cross_version_mappings_count'] as num?)?.toInt() ?? 0,
      canStageReview: json['can_stage_review'] as bool? ?? false,
      canPublish: json['can_publish'] as bool? ?? false,
      blockingIssues: (json['blocking_issues'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'target_version_id': targetVersionId,
        'version_code': versionCode,
        'status': status,
        'target_title': targetTitle,
        'domain_count': domainCount,
        'objective_count': objectiveCount,
        'leaf_objective_count': leafObjectiveCount,
        'domain_weight_sum': domainWeightSum,
        'is_domain_weight_balanced': isDomainWeightBalanced,
        'lesson_count': lessonCount,
        'lesson_block_count': lessonBlockCount,
        'stimulus_count': stimulusCount,
        'assessment_item_count': assessmentItemCount,
        'empty_objectives_count': emptyObjectivesCount,
        'concept_coverage_count': conceptCoverageCount,
        'unassessed_concepts_count': unassessedConceptsCount,
        'provenance_citations_count': provenanceCitationsCount,
        'missing_provenance_count': missingProvenanceCount,
        'cross_version_mappings_count': crossVersionMappingsCount,
        'can_stage_review': canStageReview,
        'can_publish': canPublish,
        'blocking_issues': blockingIssues,
        'warnings': warnings,
      };
}
