import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assessment_item.dart';

/// Raised when the server cannot grade a response (offline, item hidden,
/// protected, or unsupported). Callers must surface this rather than guess.
class AssessmentGradingException implements Exception {
  final String message;
  const AssessmentGradingException(this.message);

  @override
  String toString() => message;
}

/// Server-side grading for assessment items whose answer keys are hidden from
/// direct client reads (FIX-12).
///
/// `grade_assessment_items` returns each answered item's `scoring_spec` and
/// `explanation`. The client merges them back into the item so the canonical
/// evaluator and answer-review UI keep a single scoring implementation.
typedef GradingTransport = Future<dynamic> Function(
  List<Map<String, dynamic>> payload,
);

class AssessmentGradingService {
  static const int maxBatchSize = 250;

  /// Placeholder response used to reveal keys for unanswered items after an
  /// exam is submitted. Every interaction type grades it as incorrect.
  static const Object unansweredPlaceholder = false;

  final SupabaseClient? _supabase;
  final GradingTransport? _transport;

  AssessmentGradingService({
    SupabaseClient? supabase,
    GradingTransport? transport,
  })  : _supabase = supabase,
        _transport = transport;

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  /// Returns [items] with server-revealed scoring for every item that lacks a
  /// local answer key. Items in [responses] use the learner's response; when
  /// [revealUnanswered] is true, the remaining items use a placeholder.
  Future<List<AssessmentItem>> revealScoring(
    List<AssessmentItem> items,
    Map<String, dynamic> responses, {
    bool revealUnanswered = false,
  }) async {
    final payload = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.hasLocalScoringSpec) continue;
      final response = responses[item.id];
      if (response != null) {
        payload.add({'item_id': item.id, 'response': response});
      } else if (revealUnanswered) {
        payload.add({'item_id': item.id, 'response': unansweredPlaceholder});
      }
    }
    if (payload.isEmpty) return items;

    final revealed = <String, Map<String, dynamic>>{};
    for (var start = 0; start < payload.length; start += maxBatchSize) {
      final end = (start + maxBatchSize).clamp(0, payload.length);
      revealed.addAll(await _grade(payload.sublist(start, end)));
    }

    return items.map((item) {
      final result = revealed[item.id];
      if (result == null) return item;
      return item.copyWith(
        scoringSpec:
            (result['scoring_spec'] as Map?)?.cast<String, dynamic>() ??
                const {},
        explanation: result['explanation'] as String?,
      );
    }).toList();
  }

  /// Reveals scoring for one answered item, throwing if it cannot be graded.
  Future<AssessmentItem> revealForResponse(
    AssessmentItem item,
    dynamic response,
  ) async {
    if (item.hasLocalScoringSpec) return item;
    final results = await _grade([
      {'item_id': item.id, 'response': response},
    ]);
    final result = results[item.id];
    if (result == null) {
      throw const AssessmentGradingException(
        'This question could not be checked right now.',
      );
    }
    return item.copyWith(
      scoringSpec:
          (result['scoring_spec'] as Map?)?.cast<String, dynamic>() ?? const {},
      explanation: result['explanation'] as String?,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _grade(
    List<Map<String, dynamic>> payload,
  ) async {
    final dynamic raw;
    try {
      raw = _transport != null
          ? await _transport(payload)
          : await _client.rpc(
              'grade_assessment_items',
              params: {'p_responses': payload},
            );
    } catch (_) {
      throw const AssessmentGradingException(
        'Answers could not be checked. Check your connection and try again.',
      );
    }
    if (raw is! List) {
      throw const AssessmentGradingException(
        'The grading service returned an unexpected response.',
      );
    }
    final graded = <String, Map<String, dynamic>>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final id = map['item_id']?.toString();
      if (id == null || map['error'] != null) continue;
      if (map['scoring_spec'] is! Map) continue;
      graded[id] = map;
    }
    return graded;
  }
}
