import 'package:learning_core/learning_core.dart';
import '../../models/learning_event.dart';

/// Service managing evidence-based discovery recommendations and autonomous proposals (ECO-09, ECO-10, ECO-11).
class DiscoveryAndFeedbackService {
  final List<ContentProposalCore> _proposals = [];
  final List<LearningEvent> _emittedEvents = [];

  List<ContentProposalCore> get proposals => List.unmodifiable(_proposals);
  List<LearningEvent> get emittedEvents => List.unmodifiable(_emittedEvents);

  /// Generates non-coercive Coach Principle recommendations for a learner.
  List<CoachRecommendation> getRecommendations({
    required List<LearnerConceptStateCore> conceptStates,
    List<ContentQualityScore> availableResources = const [],
  }) {
    return CoachRecommendationEngine.generateRecommendations(
      conceptStates: conceptStates,
      availableResources: availableResources,
    );
  }

  /// Adds a new autonomous proposal to the review queue.
  void submitProposal(ContentProposalCore proposal) {
    _proposals.add(proposal);
  }

  /// Processes an educator/community review action on a proposal.
  ContentProposalCore reviewProposal({
    required String proposalId,
    required ProposalReviewStatus newStatus,
    String? reviewerNotes,
    String? reviewerId,
  }) {
    final index = _proposals.indexWhere((p) => p.id == proposalId);
    if (index == -1) {
      throw ArgumentError('Proposal not found: $proposalId');
    }

    final old = _proposals[index];
    final updated = ContentProposalCore(
      id: old.id,
      targetResourceId: old.targetResourceId,
      targetConceptSlug: old.targetConceptSlug,
      proposalType: old.proposalType,
      summary: old.summary,
      proposedDiff: old.proposedDiff,
      evidenceData: old.evidenceData,
      status: newStatus,
      createdAt: old.createdAt,
      reviewerNotes: reviewerNotes,
    );

    _proposals[index] = updated;

    final event = LearningEvent(
      userId: reviewerId,
      eventType: 'content_proposal_reviewed',
      itemType: 'content_proposal',
      itemId: proposalId,
      metadata: {
        'target_resource_id': old.targetResourceId,
        'target_concept_slug': old.targetConceptSlug,
        'proposal_type': old.proposalType.toDbString(),
        'status': newStatus.toDbString(),
        if (reviewerNotes != null) 'reviewer_notes': reviewerNotes,
      },
    );
    _emittedEvents.add(event);

    return updated;
  }
}
