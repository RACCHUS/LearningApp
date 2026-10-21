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

  User _permanentUser() {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError(
        'Durable reference practice requires a signed-in non-guest account.',
      );
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

  /// Each query is independently owner-scoped. No shared cross-account cache.
  Future<List<Map<String, dynamic>>> listMyEvents({
    int limit = 100,
  }) async {
    final user = _permanentUser();
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final rows = await _client
        .from('exam_reference_drill_events')
        .select()
        .eq('owner_auth_uid', user.id)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  /// User-requested deletion, distinct from ordinary append-only recording.
  Future<void> deleteMyAttempt(String clientAttemptId) async {
    final user = _permanentUser();
    await _client
        .from('exam_reference_drill_events')
        .delete()
        .eq('owner_auth_uid', user.id)
        .eq('client_attempt_id', clientAttemptId);
  }
}
