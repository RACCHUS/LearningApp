import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Only fields produced by the owner-invoker RLS projection. This is NOT an
/// examination score and a server-graded response is not observed book use.
class ReferenceDrillEvidence {
  final String id;
  final String ownerId;
  final String manifestId;
  final String attemptId;
  final String itemId;
  final String bindingId;
  final String partKey;
  final String examDate;
  final int itemRevision;
  final int answerRevision;
  final String step;
  final bool responded;
  final int appElapsedMs;
  final int? selfReportedBookMs;
  final DateTime startedAt;
  final DateTime completedAt;
  final DateTime recordedAt;
  final bool? isCorrect;
  final int? scoringVersion;
  final DateTime? gradedAt;

  const ReferenceDrillEvidence({
    required this.id,
    required this.ownerId,
    required this.manifestId,
    required this.attemptId,
    required this.itemId,
    required this.bindingId,
    required this.partKey,
    required this.examDate,
    required this.itemRevision,
    required this.answerRevision,
    required this.step,
    required this.responded,
    required this.appElapsedMs,
    required this.selfReportedBookMs,
    required this.startedAt,
    required this.completedAt,
    required this.recordedAt,
    required this.isCorrect,
    required this.scoringVersion,
    required this.gradedAt,
  });

  static const steps = [
    'resource_choice', 'section_location', 'interpretation', 'application',
  ];

  static ReferenceDrillEvidence fromRow(
    Map<String, dynamic> row, {
    required String ownerId,
    required String manifestId,
  }) {
    // Reject extensions to the server response that might inadvertently
    // include a raw answer, private rubric, or reviewer-only information.
    const fields = {
      'event_id', 'owner_auth_uid', 'client_attempt_id',
      'assessment_item_id', 'approved_binding_id', 'manifest_revision_id',
      'exam_part_key', 'administration_date', 'item_content_revision',
      'answer_location_revision', 'drill_step', 'responded',
      'app_elapsed_ms', 'self_reported_book_ms', 'started_at',
      'completed_at', 'recorded_at', 'verification_state', 'is_correct',
      'scoring_version', 'graded_at',
    };
    if (row.keys.toSet().difference(fields).isNotEmpty ||
        row.length != fields.length ||
        row['owner_auth_uid'] != ownerId ||
        row['manifest_revision_id'] != manifestId ||
        row['verification_state'] != 'unverified' ||
        !steps.contains(row['drill_step']) ||
        row['responded'] is! bool ||
        row['item_content_revision'] is! int ||
        (row['item_content_revision'] as int) < 1 ||
        row['answer_location_revision'] is! int ||
        (row['answer_location_revision'] as int) < 1 ||
        row['app_elapsed_ms'] is! int ||
        (row['app_elapsed_ms'] as int) < 0 ||
        (row['app_elapsed_ms'] as int) > 86400000 ||
        (row['self_reported_book_ms'] != null &&
            (row['self_reported_book_ms'] is! int ||
             (row['self_reported_book_ms'] as int) < 0 ||
             (row['self_reported_book_ms'] as int) > 86400000))) {
      throw const FormatException('Invalid private reference progress record');
    }
    String requiredString(String key) {
      final raw = row[key];
      if (raw is! String || raw.isEmpty) {
        throw const FormatException('Missing reference progress identity');
      }
      return raw;
    }
    DateTime time(String key) =>
        DateTime.tryParse(row[key]?.toString() ?? '')?.toUtc() ??
        (throw const FormatException('Invalid progress timestamp'));

    final correct = row['is_correct'];
    final version = row['scoring_version'];
    final graded = row['graded_at'];
    if (correct != null && correct is! bool) {
      throw const FormatException('Invalid verified correctness');
    }
    if ((correct == null && (version != null || graded != null)) ||
        (correct != null && (! (row['responded'] as bool) ||
            version is! int || version < 1 || graded == null))) {
      throw const FormatException('Untrusted grade state');
    }
    final event = ReferenceDrillEvidence(
      id: requiredString('event_id'),
      ownerId: ownerId,
      manifestId: manifestId,
      attemptId: requiredString('client_attempt_id'),
      itemId: requiredString('assessment_item_id'),
      bindingId: requiredString('approved_binding_id'),
      partKey: requiredString('exam_part_key'),
      examDate: requiredString('administration_date'),
      itemRevision: row['item_content_revision'] as int,
      answerRevision: row['answer_location_revision'] as int,
      step: row['drill_step'] as String,
      responded: row['responded'] as bool,
      appElapsedMs: row['app_elapsed_ms'] as int,
      selfReportedBookMs: row['self_reported_book_ms'] as int?,
      startedAt: time('started_at'),
      completedAt: time('completed_at'),
      recordedAt: time('recorded_at'),
      isCorrect: correct as bool?,
      scoringVersion: version as int?,
      gradedAt: correct == null ? null : time('graded_at'),
    );
    if (event.completedAt.isBefore(event.startedAt)) {
      throw const FormatException('Invalid progress time order');
    }
    return event;
  }

  Map<String, dynamic> toExport() => {
    'event_id': id,
    'client_attempt_id': attemptId,
    'assessment_item_id': itemId,
    'approved_binding_id': bindingId,
    'manifest_revision_id': manifestId,
    'exam_part_key': partKey,
    'administration_date': examDate,
    'item_content_revision': itemRevision,
    'answer_location_revision': answerRevision,
    'drill_step': step,
    'responded': responded,
    'app_elapsed_ms': appElapsedMs,
    'self_reported_book_ms': selfReportedBookMs,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt.toIso8601String(),
    'recorded_at': recordedAt.toIso8601String(),
    'observation_verification': 'unverified',
    'server_graded_correct': isCorrect,
    'scoring_version': scoringVersion,
    'graded_at': gradedAt?.toIso8601String(),
  };
}

