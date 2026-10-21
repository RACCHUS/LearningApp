import 'package:supabase_flutter/supabase_flutter.dart';

/// EXM-02B: secure storage of *ungraded* R1–R4 practice observations.
///
/// Supabase Auth anonymous guest sessions have authenticated DB role but are
/// deliberately not eligible for durable server history. No private answer
/// keys, learner free-text, or claimed mastery scores are persisted here.
class ExamReferenceDrillEventService {
  final SupabaseClient _client;

  ExamReferenceDrillEventService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  User _permanentUser({String? expectedUserId}) {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError(
        'Durable reference practice requires a signed-in non-guest account.',
      );
    }
    if (expectedUserId != null && user.id != expectedUserId) {
      throw StateError('Reference practice owner changed during this request.');
    }
    return user;
  }

  /// Client-submitted timing/response *observations*, not graded evidence.
  Future<Map<String, dynamic>> recordStep({
    required String clientAttemptId,
    required String assessmentItemId,
    required String approvedBindingId,
    required String manifestRevisionId,
    required String examPartKey,
    required DateTime administrationDate,
    required int itemContentRevision,
    required int answerLocationRevision,
    required String step,
    required bool responded,
    required Duration appElapsed,
    required DateTime startedAt,
    required DateTime completedAt,
    Duration? selfReportedBookTime,
  }) async {
    final user = _permanentUser();
    if (!const {
      'resource_choice', 'section_location', 'interpretation', 'application',
    }.contains(step)) {
      throw ArgumentError.value(step, 'step', 'Unsupported reference drill step');
    }
    if (itemContentRevision <= 0 || answerLocationRevision <= 0 ||
        appElapsed.isNegative ||
        appElapsed.inMilliseconds > 86400000 ||
        (selfReportedBookTime?.isNegative ?? false) ||
        (selfReportedBookTime?.inMilliseconds ?? 0) > 86400000 ||
        completedAt.isBefore(startedAt)) {
      throw ArgumentError('Invalid reference drill revision or duration');
    }
    final payload = <String, dynamic>{
      'owner_auth_uid': user.id,
      'client_attempt_id': clientAttemptId,
      'assessment_item_id': assessmentItemId,
      'approved_binding_id': approvedBindingId,
      'manifest_revision_id': manifestRevisionId,
      'exam_part_key': examPartKey,
      'administration_date':
          administrationDate.toIso8601String().substring(0, 10),
      'item_content_revision': itemContentRevision,
      'answer_location_revision': answerLocationRevision,
      'drill_step': step,
      'responded': responded,
      'app_elapsed_ms': appElapsed.inMilliseconds,
      'self_reported_book_ms': selfReportedBookTime?.inMilliseconds,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt.toUtc().toIso8601String(),
      // Deliberately no correctness/pass score, free-response or answer keys.
    };
    try {
      final response = await _client
          .from('exam_reference_drill_events')
          .insert(payload)
          .select()
          .single();
      _permanentUser(expectedUserId: user.id);
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // A network retry of the same event must be safe without giving clients
      // UPDATE/upsert privileges. We must also detect replayed conflicting data.
      final existing = await _client
          .from('exam_reference_drill_events')
          .select()
          .eq('owner_auth_uid', user.id)
          .eq('client_attempt_id', clientAttemptId)
          .eq('drill_step', step)
          .maybeSingle();
      _permanentUser(expectedUserId: user.id);
      if (existing == null) rethrow;
      for (final entry in payload.entries) {
        if (entry.value != existing[entry.key]) {
          throw StateError(
            'This attempt step already exists with different observations.',
          );
        }
      }
      return Map<String, dynamic>.from(existing);
    }
  }

  /// Query is scoped to the current permanent account, with a post-await
  /// identity check so a response from account A cannot populate account B.
  Future<List<Map<String, dynamic>>> listMyEvents({
    int limit = 100,
    String? manifestRevisionId,
    String? expectedOwnerId,
  }) async {
    final user = _permanentUser(expectedUserId: expectedOwnerId);
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    if (manifestRevisionId != null && manifestRevisionId.trim().isEmpty) {
      throw ArgumentError.value(manifestRevisionId, 'manifestRevisionId');
    }
    var query = _client
        .from('exam_reference_drill_events')
        .select()
        .eq('owner_auth_uid', user.id);
    if (manifestRevisionId != null) {
      query = query.eq('manifest_revision_id', manifestRevisionId);
    }
    final rows = await query
        .order('recorded_at', ascending: false)
        .limit(limit);
    _permanentUser(expectedUserId: user.id);
    // Defense in depth: never return foreign rows even if a mock, server or
    // mistakenly altered query returns broader data than requested.
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) =>
            row['owner_auth_uid'] == user.id &&
            (manifestRevisionId == null ||
                row['manifest_revision_id'] == manifestRevisionId))
        .toList();
  }

  /// Explicit user-directed removal; require the same account that opened
  /// the confirmation and limit deletion to the selected manifest.
  Future<void> deleteMyAttempt(
    String clientAttemptId, {
    String? manifestRevisionId,
    String? expectedOwnerId,
  }) async {
    final user = _permanentUser(expectedUserId: expectedOwnerId);
    if (clientAttemptId.trim().isEmpty ||
        (manifestRevisionId != null && manifestRevisionId.trim().isEmpty)) {
      throw ArgumentError('Attempt and manifest identities must not be empty');
    }
    var query = _client
        .from('exam_reference_drill_events')
        .delete()
        .eq('owner_auth_uid', user.id)
        .eq('client_attempt_id', clientAttemptId);
    if (manifestRevisionId != null) {
      query = query.eq('manifest_revision_id', manifestRevisionId);
    }
    await query;
    _permanentUser(expectedUserId: user.id);
  }
}
