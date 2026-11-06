import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('EvidenceScorerCore (ECO-09)', () {
    test('computes composite Educational Quality Index accurately with standard weights', () {
      // Gain: 0.80 * 0.35 = 0.280
      // Retention: 0.90 * 0.30 = 0.270
      // Provenance: official (1.0) * 0.20 = 0.200
      // Psychometric: 1.0 * 0.15 = 0.150
      // Total = 0.900 -> Exemplary
      final score = EvidenceScorerCore.evaluateResource(
        resourceId: 'res-official-1',
        diagnosticGain: 0.80,
        retentionRate: 0.90,
        provenanceOrigin: 'official',
        psychometricHealth: 1.0,
      );

      expect(score.resourceId, equals('res-official-1'));
      expect(score.provenanceTrustWeight, equals(1.0));
      expect(score.educationalQualityIndex, equals(0.90));
      expect(score.qualityTier, equals(QualityTier.exemplary));
    });

    test('penalizes unverified community or private resources via provenance weights', () {
      final unverified = EvidenceScorerCore.evaluateResource(
        resourceId: 'res-private-1',
        diagnosticGain: 0.50,
        retentionRate: 0.50,
        provenanceOrigin: 'private', // 0.30 weight
      );

      // (0.5 * 0.35) + (0.5 * 0.30) + (0.3 * 0.20) + (1.0 * 0.15)
      // = 0.175 + 0.150 + 0.060 + 0.150 = 0.535 -> Adequate
      expect(unverified.provenanceTrustWeight, equals(0.30));
      expect(unverified.educationalQualityIndex, equals(0.535));
      expect(unverified.qualityTier, equals(QualityTier.adequate));
    });

    test('rankResources orders resources descending by Educational Quality Index', () {
      final highRes = EvidenceScorerCore.evaluateResource(
        resourceId: 'high-res',
        diagnosticGain: 0.85,
        retentionRate: 0.85,
        provenanceOrigin: 'official',
      );
      final medRes = EvidenceScorerCore.evaluateResource(
        resourceId: 'med-res',
        diagnosticGain: 0.60,
        retentionRate: 0.60,
        provenanceOrigin: 'catalog',
      );
      final lowRes = EvidenceScorerCore.evaluateResource(
        resourceId: 'low-res',
        diagnosticGain: 0.20,
        retentionRate: 0.30,
        provenanceOrigin: 'community_pending',
      );

      final ranked = EvidenceScorerCore.rankResources([lowRes, highRes, medRes]);

      expect(ranked.first.resourceId, equals('high-res'));
      expect(ranked[1].resourceId, equals('med-res'));
      expect(ranked.last.resourceId, equals('low-res'));
    });
  });
}
