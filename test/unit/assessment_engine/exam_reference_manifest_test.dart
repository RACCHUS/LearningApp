import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/exam_reference_manifest.dart';

void main() {
  Map<String, dynamic> targetMetadata({
    String partKey = 'project_management',
    bool withScope = true,
    Map<String, dynamic>? requirements,
  }) => {
        'exam_preparation': {
          'schema_version': 1,
          'exam_parts': [
            {
              'key': partKey,
              'display_name': 'Project Management',
              if (withScope) 'curriculum_root_node_id': 'node-pm',
              'requirements': requirements ?? {},
            },
          ],
          'review_status': 'draft',
        },
      };

  Map<String, dynamic> manifestRow({
    String id = 'manifest-2027',
    String version = 'target-v1',
    String part = 'project_management',
    String from = '2027-01-01',
    String? until = '2027-12-31',
    String status = 'published',
    int revision = 2,
    String reviewStatus = 'approved',
  }) => {
        'id': id,
        'target_version_id': version,
        'exam_part_key': part,
        'revision': revision,
        'effective_from': from,
        'effective_until': until,
        'publication_status': status,
        'review_status': reviewStatus,
        'reviewed_at': '2026-10-18T19:00:00Z',
        'reviewer_ref': 'external-review-1',
        'official_source_url': 'https://www.example.gov/primary-reference.pdf',
        'source_release_id': 'source-release-1',
        'source_checked_at': '2026-10-18T18:00:00Z',
        'reference_entries': [
          {
            'key': 'example-publication',
            'edition': '2027',
            'source_page': '2',
          },
        ],
        'room_rules': [
          {'name': 'tabs', 'state': 'unknown', 'value': null},
        ],
      };

  group('EXM-01 part profile', () {
    test('No profile is not an invitation to create a fictitious exam part', () {
      expect(ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: const {},
      ), isNull);
    });

    test('Draft unknown official requirements remain unset', () {
      final profile = ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: targetMetadata(requirements: {
          'time_limit_minutes': {
            'state': 'unknown', 'value': null, 'evidence_ids': [],
          },
        }),
      )!;
      final fact = profile.findPart('project_management')!
          .officialRequirements['time_limit_minutes']!;
      expect(fact.state, ExamFactState.unknown);
      expect(fact.value, isNull);
      expect(profile.findPart('business_finance'), isNull);
    });

    test('Verified official facts require both value and evidence', () {
      expect(() => ExamOfficialFact.fromJson({
        'state': 'verified',
        'value': 90,
        'evidence_ids': [],
      }), throwsFormatException);
      expect(() => ExamOfficialFact.fromJson({
        'state': 'verified',
        'value': 90,
        'evidence_ids': ['official-source-page-1'],
      }), returnsNormally);
      expect(() => ExamOfficialFact.fromJson({
        'state': 'unknown',
        'value': 90,
      }), throwsFormatException);
    });

    test('Verified claims require resolvable primary source records', () {
      final metadata = targetMetadata(requirements: {
        'reference_mode': {
          'state': 'verified',
          'value': 'candidate_supplied_paper',
          'evidence_ids': ['regulator-pdf-1'],
        },
      });
      expect(() => ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: metadata,
      ), throwsFormatException);

      (metadata['exam_preparation'] as Map)['source_evidence'] = [
        {
          'id': 'regulator-pdf-1',
          'official_url': 'https://www.example.gov/reference.pdf',
          'source_page': '1',
          'source_checked_at': '2026-10-18T18:00:00Z',
        },
      ];
      expect(() => ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: metadata,
      ), returnsNormally);

      (metadata['exam_preparation'] as Map)['source_evidence'] = [
        {
          'id': 'regulator-pdf-1',
          'official_url': 'https://www.example.gov/reference.pdf',
          'source_checked_at': '2026-10-18T18:00:00Z',
        },
      ];
      expect(() => ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: metadata,
      ), throwsFormatException);
    });

    test('Duplicate or malformed parts fail closed', () {
      final metadata = targetMetadata();
      (metadata['exam_preparation'] as Map)['exam_parts'] = [
        {
          'key': 'project_management',
          'display_name': 'PM',
          'curriculum_root_node_id': 'node-pm',
        },
        {
          'key': 'project_management',
          'display_name': 'PM duplicate',
          'curriculum_root_node_id': 'node-duplicate',
        },
      ];
      expect(() => ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: metadata,
      ), throwsFormatException);
      expect(() => ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: targetMetadata(partKey: 'Bad Key'),
      ), throwsFormatException);
    });
  });

  group('EXM-01 effective-dated reference selection', () {
    final profile = ExamPreparationProfile.fromTargetVersionMetadata(
      targetVersionId: 'target-v1',
      metadata: targetMetadata(),
    )!;
    const resolver = ExamReferenceManifestResolver();

    test('2026 and 2027 can share a target without curriculum clone', () {
      final v2026 = ExamReferenceManifestRevision.fromRow(manifestRow(
        id: 'manifest-2026',
        revision: 1,
        from: '2026-01-01',
        until: '2026-12-31',
      ));
      final v2027 = ExamReferenceManifestRevision.fromRow(manifestRow());
      final earlier = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2026, 12, 31),
        revisions: [v2026, v2027],
      );
      final later = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 1, 1),
        revisions: [v2026, v2027],
      );
      expect(earlier.revision?.id, 'manifest-2026');
      expect(later.revision?.id, 'manifest-2027');
      expect(earlier.revision!.targetVersionId, later.revision!.targetVersionId);
      expect(later.isSelected, isTrue);
    });

    test('Within-year edition changes resolve by exact administration day', () {
      final earlier = ExamReferenceManifestRevision.fromRow(manifestRow(
        id: 'pre-switch',
        from: '2027-01-01',
        until: '2027-07-31',
        revision: 2,
      ));
      final later = ExamReferenceManifestRevision.fromRow(manifestRow(
        id: 'post-switch',
        from: '2027-08-01',
        until: '2027-12-31',
        revision: 3,
      ));
      expect(resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 7, 31),
        revisions: [earlier, later],
      ).revision?.id, 'pre-switch');
      expect(resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 8, 1),
        revisions: [earlier, later],
      ).revision?.id, 'post-switch');
    });

    test('2027-only references never claim to cover 2026 exam dates', () {
      final only2027 = ExamReferenceManifestRevision.fromRow(manifestRow());
      final result = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2026, 11, 20),
        revisions: [only2027],
      );
      expect(result.status, ExamManifestSelectionStatus.noApplicableRevision);
      expect(result.revision, isNull);
    });

    test('Missing exam date, part root or selected part fails closed', () {
      final source = ExamReferenceManifestRevision.fromRow(manifestRow());
      final noDate = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: null,
        revisions: [source],
      );
      expect(noDate.status, ExamManifestSelectionStatus.unknownExamDate);
      final wrongPart = resolver.select(
        profile: profile,
        examPartKey: 'business_finance',
        administrationDate: DateTime.utc(2027, 1, 1),
        revisions: [source],
      );
      expect(wrongPart.status, ExamManifestSelectionStatus.unknownExamPart);
      final unscopedProfile = ExamPreparationProfile.fromTargetVersionMetadata(
        targetVersionId: 'target-v1',
        metadata: targetMetadata(withScope: false),
      )!;
      expect(resolver.select(
        profile: unscopedProfile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 1, 1),
        revisions: [source],
      ).status, ExamManifestSelectionStatus.missingPartScope);
    });

    test('Overlapping published revisions are ambiguous, never newest-wins', () {
      final a = ExamReferenceManifestRevision.fromRow(manifestRow());
      final b = ExamReferenceManifestRevision.fromRow(manifestRow(
        id: 'overlap', revision: 3, from: '2027-06-01',
      ));
      final selected = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 7, 1),
        revisions: [a, b],
      );
      expect(selected.status, ExamManifestSelectionStatus.conflictingRevisions);
      expect(selected.revision, isNull);
    });

    test('Draft, unreviewed and foreign target/part manifests are excluded', () {
      final records = [
        ExamReferenceManifestRevision.fromRow(manifestRow(status: 'draft')),
        ExamReferenceManifestRevision.fromRow(manifestRow(
          id: 'unreviewed', revision: 3, status: 'draft', reviewStatus: 'pending')),
        ExamReferenceManifestRevision.fromRow(manifestRow(
          id: 'foreign', revision: 4, version: 'other-target')),
        ExamReferenceManifestRevision.fromRow(manifestRow(
          id: 'other-part', revision: 5, part: 'contract_administration')),
      ];
      final result = resolver.select(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 7, 1),
        revisions: records,
      );
      expect(result.status, ExamManifestSelectionStatus.noApplicableRevision);
    });

    test('A nominally published but unreviewed record is rejected on parse', () {
      expect(() => ExamReferenceManifestRevision.fromRow(manifestRow(
        reviewStatus: 'pending',
      )), throwsFormatException);
      final noReferences = manifestRow()..['reference_entries'] = [];
      expect(() => ExamReferenceManifestRevision.fromRow(noReferences),
          throwsFormatException);
    });

    test('A published record requires independent source, review, and exact edition anchors', () {
      final missingRelease = manifestRow()..remove('source_release_id');
      expect(() => ExamReferenceManifestRevision.fromRow(missingRelease),
          throwsFormatException);

      final reviewBeforeSource = manifestRow()
        ..['reviewed_at'] = '2026-10-18T17:00:00Z';
      expect(() => ExamReferenceManifestRevision.fromRow(reviewBeforeSource),
          throwsFormatException);

      final noPage = manifestRow()..['reference_entries'] = [
        {'key': 'example-publication', 'edition': '2027'}
      ];
      expect(() => ExamReferenceManifestRevision.fromRow(noPage),
          throwsFormatException);

      final unsourcedRule = manifestRow()..['room_rules'] = [
        {'name': 'tabs', 'state': 'verified', 'value': true}
      ];
      expect(() => ExamReferenceManifestRevision.fromRow(unsourcedRule),
          throwsFormatException);
    });

    test('Invalid effective dates cannot be accepted as a manifest', () {
      expect(() => ExamReferenceManifestRevision.fromRow(manifestRow(
        from: '2027-02-30',
      )), throwsFormatException);
      expect(() => ExamReferenceManifestRevision.fromRow(manifestRow(
        from: '2027-12-31', until: '2027-01-01',
      )), throwsFormatException);
    });
  });
}
