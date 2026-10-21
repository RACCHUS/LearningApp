import 'package:supabase_flutter/supabase_flutter.dart';

/// EXM-03: owner-only read projection over the EXISTING R1-R4 durable events.
/// Four saved steps are not an exam score, proof of using a physical reference
/// book, or a verified diagnostic/mock exam attempt.
class SavedPartReferenceAttempt {
  final String id;
  final String manifestId;
  final int manifestRevision;
  final String partKey;
  final String examDate;
  final int recordedSteps;
  final int correct;
  final int incorrect;
  final int awaiting;
  final int skipped;
  final DateTime firstRecordedAt;
  final DateTime lastRecordedAt;
  final bool completedFourSteps;

  const SavedPartReferenceAttempt({
    required this.id,
    required this.manifestId,
    required this.manifestRevision,
    required this.partKey,
    required this.examDate,
    required this.recordedSteps,
    required this.correct,
    required this.incorrect,
    required this.awaiting,
    required this.skipped,
    required this.firstRecordedAt,
    required this.lastRecordedAt,
    required this.completedFourSteps,
  });

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static SavedPartReferenceAttempt fromRow(
    Map<String, dynamic> row, {
    required String ownerId,
    required String targetVersionId,
    required String examPartKey,
  }) {
    const fields = {
      'owner_auth_uid', 'target_version_id', 'exam_part_key',
      'client_attempt_id', 'manifest_revision_id', 'manifest_revision',
      'assessment_item_id', 'approved_binding_id', 'administration_date',
      'recorded_steps', 'graded_correct', 'graded_incorrect',
      'awaiting_grade', 'skipped_steps', 'first_recorded_at',
      'last_recorded_at', 'completed_four_steps',
    };
    if (row.length != fields.length ||
        row.keys.toSet().difference(fields).isNotEmpty ||
        row['owner_auth_uid'] != ownerId ||
        row['target_version_id'] != targetVersionId ||
        row['exam_part_key'] != examPartKey ||
        row['completed_four_steps'] is! bool) {
      throw const FormatException('Invalid private exam-part history identity');
    }
    String uuid(String key) {
      final value = row[key];
      if (value is! String || !_uuid.hasMatch(value)) {
        throw const FormatException('Invalid saved reference attempt ID');
      }
      return value;
    }
    int number(String key) {
      final value = row[key];
      if (value is! int || value < 0 || value > 1000000) {
        throw const FormatException('Invalid saved reference attempt count');
      }
      return value;
    }
    DateTime time(String key) {
      final value = row[key];
      if (value is! String) {
        throw const FormatException('Invalid saved reference timestamp');
      }
      return DateTime.tryParse(value)?.toUtc() ??
          (throw const FormatException('Invalid saved reference timestamp'));
    }
    final id = uuid('client_attempt_id');
    final manifestId = uuid('manifest_revision_id');
    uuid('assessment_item_id');
    uuid('approved_binding_id');
    final rev = number('manifest_revision');
    final recorded = number('recorded_steps');
    final correct = number('graded_correct');
    final incorrect = number('graded_incorrect');
    final awaiting = number('awaiting_grade');
    final skipped = number('skipped_steps');
    final completed = row['completed_four_steps'] as bool;
    final date = row['administration_date'];
    if (rev < 1 || recorded < 1 || recorded > 4 ||
        correct + incorrect + awaiting + skipped != recorded ||
        completed != (recorded == 4) ||
        date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        DateTime.tryParse(date) == null) {
      throw const FormatException('Inconsistent reference attempt history');
    }
    final first = time('first_recorded_at');
    final last = time('last_recorded_at');
    if (last.isBefore(first)) {
      throw const FormatException('Invalid saved reference attempt time');
    }
    return SavedPartReferenceAttempt(
      id: id, manifestId: manifestId, manifestRevision: rev,
      partKey: examPartKey, examDate: date, recordedSteps: recorded,
      correct: correct, incorrect: incorrect, awaiting: awaiting,
      skipped: skipped, firstRecordedAt: first, lastRecordedAt: last,
      completedFourSteps: completed,
    );
  }
}

