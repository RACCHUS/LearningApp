import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_engine/exam_reference_manifest.dart';

/// Retrieves only approved, public reference-manifest metadata through RLS.
///
/// An exam date, part key, and valid part-root candidate are mandatory.
/// Missing and corrupt source data are distinct unknown states; callers must
/// never fall back to the newest revision or use the study date instead.
class ExamReferenceManifestService {
  final SupabaseClient _supabase;
  final ExamReferenceManifestResolver _resolver;

  ExamReferenceManifestService({
    SupabaseClient? supabase,
    ExamReferenceManifestResolver resolver =
        const ExamReferenceManifestResolver(),
  })  : _supabase = supabase ?? Supabase.instance.client,
        _resolver = resolver;

  Future<ExamManifestSelection> resolveForExamDate({
    required ExamPreparationProfile profile,
    required String examPartKey,
    required DateTime? administrationDate,
  }) async {
    // Fail before an API call when the request cannot identify a real exam
    // part, its proposed scope root, and an examination administration date.
    final preliminary = _resolver.select(
      profile: profile,
      examPartKey: examPartKey,
      administrationDate: administrationDate,
      revisions: const [],
    );
    if (preliminary.status != ExamManifestSelectionStatus.noApplicableRevision) {
      return preliminary;
    }

    try {
      final response = await _supabase
          .from('exam_reference_manifest_revisions')
          .select(
            'id,target_version_id,exam_part_key,revision,effective_from,'
            'effective_until,source_release_id,official_source_url,'
            'source_checked_at,reviewer_ref,reviewed_at,review_status,'
            'publication_status,reference_entries,room_rules',
          )
          .eq('target_version_id', profile.targetVersionId)
          .eq('exam_part_key', examPartKey)
          .eq('publication_status', 'published');

      final revisions = (response as List)
          .map((row) => ExamReferenceManifestRevision.fromRow(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();

      return _resolver.select(
        profile: profile,
        examPartKey: examPartKey,
        administrationDate: administrationDate,
        revisions: revisions,
      );
    } catch (_) {
      // A network/RLS/parse failure is *not* evidence that no official list
      // exists. Withhold all list-specific claims and allow generic study.
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.unavailableSource,
      );
    }
  }
}
