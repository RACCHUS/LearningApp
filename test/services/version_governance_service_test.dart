import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/version_governance_service.dart';

void main() {
  group('Phase G: VersionGovernanceService Unit Tests', () {
    late VersionGovernanceService service;

    setUp(() {
      // In offline/mock mode (null client), service uses comprehensive fallback mocks
      service = VersionGovernanceService(supabaseClient: null);
    });

    test('evaluateMigration returns robust projection in offline/fallback mode', () async {
      final eval = await service.evaluateMigration(
        userId: 'test-user-id',
        fromVersionId: 'v-sy0-601',
        toVersionId: 'v-sy0-701',
      );

      expect(eval.fromTargetVersionId, 'v-sy0-601');
      expect(eval.toTargetVersionId, 'v-sy0-701');
      expect(eval.totalSourceConcepts, greaterThan(0));
      expect(eval.totalTargetConcepts, greaterThan(0));
      expect(eval.transferRetentionPct, greaterThanOrEqualTo(80.0));
      expect(eval.isHighRetention, isTrue);
      expect(eval.conceptMappings, isNotEmpty);

      // Verify mapping types include expanded and removed mappings
      expect(eval.conceptMappings.any((m) => m.mappingType == 'expanded'), isTrue);
      expect(eval.conceptMappings.any((m) => m.isRemoved), isTrue);
    });

    test('migrateUserContext returns successful migration result in offline mode', () async {
      final result = await service.migrateUserContext(
        userId: 'test-user-id',
        contextId: 'test-context-id',
        toVersionId: 'v-sy0-701',
      );

      expect(result.success, isTrue);
      expect(result.contextId, 'test-context-id');
      expect(result.transferredConceptsCount, greaterThan(0));
      expect(result.retainedMasteryPct, greaterThan(0.0));
    });

    test('auditTargetVersionReadiness returns comprehensive QA report in offline mode', () async {
      final report = await service.auditTargetVersionReadiness('v-sy0-701');

      expect(report.targetVersionId, 'v-sy0-701');
      expect(report.versionCode, 'SY0-701');
      expect(report.status, 'review_ready');
      expect(report.isDomainWeightBalanced, isTrue);
      expect(report.domainWeightSum, 100.0);
      expect(report.domainCount, 5);
      expect(report.leafObjectiveCount, greaterThan(0));
      expect(report.lessonCount, greaterThan(0));
      expect(report.assessmentItemCount, greaterThan(0));
      expect(report.canStageReview, isTrue);
      expect(report.canPublish, isTrue);
      expect(report.isClean, isTrue);
    });

    test('stageReview executes without throwing when client is null', () async {
      expect(service.stageReview('v-sy0-701'), completes);
    });

    test('publishVersion returns published response in offline mode', () async {
      final result = await service.publishVersion('v-sy0-701', retirePrevious: true);

      expect(result['success'], isTrue);
      expect(result['status'], 'published');
      expect(result['target_version_id'], 'v-sy0-701');
    });

    test('retireVersion returns retired response in offline mode', () async {
      final result = await service.retireVersion('v-sy0-601');

      expect(result['success'], isTrue);
      expect(result['status'], 'retired');
      expect(result['target_version_id'], 'v-sy0-601');
    });

    test('getContextVersionUpdate returns null when no client is available', () async {
      final update = await service.getContextVersionUpdate('ctx-none');
      expect(update, isNull);
    });

    test('getStagedTargetVersions returns empty list when no client is available', () async {
      final staged = await service.getStagedTargetVersions();
      expect(staged, isEmpty);
    });
  });
}
