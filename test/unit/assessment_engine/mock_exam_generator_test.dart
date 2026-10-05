import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';

void main() {
  group('Phase E: MockExamBlueprint & Quota Computation Tests', () {
    final comptiaDomains = [
      const DomainWeightConstraint(
        domainId: 'dom-1',
        domainCode: '1.0',
        domainTitle: 'General Security Concepts',
        weight: 0.12, // 12%
      ),
      const DomainWeightConstraint(
        domainId: 'dom-2',
        domainCode: '2.0',
        domainTitle: 'Threats, Vulnerabilities & Mitigations',
        weight: 0.22, // 22%
      ),
      const DomainWeightConstraint(
        domainId: 'dom-3',
        domainCode: '3.0',
        domainTitle: 'Security Architecture',
        weight: 0.18, // 18%
      ),
      const DomainWeightConstraint(
        domainId: 'dom-4',
        domainCode: '4.0',
        domainTitle: 'Security Operations',
        weight: 0.28, // 28%
      ),
      const DomainWeightConstraint(
        domainId: 'dom-5',
        domainCode: '5.0',
        domainTitle: 'Security Program Management & Oversight',
        weight: 0.20, // 20%
      ),
    ];

    final blueprint = MockExamBlueprint(
      targetVersionId: 'tv-sy0-701',
      examCode: 'SY0-701',
      title: 'CompTIA Security+ (SY0-701) Official Blueprint',
      domainWeights: comptiaDomains,
      officialPassingScore: 750,
      officialScoreScale: '100-900',
    );

    test('Computes exact question quotas for standard 50-item exam', () {
      final quotas = blueprint.computeDomainQuotas(50);

      // 50 * 0.12 = 6
      expect(quotas['dom-1'], equals(6));
      // 50 * 0.22 = 11
      expect(quotas['dom-2'], equals(11));
      // 50 * 0.18 = 9
      expect(quotas['dom-3'], equals(9));
      // 50 * 0.28 = 14
      expect(quotas['dom-4'], equals(14));
      // 50 * 0.20 = 10
      expect(quotas['dom-5'], equals(10));

      final totalAllocated = quotas.values.fold<int>(0, (sum, count) => sum + count);
      expect(totalAllocated, equals(50));
    });

    test('Computes exact question quotas for full 90-item exam with remainder distribution', () {
      final quotas = blueprint.computeDomainQuotas(90);

      // 90 * 0.12 = 10.8 -> 11
      expect(quotas['dom-1'], equals(11));
      // 90 * 0.22 = 19.8 -> 20
      expect(quotas['dom-2'], equals(20));
      // 90 * 0.18 = 16.2 -> 16
      expect(quotas['dom-3'], equals(16));
      // 90 * 0.28 = 25.2 -> 25
      expect(quotas['dom-4'], equals(25));
      // 90 * 0.20 = 18.0 -> 18
      expect(quotas['dom-5'], equals(18));

      final totalAllocated = quotas.values.fold<int>(0, (sum, count) => sum + count);
      expect(totalAllocated, equals(90));
    });

    test('Handles prime question count (33 items) preserving total sum constraint', () {
      final quotas = blueprint.computeDomainQuotas(33);

      final totalAllocated = quotas.values.fold<int>(0, (sum, count) => sum + count);
      expect(totalAllocated, equals(33));

      // Each domain should receive a reasonable proportion
      expect(quotas['dom-1']!, greaterThanOrEqualTo(3));
      expect(quotas['dom-4']!, greaterThanOrEqualTo(quotas['dom-1']!));
    });

    test('Normalizes unnormalized domain weights gracefully', () {
      final unnormalizedDomains = [
        const DomainWeightConstraint(
          domainId: 'dom-a',
          domainCode: 'A',
          domainTitle: 'Domain A',
          weight: 60.0,
        ),
        const DomainWeightConstraint(
          domainId: 'dom-b',
          domainCode: 'B',
          domainTitle: 'Domain B',
          weight: 40.0,
        ),
      ];

      final unnormBlueprint = MockExamBlueprint(
        targetVersionId: 'tv-test',
        examCode: 'TEST-101',
        title: 'Unnormalized Test',
        domainWeights: unnormalizedDomains,
      );

      final quotas = unnormBlueprint.computeDomainQuotas(10);
      expect(quotas['dom-a'], equals(6));
      expect(quotas['dom-b'], equals(4));
    });
  });
}
