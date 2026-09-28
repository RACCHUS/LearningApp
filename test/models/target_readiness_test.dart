import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/user_concept_state.dart';

void main() {
  group('UserConceptState.computeBandAndConfidence (§8.2)', () {
    test('returns unassessed for 0 evidence', () {
      final res = UserConceptState.computeBandAndConfidence(accuracy: 0.0, evidenceCount: 0);
      expect(res.band, equals(RetrievalBand.unassessed));
      expect(res.confidence, equals(ConceptConfidence.low));
    });

    test('returns needsReinforcement for accuracy < 0.6', () {
      final res = UserConceptState.computeBandAndConfidence(accuracy: 0.5, evidenceCount: 3);
      expect(res.band, equals(RetrievalBand.needsReinforcement));
      expect(res.confidence, equals(ConceptConfidence.medium));
    });

    test('returns developing for 0.6 <= accuracy < 0.85', () {
      final res = UserConceptState.computeBandAndConfidence(accuracy: 0.75, evidenceCount: 4);
      expect(res.band, equals(RetrievalBand.developing));
      expect(res.confidence, equals(ConceptConfidence.medium));
    });

    test('returns wellRetained for accuracy >= 0.85 and evidenceCount >= 3', () {
      final res = UserConceptState.computeBandAndConfidence(accuracy: 0.88, evidenceCount: 3);
      expect(res.band, equals(RetrievalBand.wellRetained));
      expect(res.confidence, equals(ConceptConfidence.medium));
    });

    test('returns wellEstablished for accuracy >= 0.90, evidenceCount >= 5, and high confidence', () {
      final res = UserConceptState.computeBandAndConfidence(accuracy: 0.95, evidenceCount: 6);
      expect(res.band, equals(RetrievalBand.wellEstablished));
      expect(res.confidence, equals(ConceptConfidence.high));
    });
  });

  group('TargetReadiness.evaluate (§9 Formula & Qualitative Bands)', () {
    test('returns notYetAssessed when no concepts or 0 evidence', () {
      final readiness = TargetReadiness.evaluate(
        targetVersionId: 'v1',
        coreConcepts: [
          (conceptId: 'c1', weight: 1.0),
          (conceptId: 'c2', weight: 1.0),
        ],
        userConceptStates: {},
      );

      expect(readiness.band, equals(TargetReadinessBand.notYetAssessed));
      expect(readiness.totalCoreConcepts, equals(2));
      expect(readiness.assessedConceptsCount, equals(0));
      expect(readiness.score, equals(0.0));
      expect(readiness.bandDistribution[RetrievalBand.unassessed], equals(2));
    });

    test('evaluates weighted readiness and assigns strongCoverage when score >= 0.85', () {
      final readiness = TargetReadiness.evaluate(
        targetVersionId: 'v1',
        coreConcepts: [
          (conceptId: 'c1', weight: 1.0),
          (conceptId: 'c2', weight: 1.0),
        ],
        userConceptStates: {
          'c1': UserConceptState(
            userId: 'u1',
            conceptId: 'c1',
            retrievalBand: RetrievalBand.wellEstablished,
            confidence: ConceptConfidence.high,
            evidenceCount: 5,
            weightedCorrect: 5.0,
            weightedTotal: 5.0,
            updatedAt: DateTime.now(),
          ),
          'c2': UserConceptState(
            userId: 'u1',
            conceptId: 'c2',
            retrievalBand: RetrievalBand.wellRetained,
            confidence: ConceptConfidence.medium,
            evidenceCount: 3,
            weightedCorrect: 2.8,
            weightedTotal: 3.0,
            updatedAt: DateTime.now(),
          ),
        },
      );

      // (1.0 * 1.0 + 0.85 * 1.0) / 2.0 = 0.925
      expect(readiness.band, equals(TargetReadinessBand.strongCoverage));
      expect(readiness.score, closeTo(0.925, 0.01));
      expect(readiness.assessedConceptsCount, equals(2));
      expect(readiness.bandDistribution[RetrievalBand.wellEstablished], equals(1));
      expect(readiness.bandDistribution[RetrievalBand.wellRetained], equals(1));
    });

    test('evaluates developing band when 0.60 <= score < 0.85', () {
      final readiness = TargetReadiness.evaluate(
        targetVersionId: 'v1',
        coreConcepts: [
          (conceptId: 'c1', weight: 1.0),
        ],
        userConceptStates: {
          'c1': UserConceptState(
            userId: 'u1',
            conceptId: 'c1',
            retrievalBand: RetrievalBand.developing,
            confidence: ConceptConfidence.medium,
            evidenceCount: 3,
            weightedCorrect: 2.0,
            weightedTotal: 3.0,
            updatedAt: DateTime.now(),
          ),
        },
      );

      expect(readiness.band, equals(TargetReadinessBand.developing));
      expect(readiness.score, closeTo(0.60, 0.01));
    });

    test('evaluates needsReinforcement band when score < 0.60', () {
      final readiness = TargetReadiness.evaluate(
        targetVersionId: 'v1',
        coreConcepts: [
          (conceptId: 'c1', weight: 1.0),
        ],
        userConceptStates: {
          'c1': UserConceptState(
            userId: 'u1',
            conceptId: 'c1',
            retrievalBand: RetrievalBand.needsReinforcement,
            confidence: ConceptConfidence.low,
            evidenceCount: 2,
            weightedCorrect: 0.5,
            weightedTotal: 2.0,
            updatedAt: DateTime.now(),
          ),
        },
      );

      expect(readiness.band, equals(TargetReadinessBand.needsReinforcement));
      expect(readiness.score, closeTo(0.25, 0.01));
    });
  });
}