class ReferenceDrillSkillProgress {
  final String step;
  final int total;
  final int correct;
  final int incorrect;
  final int awaitingScore;
  final int skipped;

  const ReferenceDrillSkillProgress({
    required this.step,
    required this.total,
    required this.correct,
    required this.incorrect,
    required this.awaitingScore,
    required this.skipped,
  });

  int get graded => correct + incorrect;
}

class ReferenceDrillProgressSnapshot {
  final String ownerId;
  final String manifestId;
  final List<ReferenceDrillEvidence> events;

  ReferenceDrillProgressSnapshot({
    required this.ownerId, required this.manifestId,
    required List<ReferenceDrillEvidence> events,
  }) : events = List.unmodifiable(events);

  List<ReferenceDrillSkillProgress> get skills => [
    for (final step in ReferenceDrillEvidence.steps)
      ReferenceDrillSkillProgress(
        step: step,
        total: events.where((e) => e.step == step).length,
        correct: events.where((e) => e.step == step && e.isCorrect == true).length,
        incorrect: events.where((e) => e.step == step && e.isCorrect == false).length,
        awaitingScore: events.where((e) =>
            e.step == step && e.responded && e.isCorrect == null).length,
        skipped: events.where((e) => e.step == step && !e.responded).length,
      ),
  ];

  /// Complete, explicit edition-scoped JSON export. No keys or answers.
  String toJsonExport({DateTime? generatedAt}) => const JsonEncoder.withIndent('  ')
      .convert({
    'format': 'learningapp-exm-reference-practice-v1',
    'scope': 'one-reference-manifest',
    'owner_auth_uid': ownerId,
    'manifest_revision_id': manifestId,
    'generated_at': (generatedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'complete': true,
    'disclaimer': 'Server grading verifies selected choices only; '
        'observed practice times and physical book use are unverified. '
        'No official score or passing prediction.',
    'steps': [for (final e in events) e.toExport()],
  });
}

/// Owner-RLS reader. Cursor paging avoids silent 100-row truncation; excessive
/// exports fail CLOSED rather than presenting an incomplete JSON as complete.
/// Snapshot consistency across concurrent deletion/inserts is not guaranteed.
class ExamReferenceDrillProgressService {
  final SupabaseClient _client;
  final Future<dynamic> Function(String manifestId, int limit,
      String? beforeTime, String? beforeId)? _testTransport;

  ExamReferenceDrillProgressService({
    SupabaseClient? client,
    Future<dynamic> Function(String manifestId, int limit,
        String? beforeTime, String? beforeId)? testTransport,
  }) : _client = client ?? Supabase.instance.client,
       _testTransport = testTransport;

  void _requireOwner(String owner) {
    final user = _client.auth.currentUser;
    if (owner.isEmpty || user == null || user.isAnonymous || user.id != owner) {
      throw StateError('Reference progress requires the original signed-in owner');
    }
  }

  Future<ReferenceDrillProgressSnapshot> loadComplete({
    required String expectedOwnerId,
    required String manifestRevisionId,
    int maxRecords = 5000,
  }) async {
    _requireOwner(expectedOwnerId);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(manifestRevisionId) || maxRecords < 1 || maxRecords > 5000) {
      throw const FormatException('Invalid progress scope or export bound');
    }
    final all = <ReferenceDrillEvidence>[];
    String? cursorTime, cursorId;
    final seen = <String>{};
    while (true) {
      _requireOwner(expectedOwnerId);
      final limit = (maxRecords + 1 - all.length).clamp(1, 100).toInt();
      final dynamic page = _testTransport != null
          ? await _testTransport(manifestRevisionId, limit,
              cursorTime, cursorId)
          : await _client.rpc('exam_reference_drill_progress_page', params: {
              'p_manifest_revision_id': manifestRevisionId,
              'p_limit': limit,
              'p_before_recorded_at': cursorTime,
              'p_before_event_id': cursorId,
            });
      _requireOwner(expectedOwnerId);
      if (page is! List || page.length > limit) {
        throw const FormatException('Malformed progress page');
      }
      DateTime? previousAt = cursorTime == null
          ? null : DateTime.tryParse(cursorTime);
      String? previousId = cursorId;
      for (final raw in page) {
        if (raw is! Map) {
          throw const FormatException('Malformed progress record');
        }
        final event = ReferenceDrillEvidence.fromRow(
          Map<String, dynamic>.from(raw),
          ownerId: expectedOwnerId,
          manifestId: manifestRevisionId,
        );
        if (!seen.add(event.id)) {
          throw const FormatException('Duplicate progress cursor result');
        }
        if (previousAt != null &&
            (event.recordedAt.isAfter(previousAt) ||
             (event.recordedAt.isAtSameMomentAs(previousAt) &&
              event.id.compareTo(previousId!) >= 0))) {
          throw const FormatException('Out-of-order progress result');
        }
        all.add(event);
        previousAt = event.recordedAt;
        previousId = event.id;
      }
      if (all.length > maxRecords) {
        throw StateError('This edition exceeds the safe export bound; '
            'do not label an incomplete export as complete.');
      }
      if (page.length < limit) break;
      cursorTime = all.last.recordedAt.toIso8601String();
      cursorId = all.last.id;
    }
    _requireOwner(expectedOwnerId);
    return ReferenceDrillProgressSnapshot(
      ownerId: expectedOwnerId, manifestId: manifestRevisionId, events: all,
    );
  }
}

