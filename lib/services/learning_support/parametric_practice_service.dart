import 'package:supabase_flutter/supabase_flutter.dart';

/// A reviewed practice family offered for a concept.
class ParametricFamily {
  const ParametricFamily(this.id, this.title);

  final String id;
  final String title;
}

/// One generated item. It never carries the answer (master plan v2.6 C09,
/// A19: the key stays on the server until the learner has answered).
class ParametricItem {
  const ParametricItem({
    required this.instanceId,
    required this.prompt,
    required this.acceptsPercentSign,
  });

  final String instanceId;
  final String prompt;
  final bool acceptsPercentSign;
}

/// The server's verdict on one answer.
class ParametricResult {
  const ParametricResult({
    required this.readable,
    this.correct,
    this.answer,
    this.firstAttempt = false,
  });

  /// False when the input was not a number; nothing was revealed.
  final bool readable;
  final bool? correct;

  /// The right answer, revealed only after a readable answer.
  final String? answer;
  final bool firstAttempt;
}

class ParametricPracticeException implements Exception {
  ParametricPracticeException(this.code);

  final String code;

  static ParametricPracticeException from(Object e) {
    final text = e is PostgrestException ? e.message : '$e';
    for (final c in const [
      'feature_disabled',
      'authentication_required',
      'family_not_found',
      'item_not_found',
      'rate_limited',
      'no_variant_available',
    ]) {
      if (text.contains(c)) return ParametricPracticeException(c);
    }
    return ParametricPracticeException('unknown');
  }

  String get message => switch (code) {
    'feature_disabled' => 'Extra practice is not available right now.',
    'authentication_required' => 'Sign in to get extra practice.',
    'rate_limited' => "That's a lot of practice today. Try again tomorrow.",
    'no_variant_available' =>
      'No new questions are left for now. Try again later.',
    _ => "Couldn't load practice. Please try again.",
  };

  @override
  String toString() => code;
}

/// Calls the parametric practice RPCs (migration 20261119020000).
/// Generation and scoring happen on the server only.
class ParametricPracticeService {
  ParametricPracticeService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  Future<List<ParametricFamily>> familiesFor(String conceptId) async {
    try {
      final rows =
          await _db.rpc(
                'parametric_families_for',
                params: {'p_concept_id': conceptId},
              )
              as List;
      return [
        for (final r in rows)
          if (r is Map) ParametricFamily('${r['id']}', '${r['title']}'),
      ];
    } catch (_) {
      // Signed out, offline or switched off: no extra practice offered.
      return const [];
    }
  }

  Future<ParametricItem> nextItem(String familyId) async {
    try {
      final rows =
          await _db.rpc(
                'parametric_next_item',
                params: {'p_family_id': familyId},
              )
              as List;
      final r = Map<String, dynamic>.from(rows.single as Map);
      return ParametricItem(
        instanceId: r['instance_id'] as String,
        prompt: r['prompt'] as String,
        acceptsPercentSign: r['accepts_percent_sign'] == true,
      );
    } catch (e) {
      throw ParametricPracticeException.from(e);
    }
  }

  Future<ParametricResult> submit(String instanceId, String answer) async {
    try {
      final rows =
          await _db.rpc(
                'parametric_submit',
                params: {'p_instance_id': instanceId, 'p_answer': answer},
              )
              as List;
      final r = Map<String, dynamic>.from(rows.single as Map);
      return ParametricResult(
        readable: r['readable'] == true,
        correct: r['correct'] as bool?,
        answer: r['answer'] as String?,
        firstAttempt: r['first_attempt'] == true,
      );
    } catch (e) {
      throw ParametricPracticeException.from(e);
    }
  }
}
