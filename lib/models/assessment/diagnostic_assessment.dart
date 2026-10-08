import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/user_concept_state.dart';

enum DiagnosticEvidenceBand {
  strongEvidence,
  developingEvidence,
  needsReinforcement;

  String get displayName => switch (this) {
        DiagnosticEvidenceBand.strongEvidence => 'Strong Diagnostic Evidence',
        DiagnosticEvidenceBand.developingEvidence =>
          'Developing Diagnostic Evidence',
        DiagnosticEvidenceBand.needsReinforcement =>
          'Needs Reinforcement',
      };
}

class DiagnosticConceptRef {
  final String conceptId;
  final String conceptName;
  final double weight;
  final String role;

  const DiagnosticConceptRef({
    required this.conceptId,
    required this.conceptName,
    this.weight = 1.0,
    this.role = 'primary',
  });
}

/// A canonical assessment item plus the target-version concepts it measures.
class DiagnosticAssessmentItem {
  final AssessmentItem item;
  final List<DiagnosticConceptRef> concepts;

  const DiagnosticAssessmentItem({
    required this.item,
    required this.concepts,
  });

  DiagnosticConceptRef get primaryConcept {
    for (final concept in concepts) {
      if (concept.role == 'primary') return concept;
    }
    return concepts.first;
  }
}

class DiagnosticAvailability {
  final String targetVersionId;
  final bool isPublishedVersion;
  final int availableItemCount;
  final int representedConceptCount;
  final int minimumItemCount;
  final int minimumConceptCount;

  const DiagnosticAvailability({
    required this.targetVersionId,
    required this.isPublishedVersion,
    required this.availableItemCount,
    required this.representedConceptCount,
    required this.minimumItemCount,
    required this.minimumConceptCount,
  });

  bool get isAvailable =>
      isPublishedVersion &&
      availableItemCount >= minimumItemCount &&
      representedConceptCount >= minimumConceptCount;
}

class DiagnosticAnswerSubmission {
  final String itemId;
  final dynamic response;
  final bool isCorrect;
  final bool isPartial;
  final double scoreEarned;

  const DiagnosticAnswerSubmission({
    required this.itemId,
    required this.response,
    required this.isCorrect,
    required this.isPartial,
    required this.scoreEarned,
  });
}

class DiagnosticConceptEvaluation {
  final String conceptId;
  final String conceptName;
  final int testedItemsCount;
  final double weightedEvidenceEarned;
  final double weightedEvidencePossible;
  final double evidenceRatio;
  final DiagnosticEvidenceBand evidenceBand;
  final ConceptConfidence confidence;
  final bool isReinforcementPriority;

  const DiagnosticConceptEvaluation({
    required this.conceptId,
    required this.conceptName,
    required this.testedItemsCount,
    required this.weightedEvidenceEarned,
    required this.weightedEvidencePossible,
    required this.evidenceRatio,
    required this.evidenceBand,
    required this.confidence,
    required this.isReinforcementPriority,
  });
}

class DiagnosticAssessmentReport {
  final String id;
  final String targetId;
  final String targetTitle;
  final String targetVersionId;
  final DateTime completedAt;
  final int totalQuestions;
  final int correctQuestions;
  final int partialQuestions;
  final double overallEvidenceScore;
  final DiagnosticEvidenceBand evidenceBand;
  final List<DiagnosticConceptEvaluation> conceptEvaluations;
  final List<DiagnosticConceptEvaluation> reinforcementPriorities;
  final List<DiagnosticConceptEvaluation> strongEvidenceConcepts;
  final bool evidencePersisted;
  final bool remedialSetCreated;
  final String? remedialSetId;
  final String? remedialSetTitle;
  final int remedialItemCount;
  final String pedagogicalDisclaimer;

  const DiagnosticAssessmentReport({
    required this.id,
    required this.targetId,
    required this.targetTitle,
    required this.targetVersionId,
    required this.completedAt,
    required this.totalQuestions,
    required this.correctQuestions,
    required this.partialQuestions,
    required this.overallEvidenceScore,
    required this.evidenceBand,
    required this.conceptEvaluations,
    required this.reinforcementPriorities,
    required this.strongEvidenceConcepts,
    required this.evidencePersisted,
    this.remedialSetCreated = false,
    this.remedialSetId,
    this.remedialSetTitle,
    this.remedialItemCount = 0,
    this.pedagogicalDisclaimer =
        'Diagnostic snapshot based only on published practice items available in this target version. It is not a certification result or a guarantee of external exam performance. Long-term Target Readiness is calculated separately from accumulated concept evidence.',
  });

  DiagnosticAssessmentReport copyWith({
    bool? remedialSetCreated,
    String? remedialSetId,
    String? remedialSetTitle,
    int? remedialItemCount,
  }) {
    return DiagnosticAssessmentReport(
      id: id,
      targetId: targetId,
      targetTitle: targetTitle,
      targetVersionId: targetVersionId,
      completedAt: completedAt,
      totalQuestions: totalQuestions,
      correctQuestions: correctQuestions,
      partialQuestions: partialQuestions,
      overallEvidenceScore: overallEvidenceScore,
      evidenceBand: evidenceBand,
      conceptEvaluations: conceptEvaluations,
      reinforcementPriorities: reinforcementPriorities,
      strongEvidenceConcepts: strongEvidenceConcepts,
      evidencePersisted: evidencePersisted,
      remedialSetCreated: remedialSetCreated ?? this.remedialSetCreated,
      remedialSetId: remedialSetId ?? this.remedialSetId,
      remedialSetTitle: remedialSetTitle ?? this.remedialSetTitle,
      remedialItemCount: remedialItemCount ?? this.remedialItemCount,
      pedagogicalDisclaimer: pedagogicalDisclaimer,
    );
  }
}
