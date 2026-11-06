import 'evidence_scorer_core.dart';

/// Urgency level for non-coercive Coach recommendations (ECO-11).
enum RecommendationUrgency {
  immediateReview,
  misconceptionRemediation,
  enrichment;

  String toDbString() {
    switch (this) {
      case RecommendationUrgency.immediateReview:
        return 'immediate_review';
      case RecommendationUrgency.misconceptionRemediation:
        return 'misconception_remediation';
      case RecommendationUrgency.enrichment:
        return 'enrichment';
    }
  }

  String get label {
    switch (this) {
      case RecommendationUrgency.immediateReview:
        return 'Review Due (FSRS)';
      case RecommendationUrgency.misconceptionRemediation:
        return 'Clarify Misconception';
      case RecommendationUrgency.enrichment:
        return 'High-Gain Next Step';
    }
  }
}

/// A transparent, opt-in learning recommendation adhering to the Coach Principle (ECO-11).
///
/// Coach Principle: Always suggesting, never compelling. Every recommendation
/// provides an explicit, evidence-backed rationale explaining why it is beneficial.
class CoachRecommendation {
  final String id;
  final String targetConceptSlug;
  final RecommendationUrgency urgency;
  final String headline;
  final String rationale;
  final String? resourceId;
  final String? resourceTitle;
  final String recommendedAction;
  final double? measuredLearningGain;

  const CoachRecommendation({
    required this.id,
    required this.targetConceptSlug,
    required this.urgency,
    required this.headline,
    required this.rationale,
    this.resourceId,
    this.resourceTitle,
    required this.recommendedAction,
    this.measuredLearningGain,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'target_concept_slug': targetConceptSlug,
        'urgency': urgency.toDbString(),
        'headline': headline,
        'rationale': rationale,
        if (resourceId != null) 'resource_id': resourceId,
        if (resourceTitle != null) 'resource_title': resourceTitle,
        'recommended_action': recommendedAction,
        if (measuredLearningGain != null)
          'measured_learning_gain': measuredLearningGain,
      };
}

/// Learner's current mastery and memory state for a single concept.
class LearnerConceptStateCore {
  final String conceptSlug;
  final double retrievability; // 0.0 to 1.0 (from FSRS)
  final double stabilityDays;
  final String? unremediatedMisconception;
  final double? lastScore;

  const LearnerConceptStateCore({
    required this.conceptSlug,
    required this.retrievability,
    required this.stabilityDays,
    this.unremediatedMisconception,
    this.lastScore,
  });
}

/// Engine generating evidence-based, non-coercive recommendations (ECO-11).
class CoachRecommendationEngine {
  const CoachRecommendationEngine._();

  /// Evaluates learner concept states and returns prioritized recommendations.
  static List<CoachRecommendation> generateRecommendations({
    required List<LearnerConceptStateCore> conceptStates,
    List<ContentQualityScore> availableResources = const [],
    int maxRecommendations = 5,
  }) {
    final recommendations = <CoachRecommendation>[];

    // 1. Check for memory decay boundary (FSRS Retrievability < 0.80)
    for (final state in conceptStates) {
      if (state.retrievability < 0.80) {
        final retPct = (state.retrievability * 100).toInt();
        recommendations.add(
          CoachRecommendation(
            id: 'rec-decay-${state.conceptSlug}',
            targetConceptSlug: state.conceptSlug,
            urgency: RecommendationUrgency.immediateReview,
            headline: 'Memory Refresh: ${state.conceptSlug}',
            rationale: 'Retrievability has decayed to $retPct% based on FSRS spacing. A 2-minute review will restore retention to 90%+.',
            recommendedAction: 'review_flashcards',
          ),
        );
      }
    }

    // 2. Check for unremediated misconceptions
    for (final state in conceptStates) {
      if (state.unremediatedMisconception != null &&
          state.unremediatedMisconception!.isNotEmpty) {
        recommendations.add(
          CoachRecommendation(
            id: 'rec-misconception-${state.conceptSlug}',
            targetConceptSlug: state.conceptSlug,
            urgency: RecommendationUrgency.misconceptionRemediation,
            headline: 'Targeted Clarification: ${state.conceptSlug}',
            rationale: 'Recent assessment indicated: "${state.unremediatedMisconception}". A targeted worked example will clarify the distinction.',
            recommendedAction: 'practice_items',
          ),
        );
      }
    }

    // 3. High-evidence enrichment for unmastered concepts
    for (final state in conceptStates) {
      if (state.retrievability >= 0.80 && state.unremediatedMisconception == null) {
        // Look for exemplary resources with high educational gain
        for (final res in availableResources) {
          if (res.educationalQualityIndex >= 0.70) {
            recommendations.add(
              CoachRecommendation(
                id: 'rec-enrich-${state.conceptSlug}-${res.resourceId}',
                targetConceptSlug: state.conceptSlug,
                urgency: RecommendationUrgency.enrichment,
                headline: 'Expand Mastery: ${state.conceptSlug}',
                rationale: 'You have solid retention here. This high-evidence resource (${res.qualityTier.label}) delivers a measured gain of ${(res.diagnosticGainScore * 100).toInt()}%.',
                resourceId: res.resourceId,
                recommendedAction: 'watch_video',
                measuredLearningGain: res.diagnosticGainScore,
              ),
            );
            break;
          }
        }
      }
    }

    // Deduplicate by targetConceptSlug and prioritize by urgency
    final uniqueRecommendations = <String, CoachRecommendation>{};
    for (final rec in recommendations) {
      if (!uniqueRecommendations.containsKey(rec.targetConceptSlug)) {
        uniqueRecommendations[rec.targetConceptSlug] = rec;
      }
    }

    final sorted = uniqueRecommendations.values.toList()
      ..sort((a, b) => a.urgency.index.compareTo(b.urgency.index));

    return sorted.take(maxRecommendations).toList();
  }
}
