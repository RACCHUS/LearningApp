import 'package:supabase_flutter/supabase_flutter.dart';

/// A server-graded token result. Correctness means the submitted token
/// matched an independently reviewed private key, not that the learner
/// physically opened a book or will pass an issuer exam.
class VerifiedReferenceDrillStepScore {
  final String step;
  final bool isCorrect;
  final int scoringVersion;
  final DateTime gradedAt;

  const VerifiedReferenceDrillStepScore({
    required this.step,
    required this.isCorrect,
    required this.scoringVersion,
    required this.gradedAt,
  });
}

/// EXM-02B: calls the private-key RPC for an already stored ungraded event.
///
/// No keys or response text are saved locally. The original permanent user
/// is checked before and after the async request, so a stale account A result
/// cannot populate account B's screen. The database remains the only scoring
/// authority; the injectable transport exists exclusively for focused tests.
class ExamReferenceDrillScoringService {
  final SupabaseClient _client;
  final Future<dynamic> Function(String eventId, String token)? _testTransport;

  ExamReferenceDrillScoringService({
    SupabaseClient? client,
    Future<dynamic> Function(String eventId, String token)? testTransport,
  })  : _client = client ?? Supabase.instance.client,
        _testTransport = testTransport;

  void _requirePermanentOwner(String expectedOwnerId) {
    final current = _client.auth.currentUser;
    if (expectedOwnerId.trim().isEmpty ||
        current == null ||
        current.isAnonymous ||
        current.id != expectedOwnerId) {
      throw StateError('Reference scoring requires the original signed-in owner.');
    }
  }

  Future<VerifiedReferenceDrillStepScore> scoreRecordedStep({
    required String expectedOwnerId,
    required String eventId,
    required String answerToken,
  }) async {
    _requirePermanentOwner(expectedOwnerId);
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(eventId)) {
      throw ArgumentError.value(eventId, 'eventId', 'Expected an event UUID');
    }
    final normalized = answerToken.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.length > 80 ||
        !RegExp(r'^[a-z0-9][a-z0-9 _./:-]*$').hasMatch(normalized)) {
      throw ArgumentError.value(
        answerToken,
        'answerToken',
        'Invalid reviewed response token',
      );
    }

    final dynamic result = _testTransport != null
        ? await _testTransport(eventId, normalized)
        : await _client.rpc(
            'score_exam_reference_drill_step',
            params: {'p_event_id': eventId, 'p_answer': normalized},
          );

    _requirePermanentOwner(expectedOwnerId);
    if (result is! List || result.length != 1 || result.first is! Map) {
      throw const FormatException('Malformed trusted grading response');
    }
    final row = Map<String, dynamic>.from(result.single as Map);
    final step = row['drill_step'];
    final correct = row['is_correct'];
    final version = row['scoring_version'];
    final at = DateTime.tryParse(row['graded_at']?.toString() ?? '');
    if (step is! String ||
        !const {
          'resource_choice',
          'section_location',
          'interpretation',
          'application',
        }.contains(step) ||
        correct is! bool ||
        version is! int ||
        version < 1 ||
        at == null) {
      throw const FormatException('Malformed trusted grading fields');
    }
    return VerifiedReferenceDrillStepScore(
      step: step,
      isCorrect: correct,
      scoringVersion: version,
      gradedAt: at,
    );
  }
}
