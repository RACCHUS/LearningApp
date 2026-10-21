import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/assessment/exam_part_practice_attempt.dart';

/// Owner-private read/export/erasure foundation. The new table explicitly
/// denies direct client INSERT, so no unverified local grade can create
/// persistent history until a canonical server transaction is reviewed.
class ExamPartPracticeHistoryService {
  final SupabaseClient _client;

  ExamPartPracticeHistoryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  void _requireOwner(String expectedOwnerId) {
    final current = _client.auth.currentUser;
    if (current == null || current.isAnonymous ||
        current.id != expectedOwnerId) {
      throw StateError('A matching permanent account is required.');
    }
  }

  Future<List<ExamPartPracticeAttempt>> readPart({
    required String expectedOwnerId,
    required String targetVersionId,
    required String examPartKey,
    int limit = 100,
  }) async {
    _requireOwner(expectedOwnerId);
    if (targetVersionId.isEmpty ||
        examPartKey.isEmpty ||
        limit < 1 || limit > 500) {
      throw ArgumentError('Exact version, part and bounded page required.');
    }
    final rows = await _client.from('exam_part_practice_attempts')
        .select()
        .eq('owner_id', expectedOwnerId)
        .eq('target_version_id', targetVersionId)
        .eq('exam_part_key', examPartKey)
        .order('completed_at', ascending: false)
        .limit(limit);
    _requireOwner(expectedOwnerId);
    final result = (rows as List).map((row) =>
        ExamPartPracticeAttempt.fromRow(
          Map<String, dynamic>.from(row as Map),
          expectedOwnerId: expectedOwnerId,
          targetVersionId: targetVersionId,
          examPartKey: examPartKey,
        )).toList(growable: false);
    return result;
  }

  /// An explicitly bounded part export, not a complete account export.
  /// The limit is intentionally visible to callers; truncated results
  /// must never be advertised as exhaustive.
  Future<String> exportPartJson({
    required String expectedOwnerId,
    required String targetVersionId,
    required String examPartKey,
    int limit = 100,
  }) async {
    final rows = await readPart(
      expectedOwnerId: expectedOwnerId,
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      limit: limit,
    );
    _requireOwner(expectedOwnerId);
    return jsonEncode({
      'schema': 'exm03-part-attempt-summary-v1',
      'owner_id': expectedOwnerId,
      'target_version_id': targetVersionId,
      'exam_part_key': examPartKey,
      'page_limit': limit,
      'possibly_truncated': rows.length == limit,
      'official_exam_result': false,
      'attempts': rows.map((a) => a.toPrivateExport()).toList(),
    });
  }

  /// Owner-initiated exact-part erasure. Never use an unconstrained account
  /// delete or accept a caller's claim that a stored event belongs to them.
  /// This will be UI-enabled only after the user-confirmation contract lands.
  Future<void> erasePart({
    required String expectedOwnerId,
    required String targetVersionId,
    required String examPartKey,
  }) async {
    _requireOwner(expectedOwnerId);
    if (targetVersionId.isEmpty || examPartKey.isEmpty) {
      throw ArgumentError('Exact target version and part required for erasure.');
    }
    await _client.from('exam_part_practice_attempts')
        .delete()
        .eq('owner_id', expectedOwnerId)
        .eq('target_version_id', targetVersionId)
        .eq('exam_part_key', examPartKey);
    _requireOwner(expectedOwnerId);
  }
}
