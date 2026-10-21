import 'package:supabase_flutter/supabase_flutter.dart';

/// One reviewed-edition R1–R4 evidence count from the owner-only SQL RPC.
/// This NEVER contributes to global knowledge mastery or issuer score.
class ReferenceContextSkillCount {
  final String step;
  final int recorded;
  final int correct;
  final int incorrect;
  final int awaiting;
  final int skipped;
  final DateTime lastRecordedAt;

  const ReferenceContextSkillCount({
    required this.step,
    required this.recorded,
    required this.correct,
    required this.incorrect,
    required this.awaiting,
    required this.skipped,
    required this.lastRecordedAt,
  });

  int get graded => correct + incorrect;
}

class ReferenceContextEdition {
  final String manifestId;
  final String partKey;
  final int revision;
  final Map<String, ReferenceContextSkillCount> steps;

  const ReferenceContextEdition({
    required this.manifestId,
    required this.partKey,
    required this.revision,
    required this.steps,
  });

  int get total => steps.values.fold(0, (sum, s) => sum + s.recorded);
  int get correct => steps.values.fold(0, (sum, s) => sum + s.correct);
  int get incorrect => steps.values.fold(0, (sum, s) => sum + s.incorrect);
  int get awaiting => steps.values.fold(0, (sum, s) => sum + s.awaiting);
  int get skipped => steps.values.fold(0, (sum, s) => sum + s.skipped);
}

class ReferenceContextProgress {
  final String ownerId;
  final String targetVersionId;
  final List<ReferenceContextEdition> editions;

  ReferenceContextProgress({
    required this.ownerId,
    required this.targetVersionId,
    required List<ReferenceContextEdition> editions,
  }) : editions = List.unmodifiable(editions);
}

class ExamReferenceContextProgressService {
  final SupabaseClient _client;
  final Future<dynamic> Function(String targetVersionId)? _testTransport;

  ExamReferenceContextProgressService({
    SupabaseClient? client,
    Future<dynamic> Function(String targetVersionId)? testTransport,
  }) : _client = client ?? Supabase.instance.client,
       _testTransport = testTransport;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static const _steps = {
    'resource_choice','section_location','interpretation','application',
  };

  void _checkOwner(String ownerId) {
    final user = _client.auth.currentUser;
    if (ownerId.isEmpty || user == null || user.isAnonymous ||
        user.id != ownerId) {
      throw StateError('Reference Progress belongs to another account');
    }
  }

  /// Immutable receipt constructed only from owner-scoped saved events and
  /// server-owned grades. The RPC filters current published review manifests;
  /// historical retired editions require an explicit later policy review.
  Future<ReferenceContextProgress> load({
    required String expectedOwnerId,
    required String targetVersionId,
  }) async {
    _checkOwner(expectedOwnerId);
    if (!_uuid.hasMatch(targetVersionId)) {
      throw const FormatException('Invalid exact target-version identifier');
    }
    final dynamic raw = _testTransport != null
        ? await _testTransport(targetVersionId)
        : await _client.rpc(
            'exam_reference_drill_context_progress',
            params: {'p_target_version_id': targetVersionId},
          );
    _checkOwner(expectedOwnerId);
    if (raw is! List || raw.length > 100) {
      throw const FormatException('Invalid reference summary size');
    }
    final grouped = <String, Map<String, ReferenceContextSkillCount>>{};
    final metadata = <String, (String, int)>{};
    const expectedFields = {
      'target_version_id','manifest_revision_id','exam_part_key',
      'manifest_revision','drill_step','recorded_steps','graded_correct',
      'graded_incorrect','awaiting_grade','skipped_steps','last_recorded_at',
    };

    for (final rawRow in raw) {
      if (rawRow is! Map) {
        throw const FormatException('Malformed private summary row');
      }
      final row = Map<String, dynamic>.from(rawRow);
      final manifest = row['manifest_revision_id'];
      final part = row['exam_part_key'];
      final revision = row['manifest_revision'];
      final step = row['drill_step'];
      final timestamp = DateTime.tryParse(
        row['last_recorded_at']?.toString() ?? '',
      )?.toUtc();
      if (row.length != expectedFields.length ||
          row.keys.toSet().difference(expectedFields).isNotEmpty ||
          row['target_version_id'] != targetVersionId ||
          manifest is! String || !_uuid.hasMatch(manifest) ||
          part is! String ||
          !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(part) ||
          revision is! int || revision < 1 ||
          step is! String || !_steps.contains(step) ||
          timestamp == null) {
        throw const FormatException('Mismatched private summary identity');
      }
      int count(String field) {
        final value = row[field];
        if (value is! int || value < 0 || value > 1000000) {
          throw const FormatException('Invalid server-verified count');
        }
        return value;
      }
      final recorded = count('recorded_steps');
      final correct = count('graded_correct');
      final incorrect = count('graded_incorrect');
      final awaiting = count('awaiting_grade');
      final skipped = count('skipped_steps');
      if (recorded == 0 ||
          correct + incorrect + awaiting + skipped != recorded) {
        throw const FormatException('Inconsistent grading evidence');
      }
      if (metadata[manifest] case final prior?) {
        if (prior.$1 != part || prior.$2 != revision) {
          throw const FormatException('Conflicting reference edition metadata');
        }
      } else {
        metadata[manifest] = (part, revision);
      }
      final steps = grouped.putIfAbsent(manifest, () => {});
      if (steps.containsKey(step)) {
        throw const FormatException('Duplicated reference skill summary');
      }
      steps[step] = ReferenceContextSkillCount(
        step: step,
        recorded: recorded,
        correct: correct,
        incorrect: incorrect,
        awaiting: awaiting,
        skipped: skipped,
        lastRecordedAt: timestamp,
      );
    }
    _checkOwner(expectedOwnerId);
    return ReferenceContextProgress(
      ownerId: expectedOwnerId,
      targetVersionId: targetVersionId,
      editions: [
        for (final entry in grouped.entries)
          ReferenceContextEdition(
            manifestId: entry.key,
            partKey: metadata[entry.key]!.$1,
            revision: metadata[entry.key]!.$2,
            steps: Map.unmodifiable(entry.value),
          ),
      ],
    );
  }
}
