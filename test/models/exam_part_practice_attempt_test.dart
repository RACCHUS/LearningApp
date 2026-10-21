import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment/exam_part_practice_attempt.dart';

Map<String, dynamic> row({
  String owner = 'owner-a',
  String version = 'version-a',
  String part = 'part-a',
}) => {
  'id': 'attempt-1',
  'owner_id': owner,
  'target_id': 'target-a',
  'target_version_id': version,
  'exam_part_key': part,
  'curriculum_root_node_id': 'root-a',
  'practice_kind': 'diagnostic',
  'completed_at': '2026-10-21T18:00:00Z',
  'question_count': 6,
  'fully_correct_count': 3,
  'partial_count': 1,
  'practice_score': 0.583333,
  'question_edition_fingerprint': 'abc123def456ghi789',
};
ExamPartPracticeAttempt parse(Map<String, dynamic> raw) =>
    ExamPartPracticeAttempt.fromRow(raw,
      expectedOwnerId: 'owner-a',
      targetVersionId: 'version-a',
      examPartKey: 'part-a');

void main() {
  test('exact canonical part + owner is preserved for portable export', () {
    final attempt = parse(row());
    expect(attempt.ownerId, 'owner-a');
    expect(attempt.examPartKey, 'part-a');
    expect(attempt.questionCount, 6);
    expect(attempt.toPrivateExport()['official_exam_result'], isFalse);
    expect(attempt.toPrivateExport()['question_edition_fingerprint'],
        'abc123def456ghi789');
    expect(attempt.toPrivateExport().containsKey('correct_answer'), isFalse);
  });
  test('rejects cross-account, cross-part and cross-version rows', () {
    expect(() => parse(row(owner: 'owner-b')), throwsStateError);
    expect(() => parse(row(part: 'part-b')), throwsStateError);
    expect(() => parse(row(version: 'version-b')), throwsStateError);
  });
  test('rejects fabricated scoring and unknown practice kind', () {
    for (final edit in [
      {'question_count': 0},
      {'question_count': 501},
      {'fully_correct_count': 7},
      {'partial_count': 5},
      {'practice_score': 1.5},
      {'practice_kind': 'official'},
      {'question_edition_fingerprint': 'short'},
    ]) {
      expect(() => parse({...row(), ...edit}), throwsFormatException);
    }
  });
}
