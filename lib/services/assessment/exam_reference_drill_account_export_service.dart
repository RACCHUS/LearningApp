import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'exam_reference_drill_progress_service.dart';

/// All saved EXM reference-practice data for one permanent account.
/// Includes historical/retired editions as SAVED EVIDENCE only; never imply
/// those editions are eligible for current or upcoming examinations.
class ReferencePracticeAccountExport {
  final String ownerId;
  final DateTime generatedAt;
  final String snapshotConsistency;
  final List<ReferenceDrillEvidence> events;

  ReferencePracticeAccountExport({
    required this.ownerId,
    required this.generatedAt,
    this.snapshotConsistency = 'single-sql-statement',
    required List<ReferenceDrillEvidence> events,
  }) : events = List.unmodifiable(events);

  int get manifestCount =>
      events.map((e) => e.manifestId).toSet().length;
  int get gradedCorrect =>
      events.where((e) => e.isCorrect == true).length;
  int get gradedIncorrect =>
      events.where((e) => e.isCorrect == false).length;
  int get awaiting =>
      events.where((e) => e.responded && e.isCorrect == null).length;
  int get skipped =>
      events.where((e) => !e.responded).length;

  /// Explicitly labelled as an EXM subsystem export, NOT all app data.
  String toJsonExport() => const JsonEncoder.withIndent('  ').convert({
    'format': 'learningapp-exm-reference-practice-account-v1',
    'scope': 'reference-practice-all-editions',
    'owner_auth_uid': ownerId,
    'generated_at': generatedAt.toIso8601String(),
    'record_count': events.length,
    'snapshot_consistency': snapshotConsistency,
    'complete_within_limit': true,
    'disclaimer': 'Only saved EXM reference-practice step data is included. '
        'This is not a whole LearningApp account archive. '
        'Older editions are historical evidence, not current book lists. '
        'Times and physical reference use are not independently verified. '
        'Graded selections do not predict an official passing score.',
    'steps': [for (final event in events) event.toExport()],
  });
}

class ExamReferenceDrillAccountExportService {
  final SupabaseClient _client;
  final Future<dynamic> Function(int maximumRecords)? _testTransport;

  ExamReferenceDrillAccountExportService({
    SupabaseClient? client,
    Future<dynamic> Function(int maximumRecords)? testTransport,
  })  : _client = client ?? Supabase.instance.client,
        _testTransport = testTransport;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  void _checkOwner(String ownerId) {
    final user = _client.auth.currentUser;
    if (ownerId.isEmpty || user == null || user.isAnonymous ||
        user.id != ownerId) {
      throw StateError('Reference export belongs to another account');
    }
  }

  /// Downloads a one-SQL-statement RLS-filtered export. Never retries from a
  /// different owner or labels a truncated set complete.
  Future<ReferencePracticeAccountExport> load({
    required String expectedOwnerId,
    int maxRecords = 5000,
  }) async {
    _checkOwner(expectedOwnerId);
    if (maxRecords < 1 || maxRecords > 5000) {
      throw const FormatException('Invalid export record bound');
    }
    final dynamic raw = _testTransport != null
        ? await _testTransport(maxRecords)
        : await _client.rpc(
            'exam_reference_drill_account_export',
            params: {'p_max_records': maxRecords},
          );
    _checkOwner(expectedOwnerId);
    if (raw is! Map) {
      throw const FormatException('Invalid private export envelope');
    }
    const fields = {
      'format','scope','owner_auth_uid','generated_at',
      'record_count','snapshot_consistency','steps',
    };
    final data = Map<String, dynamic>.from(raw);
    final count = data['record_count'];
    final generated = DateTime.tryParse(
      data['generated_at']?.toString() ?? '',
    )?.toUtc();
    final rows = data['steps'];
    if (data.keys.toSet().difference(fields).isNotEmpty ||
        data.length != fields.length ||
        data['format'] != 'learningapp-exm-reference-practice-account-v1' ||
        data['scope'] != 'reference-practice-all-editions' ||
        data['snapshot_consistency'] != 'single-sql-statement' ||
        data['owner_auth_uid'] != expectedOwnerId ||
        generated == null ||
        count is! int || count < 0 || count > maxRecords ||
        rows is! List || rows.length != count) {
      throw const FormatException('Untrusted private export metadata');
    }

    final seen = <String>{};
    final events = <ReferenceDrillEvidence>[];
    DateTime? prevTime;
    String? prevId;
    for (final item in rows) {
      if (item is! Map) {
        throw const FormatException('Malformed private export event');
      }
      final row = Map<String, dynamic>.from(item);
      final manifest = row['manifest_revision_id'];
      if (manifest is! String || !_uuid.hasMatch(manifest)) {
        throw const FormatException('Invalid historical reference revision');
      }
      final event = ReferenceDrillEvidence.fromRow(
        row, ownerId: expectedOwnerId, manifestId: manifest,
      );
      if (!_uuid.hasMatch(event.id) || !seen.add(event.id)) {
        throw const FormatException('Duplicate or malformed event');
      }
      if (prevTime != null &&
          (event.recordedAt.isAfter(prevTime) ||
           (event.recordedAt.isAtSameMomentAs(prevTime) &&
            event.id.compareTo(prevId!) >= 0))) {
        throw const FormatException('Out-of-order reference export');
      }
      events.add(event);
      prevTime = event.recordedAt;
      prevId = event.id;
    }
    _checkOwner(expectedOwnerId);
    return ReferencePracticeAccountExport(
      ownerId: expectedOwnerId,
      generatedAt: generated,
      events: events,
    );
  }
}
