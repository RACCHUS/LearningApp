import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a learner thinks a practice check is wrong (master plan v2.6 §10.0
/// wrong-answer triage). The server accepts the same list.
enum CheckDisputeReason {
  wrongAnswer('wrong_answer', 'The marked answer is wrong'),
  unclear('unclear', 'The question is unclear'),
  inputProblem('input_problem', "My answer couldn't be entered or read"),
  sourceMismatch('source_mismatch', "It doesn't match the source"),
  other('other', 'Something else');

  const CheckDisputeReason(this.wire, this.label);

  final String wire;
  final String label;

  static CheckDisputeReason? fromWire(Object? v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

/// One practice check at one content version.
class CheckRef {
  const CheckRef({
    required this.contentId,
    required this.contentVersion,
    required this.itemId,
  });

  final String contentId;
  final String contentVersion;
  final String itemId;

  /// Stable key for sets and maps.
  String get key => '$contentId@$contentVersion#$itemId';

  @override
  bool operator ==(Object other) => other is CheckRef && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

enum DisputeSubmitOutcome {
  sent,
  alreadySent,
  rateLimited,

  /// Switched off, or not signed in: the dispute stays on this device.
  unavailable,
  failed,
}

/// Open disputes for one check, grouped for review.
class DisputedCheck {
  const DisputedCheck({
    required this.ref,
    required this.reasons,
    required this.notes,
    required this.firstReported,
  });

  final CheckRef ref;

  /// How many open disputes gave each reason.
  final Map<CheckDisputeReason, int> reasons;

  /// Learners' optional notes.
  final List<String> notes;
  final DateTime firstReported;

  int get count => reasons.values.fold(0, (a, b) => a + b);
}

/// A refusal from a moderator action, with a plain-language message.
class CheckDisputeException implements Exception {
  CheckDisputeException(this.code);

  final String code;

  String get message => switch (code) {
    'feature_disabled' => 'Dispute review is switched off.',
    'moderator_required' => 'Only moderators can do this.',
    'dismiss_reason_required' => 'Please say why the question is fine.',
    'cannot_decide_own_dispute' =>
      'You disputed this question yourself, so another moderator must '
          'decide.',
    'no_open_disputes' =>
      'Someone already decided this. Refresh to see the queue.',
    _ => 'Something went wrong. Nothing was changed.',
  };

  @override
  String toString() => code;
}

/// Calls the disputed-check RPCs (migration 20261119000000). The server
/// checks the gate, sign-in, roles, formats and rate limits.
class CheckDisputeService {
  CheckDisputeService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;

  static String _text(Object e) => e is PostgrestException ? e.message : '$e';

  /// Maps a submit error to an outcome. Exposed for tests.
  static DisputeSubmitOutcome submitOutcomeFor(Object error) {
    final t = _text(error);
    if (t.contains('already_disputed')) return DisputeSubmitOutcome.alreadySent;
    if (t.contains('rate_limited')) return DisputeSubmitOutcome.rateLimited;
    if (t.contains('feature_disabled') ||
        t.contains('authentication_required')) {
      return DisputeSubmitOutcome.unavailable;
    }
    return DisputeSubmitOutcome.failed;
  }

  Future<DisputeSubmitOutcome> submit(
    CheckRef ref,
    CheckDisputeReason reason, {
    String? note,
  }) async {
    try {
      await _db.rpc(
        'submit_check_dispute',
        params: {
          'p_content_id': ref.contentId,
          'p_content_version': ref.contentVersion,
          'p_item_id': ref.itemId,
          'p_reason': reason.wire,
          'p_note': note,
        },
      );
      return DisputeSubmitOutcome.sent;
    } catch (e) {
      return submitOutcomeFor(e);
    }
  }

  /// Check versions a moderator upheld. Errors give an empty set: the
  /// learner's own local disputes still apply.
  Future<Set<CheckRef>> quarantined() async {
    try {
      final rows = await _db.rpc('quarantined_check_items') as List;
      return parseQuarantine(rows);
    } catch (_) {
      return const {};
    }
  }

  static Set<CheckRef> parseQuarantine(List<Object?> rows) => {
    for (final r in rows)
      if (r is Map &&
          r['content_kind'] == 'bridge' &&
          r['content_id'] is String &&
          r['content_version'] is String &&
          r['item_id'] is String)
        CheckRef(
          contentId: r['content_id'] as String,
          contentVersion: r['content_version'] as String,
          itemId: r['item_id'] as String,
        ),
  };

  /// Open disputes, grouped by check, most disputed first.
  Future<List<DisputedCheck>> openQueue() async {
    final rows = await _db
        .from('learning_check_disputes')
        .select(
          'content_id, content_version, item_id, reason, note, created_at',
        )
        .eq('status', 'open')
        .order('created_at')
        .limit(500);
    return groupOpen(rows);
  }

  static List<DisputedCheck> groupOpen(List<Map<String, dynamic>> rows) {
    final reasons = <CheckRef, Map<CheckDisputeReason, int>>{};
    final notes = <CheckRef, List<String>>{};
    final first = <CheckRef, DateTime>{};
    for (final r in rows) {
      final reason = CheckDisputeReason.fromWire(r['reason']);
      final created = DateTime.tryParse('${r['created_at']}');
      if (reason == null || created == null) continue;
      final ref = CheckRef(
        contentId: '${r['content_id']}',
        contentVersion: '${r['content_version']}',
        itemId: '${r['item_id']}',
      );
      final counts = reasons.putIfAbsent(ref, () => {});
      counts[reason] = (counts[reason] ?? 0) + 1;
      final note = (r['note'] as String?)?.trim();
      if (note != null && note.isNotEmpty) {
        notes.putIfAbsent(ref, () => []).add(note);
      }
      if (first[ref] == null || created.isBefore(first[ref]!)) {
        first[ref] = created;
      }
    }
    final out = [
      for (final ref in reasons.keys)
        DisputedCheck(
          ref: ref,
          reasons: Map.unmodifiable(reasons[ref]!),
          notes: List.unmodifiable(notes[ref] ?? const <String>[]),
          firstReported: first[ref]!,
        ),
    ];
    out.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.firstReported.compareTo(b.firstReported);
    });
    return out;
  }

  /// Upholds (quarantines) or dismisses every open dispute for [ref].
  /// Returns how many disputes were settled.
  Future<int> decide(CheckRef ref, {required bool uphold, String? note}) async {
    try {
      final n = await _db.rpc(
        'decide_check_disputes',
        params: {
          'p_content_id': ref.contentId,
          'p_content_version': ref.contentVersion,
          'p_item_id': ref.itemId,
          'p_uphold': uphold,
          'p_note': note,
        },
      );
      return (n as num).toInt();
    } catch (e) {
      final t = _text(e);
      for (final code in const [
        'feature_disabled',
        'moderator_required',
        'dismiss_reason_required',
        'cannot_decide_own_dispute',
        'no_open_disputes',
      ]) {
        if (t.contains(code)) throw CheckDisputeException(code);
      }
      throw CheckDisputeException('unknown');
    }
  }
}
