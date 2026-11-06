import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('CoachRecommendationEngine (ECO-11 Coach Principle)', () {
    test('prioritizes memory decay review when retrievability is below 80%', () {
      final decayingConcept = LearnerConceptStateCore(
        conceptSlug: 'pharmacology-beta-blockers',
        retrievability: 0.72,
        stabilityDays: 3.5,
      );

      final recs = CoachRecommendationEngine.generateRecommendations(
        conceptStates: [decayingConcept],
      );

      expect(recs.length, equals(1));
      final rec = recs.first;
      expect(rec.urgency, equals(RecommendationUrgency.immediateReview));
      expect(rec.targetConceptSlug, equals('pharmacology-beta-blockers'));
      expect(rec.headline, contains('Memory Refresh'));
      expect(rec.rationale, contains('Retrievability has decayed to 72% based on FSRS spacing'));
      expect(rec.recommendedAction, equals('review_flashcards'));
    });

    test('generates targeted clarification recommendation for unaddressed misconceptions', () {
      final misconceptionConcept = LearnerConceptStateCore(
        conceptSlug: 'circuits-kirchhoff-voltage',
        retrievability: 0.92,
        stabilityDays: 14.0,
        unremediatedMisconception: 'Sum of voltages in a loop is zero, not dependent on current direction.',
      );

      final recs = CoachRecommendationEngine.generateRecommendations(
        conceptStates: [misconceptionConcept],
      );

      expect(recs.length, equals(1));
      final rec = recs.first;
      expect(rec.urgency, equals(RecommendationUrgency.misconceptionRemediation));
      expect(rec.targetConceptSlug, equals('circuits-kirchhoff-voltage'));
      expect(rec.headline, contains('Targeted Clarification'));
      expect(rec.rationale, contains('Recent assessment indicated'));
      expect(rec.recommendedAction, equals('practice_items'));
    });

    test('recommends high-gain enrichment when retention is solid', () {
      final solidConcept = LearnerConceptStateCore(
        conceptSlug: 'quantum-superposition',
        retrievability: 0.95,
        stabilityDays: 30.0,
      );

      final highGainResource = EvidenceScorerCore.evaluateResource(
        resourceId: 'res-quantum-interactive',
        diagnosticGain: 0.78,
        retentionRate: 0.88,
        provenanceOrigin: 'official',
      );

      final recs = CoachRecommendationEngine.generateRecommendations(
        conceptStates: [solidConcept],
        availableResources: [highGainResource],
      );

      expect(recs.length, equals(1));
      final rec = recs.first;
      expect(rec.urgency, equals(RecommendationUrgency.enrichment));
      expect(rec.headline, contains('Expand Mastery'));
      expect(rec.measuredLearningGain, equals(0.78));
      expect(rec.rationale, contains('measured gain of 78%'));
      expect(rec.recommendedAction, equals('watch_video'));
    });
  });
}
