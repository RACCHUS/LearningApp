import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/governance.dart';
import 'package:learning_pwa/models/user_concept_state.dart';

void main() {
  group('Phase G: Version Governance Models Unit Tests', () {
    group('ConceptTransferDiff', () {
      test('direct match has isDirectMatch=true and 100% label', () {
        const diff = ConceptTransferDiff(
          fromConceptId: 'c1',
          toConceptId: 'c1',
          mappingType: 'unchanged',
          transferWeight: 1.0,
          fromConceptName: 'Symmetric Encryption',
          toConceptName: 'Symmetric Encryption',
        );

        expect(diff.isDirectMatch, isTrue);
        expect(diff.isRemoved, isFalse);
        expect(diff.isScaled, isFalse);
        expect(diff.percentageLabel, '100%');
      });

      test('scaled transfer weight has isScaled=true and percentage label', () {
        const diff = ConceptTransferDiff(
          fromConceptId: 'c1',
          toConceptId: 'c2',
          mappingType: 'expanded',
          transferWeight: 0.75,
          fromConceptName: 'Public Key Infra',
          toConceptName: 'Modern PKI & Certificates',
          userRetrievalBand: RetrievalBand.wellRetained,
        );

        expect(diff.isDirectMatch, isFalse);
        expect(diff.isRemoved, isFalse);
        expect(diff.isScaled, isTrue);
        expect(diff.percentageLabel, '75%');
        expect(diff.userRetrievalBand, RetrievalBand.wellRetained);
      });

      test('removed concept is identified correctly', () {
        const diff1 = ConceptTransferDiff(
          fromConceptId: 'c-legacy',
          toConceptId: null,
          mappingType: 'removed',
          transferWeight: 0.0,
        );
        expect(diff1.isRemoved, isTrue);

        const diff2 = ConceptTransferDiff(
          fromConceptId: 'c-legacy2',
          toConceptId: 'c-legacy2',
          mappingType: 'unchanged',
          transferWeight: 0.0,
        );
        expect(diff2.isRemoved, isTrue);
      });

      test('fromJson and toJson roundtrip preserves all fields', () {
        final json = {
          'from_concept_id': 'c-source',
          'to_concept_id': 'c-dest',
          'mapping_type': 'replaced',
          'transfer_weight': 0.8,
          'from_concept_name': 'Source Name',
          'to_concept_name': 'Dest Name',
          'user_retrieval_band': 'well_established',
        };

        final model = ConceptTransferDiff.fromJson(json);
        expect(model.fromConceptId, 'c-source');
        expect(model.toConceptId, 'c-dest');
        expect(model.mappingType, 'replaced');
        expect(model.transferWeight, 0.8);
        expect(model.fromConceptName, 'Source Name');
        expect(model.toConceptName, 'Dest Name');
        expect(model.userRetrievalBand, RetrievalBand.wellEstablished);

        final outJson = model.toJson();
        expect(outJson['from_concept_id'], 'c-source');
        expect(outJson['transfer_weight'], 0.8);
        expect(outJson['user_retrieval_band'], 'well_established');
      });
    });

    group('TargetVersionMigrationEvaluation', () {
      test('computes boolean helpers correctly', () {
        const evalHigh = TargetVersionMigrationEvaluation(
          fromTargetVersionId: 'v1',
          toTargetVersionId: 'v2',
          totalSourceConcepts: 20,
          totalTargetConcepts: 22,
          mappedConceptsCount: 19,
          retainedConceptsCount: 18,
          removedConceptsCount: 1,
          newConceptsCount: 3,
          transferRetentionPct: 85.0,
          userAssessedConceptsCount: 15,
          projectedRetainedAssessedCount: 13.5,
        );

        expect(evalHigh.hasRemovedConcepts, isTrue);
        expect(evalHigh.hasNewConcepts, isTrue);
        expect(evalHigh.isHighRetention, isTrue);

        const evalLow = TargetVersionMigrationEvaluation(
          fromTargetVersionId: 'v1',
          toTargetVersionId: 'v3',
          totalSourceConcepts: 10,
          totalTargetConcepts: 20,
          mappedConceptsCount: 5,
          retainedConceptsCount: 5,
          removedConceptsCount: 0,
          newConceptsCount: 0,
          transferRetentionPct: 50.0,
          userAssessedConceptsCount: 5,
          projectedRetainedAssessedCount: 2.5,
        );

        expect(evalLow.hasRemovedConcepts, isFalse);
        expect(evalLow.hasNewConcepts, isFalse);
        expect(evalLow.isHighRetention, isFalse);
      });

      test('fromJson and toJson roundtrip parses nested mappings', () {
        final json = {
          'from_target_version_id': 'tv-1',
          'to_target_version_id': 'tv-2',
          'total_source_concepts': 10,
          'total_target_concepts': 12,
          'mapped_concepts_count': 9,
          'retained_concepts_count': 9,
          'removed_concepts_count': 1,
          'new_concepts_count': 3,
          'transfer_retention_pct': 90.0,
          'user_assessed_concepts_count': 8,
          'projected_retained_assessed_count': 7.2,
          'concept_mappings': [
            {
              'from_concept_id': 'c1',
              'to_concept_id': 'c1-new',
              'mapping_type': 'renamed',
              'transfer_weight': 1.0,
            }
          ],
        };

        final eval = TargetVersionMigrationEvaluation.fromJson(json);
        expect(eval.fromTargetVersionId, 'tv-1');
        expect(eval.conceptMappings.length, 1);
        expect(eval.conceptMappings.first.mappingType, 'renamed');

        final serialized = eval.toJson();
        expect(serialized['from_target_version_id'], 'tv-1');
        expect((serialized['concept_mappings'] as List).length, 1);
      });
    });

    group('UserVersionMigrationResult', () {
      test('fromJson and toJson roundtrip', () {
        final json = {
          'success': true,
          'context_id': 'ctx-123',
          'from_version_code': 'SY0-601',
          'to_version_code': 'SY0-701',
          'transferred_concepts_count': 42,
          'retained_mastery_pct': 92.4,
        };

        final result = UserVersionMigrationResult.fromJson(json);
        expect(result.success, isTrue);
        expect(result.contextId, 'ctx-123');
        expect(result.fromVersionCode, 'SY0-601');
        expect(result.toVersionCode, 'SY0-701');
        expect(result.transferredConceptsCount, 42);
        expect(result.retainedMasteryPct, 92.4);

        final out = result.toJson();
        expect(out['success'], isTrue);
        expect(out['retained_mastery_pct'], 92.4);
      });
    });

    group('TargetVersionUpdateInfo', () {
      test('needsUpgrade and upgradeReason for retired version', () {
        const info = TargetVersionUpdateInfo(
          contextId: 'ctx-1',
          userId: 'usr-1',
          targetId: 't-1',
          targetTitle: 'CompTIA Security+',
          currentVersionId: 'v1',
          currentVersionCode: 'SY0-601',
          currentVersionStatus: 'retired',
          latestVersionId: 'v2',
          latestVersionCode: 'SY0-701',
          latestVersionStatus: 'published',
          isOutdated: true,
          isRetired: true,
        );

        expect(info.needsUpgrade, isTrue);
        expect(info.upgradeReason, contains('retired'));
        expect(info.upgradeReason, contains('SY0-601'));
        expect(info.upgradeReason, contains('SY0-701'));
      });

      test('needsUpgrade and upgradeReason for outdated but not retired version', () {
        const info = TargetVersionUpdateInfo(
          contextId: 'ctx-1',
          userId: 'usr-1',
          targetId: 't-1',
          targetTitle: 'CompTIA Security+',
          currentVersionId: 'v1',
          currentVersionCode: 'SY0-601',
          currentVersionStatus: 'published',
          latestVersionId: 'v2',
          latestVersionCode: 'SY0-701',
          latestVersionStatus: 'published',
          isOutdated: true,
          isRetired: false,
        );

        expect(info.needsUpgrade, isTrue);
        expect(info.upgradeReason, contains('newer official blueprint'));
        expect(info.upgradeReason, contains('SY0-701'));
      });

      test('needsUpgrade=false when up to date', () {
        const info = TargetVersionUpdateInfo(
          contextId: 'ctx-1',
          userId: 'usr-1',
          targetId: 't-1',
          targetTitle: 'CompTIA Security+',
          currentVersionId: 'v2',
          currentVersionCode: 'SY0-701',
          currentVersionStatus: 'published',
          latestVersionId: 'v2',
          latestVersionCode: 'SY0-701',
          latestVersionStatus: 'published',
          isOutdated: false,
          isRetired: false,
        );

        expect(info.needsUpgrade, isFalse);
        expect(info.upgradeReason, contains('latest official blueprint'));
      });

      test('fromJson and toJson roundtrip', () {
        final json = {
          'context_id': 'ctx-test',
          'user_id': 'usr-test',
          'target_id': 't-test',
          'target_title': 'Test Target',
          'target_slug': 'test-slug',
          'current_version_id': 'cv-1',
          'current_version_code': 'v1',
          'current_version_title': 'Edition 1',
          'current_version_status': 'published',
          'latest_version_id': 'lv-2',
          'latest_version_code': 'v2',
          'latest_version_title': 'Edition 2',
          'latest_version_status': 'published',
          'is_outdated': true,
          'is_retired': false,
        };

        final info = TargetVersionUpdateInfo.fromJson(json);
        expect(info.contextId, 'ctx-test');
        expect(info.targetSlug, 'test-slug');
        expect(info.isOutdated, isTrue);

        final out = info.toJson();
        expect(out['target_slug'], 'test-slug');
        expect(out['is_outdated'], isTrue);
      });
    });

    group('TargetVersionAuditReport', () {
      test('computes audit report ratios and validation flags', () {
        const report = TargetVersionAuditReport(
          targetVersionId: 'v-audit',
          versionCode: 'SY0-701',
          status: 'review_ready',
          targetTitle: 'CompTIA Security+',
          domainCount: 5,
          objectiveCount: 25,
          leafObjectiveCount: 20,
          domainWeightSum: 100.0,
          isDomainWeightBalanced: true,
          lessonCount: 40,
          lessonBlockCount: 200,
          stimulusCount: 10,
          assessmentItemCount: 60,
          emptyObjectivesCount: 0,
          conceptCoverageCount: 50,
          unassessedConceptsCount: 5,
          provenanceCitationsCount: 25,
          missingProvenanceCount: 0,
          crossVersionMappingsCount: 45,
          canStageReview: true,
          canPublish: true,
          blockingIssues: [],
          warnings: ['Minor warning'],
        );

        expect(report.isClean, isTrue);
        expect(report.hasWarnings, isTrue);
        expect(report.totalContentItems, 40 + 10 + 60);
        expect(report.assessmentToObjectiveRatio, 3.0);
        expect(report.conceptAssessmentCoveragePct, 90.0);
      });

      test('handles zero leaf objectives and zero concept coverage without dividing by zero', () {
        const report = TargetVersionAuditReport(
          targetVersionId: 'v-zero',
          versionCode: 'v0',
          status: 'draft',
          targetTitle: 'Empty Target',
          domainCount: 0,
          objectiveCount: 0,
          leafObjectiveCount: 0,
          domainWeightSum: 0.0,
          isDomainWeightBalanced: false,
          lessonCount: 0,
          lessonBlockCount: 0,
          stimulusCount: 0,
          assessmentItemCount: 0,
          emptyObjectivesCount: 0,
          conceptCoverageCount: 0,
          unassessedConceptsCount: 0,
          provenanceCitationsCount: 0,
          missingProvenanceCount: 0,
          crossVersionMappingsCount: 0,
          canStageReview: false,
          canPublish: false,
          blockingIssues: ['No domains defined'],
        );

        expect(report.isClean, isFalse);
        expect(report.assessmentToObjectiveRatio, 0.0);
        expect(report.conceptAssessmentCoveragePct, 100.0);
      });

      test('fromJson and toJson roundtrip', () {
        final json = {
          'target_version_id': 'tv-audit-1',
          'version_code': 'v1.0.0',
          'status': 'published',
          'target_title': 'Audit Target',
          'domain_count': 3,
          'objective_count': 12,
          'leaf_objective_count': 10,
          'domain_weight_sum': 100.0,
          'is_domain_weight_balanced': true,
          'lesson_count': 15,
          'lesson_block_count': 45,
          'stimulus_count': 2,
          'assessment_item_count': 30,
          'empty_objectives_count': 0,
          'concept_coverage_count': 20,
          'unassessed_concepts_count': 2,
          'provenance_citations_count': 10,
          'missing_provenance_count': 0,
          'cross_version_mappings_count': 0,
          'can_stage_review': true,
          'can_publish': true,
          'blocking_issues': <String>[],
          'warnings': ['Warning 1'],
        };

        final report = TargetVersionAuditReport.fromJson(json);
        expect(report.targetVersionId, 'tv-audit-1');
        expect(report.warnings.length, 1);

        final out = report.toJson();
        expect(out['target_version_id'], 'tv-audit-1');
        expect(out['is_domain_weight_balanced'], isTrue);
      });
    });
  });
}