class SavedPartReferenceAttemptPage {
  final String ownerId;
  final String targetVersionId;
  final String partKey;
  final List<SavedPartReferenceAttempt> attempts;
  final int pageLimit;

  SavedPartReferenceAttemptPage({
    required this.ownerId,
    required this.targetVersionId,
    required this.partKey,
    required List<SavedPartReferenceAttempt> attempts,
    required this.pageLimit,
  }) : attempts = List.unmodifiable(attempts);

  int get completed => attempts.where((a) => a.completedFourSteps).length;
  int get incomplete => attempts.length - completed;

  /// Whether a continuation *could* exist, not a verified total count.
  bool get mightHaveMore => attempts.length == pageLimit;
}

/// Uses permanent Supabase Auth identity before AND after network awaits.
/// No client-provided owner parameter is forwarded to the RPC.
class ExamPartReferenceAttemptHistoryService {
  final SupabaseClient _client;
  final Future<dynamic> Function(
    String version, String part, int limit, String? beforeAt,
    String? beforeAttemptId,
  )? _testTransport;

  ExamPartReferenceAttemptHistoryService({
    SupabaseClient? client,
    Future<dynamic> Function(
      String version, String part, int limit, String? beforeAt,
      String? beforeAttemptId,
    )? testTransport,
  }) : _client = client ?? Supabase.instance.client,
       _testTransport = testTransport;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void _requireOwner(String owner) {
    final user = _client.auth.currentUser;
    if (owner.isEmpty || user == null || user.isAnonymous || user.id != owner) {
      throw StateError('Saved exam-part history requires its permanent owner.');
    }
  }

  Future<SavedPartReferenceAttemptPage> load({
    required String expectedOwnerId,
    required String targetVersionId,
    required String examPartKey,
    int limit = 20,
    DateTime? beforeAt,
    String? beforeAttemptId,
  }) async {
    _requireOwner(expectedOwnerId);
    if (!_uuid.hasMatch(targetVersionId) ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(examPartKey) ||
        examPartKey.length > 128 || limit < 1 || limit > 50 ||
        (beforeAt == null) != (beforeAttemptId == null) ||
        (beforeAttemptId != null && !_uuid.hasMatch(beforeAttemptId))) {
      throw const FormatException('Invalid exact exam part history request');
    }

    final raw = _testTransport != null
        ? await _testTransport(
            targetVersionId, examPartKey, limit,
            beforeAt?.toUtc().toIso8601String(), beforeAttemptId,
          )
        : await _client.rpc(
            'exam_reference_drill_part_attempt_history',
            params: {
              'p_target_version_id': targetVersionId,
              'p_exam_part_key': examPartKey,
              'p_limit': limit,
              'p_before_last_at': beforeAt?.toUtc().toIso8601String(),
              'p_before_attempt_id': beforeAttemptId,
            },
          );
    _requireOwner(expectedOwnerId);
    if (raw is! List || raw.length > limit) {
      throw const FormatException('Invalid bounded reference history response');
    }
    final rows = <SavedPartReferenceAttempt>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Malformed reference attempt');
      }
      final row = SavedPartReferenceAttempt.fromRow(
        Map<String, dynamic>.from(item),
        ownerId: expectedOwnerId,
        targetVersionId: targetVersionId,
        examPartKey: examPartKey,
      );
      if (!seen.add(row.id) ||
          (rows.isNotEmpty &&
           (row.lastRecordedAt.isAfter(rows.last.lastRecordedAt) ||
            (row.lastRecordedAt.isAtSameMomentAs(rows.last.lastRecordedAt) &&
             row.id.compareTo(rows.last.id) >= 0))) ||
          (beforeAt != null &&
           (row.lastRecordedAt.isAfter(beforeAt) ||
            (row.lastRecordedAt.isAtSameMomentAs(beforeAt) &&
             row.id.compareTo(beforeAttemptId!) >= 0)))) {
        throw const FormatException('Untrusted or unsorted attempt cursor');
      }
      rows.add(row);
    }
    _requireOwner(expectedOwnerId);
    return SavedPartReferenceAttemptPage(
      ownerId: expectedOwnerId, targetVersionId: targetVersionId,
      partKey: examPartKey, attempts: rows, pageLimit: limit,
    );
  }
}
