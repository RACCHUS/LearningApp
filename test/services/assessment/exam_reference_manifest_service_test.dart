import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/assessment_engine/exam_reference_manifest.dart';
import 'package:learning_pwa/services/assessment/exam_reference_manifest_service.dart';

import '../../test_helpers/fake_supabase_client.dart';

class _BrokenSupabaseClient extends FakeSupabaseClient {
  @override
  SupabaseQueryBuilder from(String table) => throw StateError('Network unavailable');
}

void main() {
  final profile = ExamPreparationProfile.fromTargetVersionMetadata(
    targetVersionId: 'version-1',
    metadata: {
      'exam_preparation': {
        'schema_version': 1,
        'exam_parts': [
          {
            'key': 'project_management',
            'display_name': 'Project Management',
            'curriculum_root_node_id': 'node-pm',
          },
        ],
      },
    },
  )!;

  Map<String, dynamic> row({
    String id = 'manifest-2027',
    String version = 'version-1',
    String part = 'project_management',
    String status = 'published',
    String from = '2027-01-01',
    String until = '2027-12-31',
    int revision = 1,
    String review = 'approved',
  }) => {
        'id': id,
        'target_version_id': version,
        'exam_part_key': part,
        'revision': revision,
        'effective_from': from,
        'effective_until': until,
        'source_release_id': 'source-release-1',
        'official_source_url': 'https://example.gov/official.pdf',
        'source_checked_at': '2026-10-18T18:00:00Z',
        'reviewed_at': '2026-10-18T19:00:00Z',
        'reviewer_ref': 'qualified-reviewer',
        'review_status': review,
        'publication_status': status,
        'reference_entries': [
          {'key': 'book_one', 'edition': '2027', 'source_page': '1'}
        ],
        'room_rules': [
          {'name': 'tabs', 'state': 'unknown', 'value': null}
        ],
      };

  group('EXM-01 public reference lookup', () {
    test('Selects only matching part and actual administration date', () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('exam_reference_manifest_revisions', [
        row(id: 'old', from: '2026-01-01', until: '2026-12-31'),
        row(),
        row(id: 'other-part', part: 'business_finance'),
        row(id: 'other-target', version: 'version-other'),
      ]);
      final result = await ExamReferenceManifestService(supabase: fake)
          .resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 5, 5),
      );
      expect(result.status, ExamManifestSelectionStatus.selected);
      expect(result.revision?.id, 'manifest-2027');
    });

    test('Does not show 2027 books for a learner testing in 2026', () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('exam_reference_manifest_revisions', [row()]);
      final result = await ExamReferenceManifestService(supabase: fake)
          .resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2026, 12, 31),
      );
      expect(result.status, ExamManifestSelectionStatus.noApplicableRevision);
    });

    test('Missing exam date fails before reaching Supabase', () async {
      final result = await ExamReferenceManifestService(
        supabase: _BrokenSupabaseClient(),
      ).resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: null,
      );
      expect(result.status, ExamManifestSelectionStatus.unknownExamDate);
    });

    test('Conflicting effective revisions fail closed', () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('exam_reference_manifest_revisions', [
        row(),
        row(id: 'overlap', revision: 2, from: '2027-07-01'),
      ]);
      final result = await ExamReferenceManifestService(supabase: fake)
          .resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 8, 1),
      );
      expect(result.status, ExamManifestSelectionStatus.conflictingRevisions);
      expect(result.revision, isNull);
    });

    test('Unreviewed published row is not silently skipped in favor of another', () async {
      final fake = FakeSupabaseClient();
      fake.setTableData('exam_reference_manifest_revisions', [
        row(),
        row(id: 'unreviewed', revision: 2, review: 'pending'),
      ]);
      final result = await ExamReferenceManifestService(supabase: fake)
          .resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 8, 1),
      );
      expect(result.status, ExamManifestSelectionStatus.unavailableSource);
      expect(result.revision, isNull);
    });

    test('Network/RLS exceptions return unavailable, never no-applicable', () async {
      final result = await ExamReferenceManifestService(
        supabase: _BrokenSupabaseClient(),
      ).resolveForExamDate(
        profile: profile,
        examPartKey: 'project_management',
        administrationDate: DateTime.utc(2027, 8, 1),
      );
      expect(result.status, ExamManifestSelectionStatus.unavailableSource);
      expect(result.revision, isNull);
    });
  });
}
