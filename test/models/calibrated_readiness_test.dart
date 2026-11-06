import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/calibrated_readiness.dart';
import 'package:learning_pwa/models/user_concept_state.dart';

void main() {
  group('CalibratedReadiness Model Tests', () {
    test('JSON serialization & toTargetReadiness compatibility', () {
      final json = {
        'target_version_id': '11111111-2222-3333-4444-555555555555',
        'exam_date': '2026-12-01T00:00:00.000Z',
        'readiness_score': 0.88,
        'readiness_band': 'strongCoverage',
        'total_core_concepts': 10,
        'assessed_concepts_count': 9,
        'average_retrievability': 0.84,
        'retrieval_bands': {
          'well_established': 5,
          'well_retained': 3,
          'developing': 1,
          'needs_reinforcement': 0,
          'unassessed': 1,
        },
        'weakest_concepts': [
          {
            'concept_id': 'concept-1',
            'title': 'Safety Calculations',
            'score': 0.65,
            'projected_retrievability': 0.70,
            'evidence_count': 4,
          }
        ]
      };

      final calibrated = CalibratedReadiness.fromJson(json);

      expect(calibrated.targetVersionId, '11111111-2222-3333-4444-555555555555');
      expect(calibrated.readinessScore, 0.88);
      expect(calibrated.band, TargetReadinessBand.strongCoverage);
      expect(calibrated.totalCoreConcepts, 10);
      expect(calibrated.assessedConceptsCount, 9);
      expect(calibrated.averageRetrievability, 0.84);
      expect(calibrated.weakestConcepts.length, 1);
      expect(calibrated.weakestConcepts.first.title, 'Safety Calculations');

      final legacy = calibrated.toTargetReadiness();
      expect(legacy.band, TargetReadinessBand.strongCoverage);
      expect(legacy.score, 0.88);
      expect(legacy.totalCoreConcepts, 10);
      expect(legacy.assessedConceptsCount, 9);
      expect(legacy.bandDistribution[RetrievalBand.wellEstablished], 5);
    });
  });
}

