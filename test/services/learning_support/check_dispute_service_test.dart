import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/learning_support/check_dispute_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('submit errors map to plain outcomes', () {
    DisputeSubmitOutcome of(String m) =>
        CheckDisputeService.submitOutcomeFor(PostgrestException(message: m));
    expect(of('already_disputed'), DisputeSubmitOutcome.alreadySent);
    expect(of('rate_limited'), DisputeSubmitOutcome.rateLimited);
    expect(of('feature_disabled'), DisputeSubmitOutcome.unavailable);
    expect(of('authentication_required'), DisputeSubmitOutcome.unavailable);
    expect(of('invalid_dispute'), DisputeSubmitOutcome.failed);
    expect(
      CheckDisputeService.submitOutcomeFor(StateError('offline')),
      DisputeSubmitOutcome.failed,
    );
  });

  test('quarantine rows are read strictly', () {
    final refs = CheckDisputeService.parseQuarantine([
      {
        'content_kind': 'bridge',
        'content_id': 'b1',
        'content_version': '1.0.0',
        'item_id': 'q1',
      },
      {
        'content_kind': 'other',
        'content_id': 'b1',
        'content_version': '1.0.0',
        'item_id': 'q2',
      },
      {'content_kind': 'bridge', 'content_id': 'b1', 'item_id': 'q3'},
      'junk',
      null,
    ]);
    expect(refs.map((r) => r.key), ['b1@1.0.0#q1']);
  });

  test('open disputes group by check version, most disputed first', () {
    Map<String, dynamic> row(
      String item,
      String reason, {
      String version = '1.0.0',
      String? note,
      String at = '2026-11-19T10:00:00Z',
    }) => {
      'content_id': 'b1',
      'content_version': version,
      'item_id': item,
      'reason': reason,
      'note': note,
      'created_at': at,
    };
    final groups = CheckDisputeService.groupOpen([
      row('q1', 'unclear', at: '2026-11-18T10:00:00Z'),
      row('q2', 'wrong_answer', note: ' Key is B '),
      row('q2', 'wrong_answer'),
      row('q2', 'other', note: '   '),
      row('q2', 'wrong_answer', version: '1.0.1'),
      row('q3', 'not_a_reason'),
    ]);
    expect(groups.map((g) => g.ref.key), [
      'b1@1.0.0#q2',
      'b1@1.0.0#q1',
      'b1@1.0.1#q2',
    ]);
    final q2 = groups.first;
    expect(q2.count, 3);
    expect(q2.reasons[CheckDisputeReason.wrongAnswer], 2);
    expect(q2.notes, ['Key is B']);
  });
}
