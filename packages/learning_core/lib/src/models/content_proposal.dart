/// Type of autonomous content proposal generated from learning evidence (ECO-10).
enum ContentProposalType {
  /// Generated when learners repeatedly trigger a specific distractor misconception.
  misconceptionRemediation,

  /// Generated when a concept is identified in curriculum but lacks sufficient retrieval items.
  contentGap,

  /// Generated when regulatory citations or references become outdated.
  citationFreshness;

  static ContentProposalType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'misconception_remediation':
      case 'misconceptionremediation':
      case 'misconception':
        return ContentProposalType.misconceptionRemediation;
      case 'content_gap':
      case 'contentgap':
      case 'gap':
        return ContentProposalType.contentGap;
      case 'citation_freshness':
      case 'citationfreshness':
      case 'freshness':
        return ContentProposalType.citationFreshness;
      default:
        return ContentProposalType.misconceptionRemediation;
    }
  }

  String toDbString() {
    switch (this) {
      case ContentProposalType.misconceptionRemediation:
        return 'misconception_remediation';
      case ContentProposalType.contentGap:
        return 'content_gap';
      case ContentProposalType.citationFreshness:
        return 'citation_freshness';
    }
  }
}

/// Status of an autonomous content improvement proposal in the review pipeline.
enum ProposalReviewStatus {
  pendingReview,
  approved,
  rejected;

  static ProposalReviewStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return ProposalReviewStatus.approved;
      case 'rejected':
        return ProposalReviewStatus.rejected;
      case 'pending_review':
      case 'pending':
      default:
        return ProposalReviewStatus.pendingReview;
    }
  }

  String toDbString() {
    switch (this) {
      case ProposalReviewStatus.pendingReview:
        return 'pending_review';
      case ProposalReviewStatus.approved:
        return 'approved';
      case ProposalReviewStatus.rejected:
        return 'rejected';
    }
  }
}

/// An autonomous content improvement proposal for educator and community review (ECO-10).
class ContentProposalCore {
  final String id;
  final String targetResourceId;
  final String targetConceptSlug;
  final ContentProposalType proposalType;
  final String summary;
  final String proposedDiff;
  final Map<String, dynamic> evidenceData;
  final ProposalReviewStatus status;
  final DateTime createdAt;
  final String? reviewerNotes;

  const ContentProposalCore({
    required this.id,
    required this.targetResourceId,
    required this.targetConceptSlug,
    required this.proposalType,
    required this.summary,
    required this.proposedDiff,
    this.evidenceData = const {},
    this.status = ProposalReviewStatus.pendingReview,
    required this.createdAt,
    this.reviewerNotes,
  });

  factory ContentProposalCore.fromJson(Map<String, dynamic> json) {
    return ContentProposalCore(
      id: json['id'] as String? ?? '',
      targetResourceId: json['target_resource_id'] as String? ?? '',
      targetConceptSlug: json['target_concept_slug'] as String? ?? '',
      proposalType: ContentProposalType.fromString(
          json['proposal_type'] as String? ?? 'misconception_remediation'),
      summary: json['summary'] as String? ?? '',
      proposedDiff: json['proposed_diff'] as String? ?? '',
      evidenceData:
          (json['evidence_data'] as Map?)?.cast<String, dynamic>() ?? const {},
      status: ProposalReviewStatus.fromString(
          json['status'] as String? ?? 'pending_review'),
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      reviewerNotes: json['reviewer_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'target_resource_id': targetResourceId,
        'target_concept_slug': targetConceptSlug,
        'proposal_type': proposalType.toDbString(),
        'summary': summary,
        'proposed_diff': proposedDiff,
        'evidence_data': evidenceData,
        'status': status.toDbString(),
        'created_at': createdAt.toUtc().toIso8601String(),
        if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
      };
}
