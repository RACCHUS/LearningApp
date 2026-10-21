/// Immutable owner-private EXM-03 practice attempt summary.
/// No question prompts, answer keys, or official pass/fail claims are stored.
class ExamPartPracticeAttempt {
  final String id;
  final String ownerId;
  final String targetId;
  final String targetVersionId;
  final String examPartKey;
  final String curriculumRootNodeId;
  final String practiceKind;
  final DateTime completedAt;
  final int questionCount;
  final int fullyCorrectCount;
  final int partialCount;
  final double practiceScore;
  final String questionEditionFingerprint;

  const ExamPartPracticeAttempt({
    required this.id,
    required this.ownerId,
    required this.targetId,
    required this.targetVersionId,
    required this.examPartKey,
    required this.curriculumRootNodeId,
    required this.practiceKind,
    required this.completedAt,
    required this.questionCount,
    required this.fullyCorrectCount,
    required this.partialCount,
    required this.practiceScore,
    required this.questionEditionFingerprint,
  });

  factory ExamPartPracticeAttempt.fromRow(
      Map<String, dynamic> raw, {required String expectedOwnerId,
      required String targetVersionId, required String examPartKey}) {
    final owner = raw['owner_id'];
    if (owner != expectedOwnerId ||
        raw['target_version_id'] != targetVersionId ||
        raw['exam_part_key'] != examPartKey) {
      throw StateError('Private exam history account/version/part mismatch.');
    }
    final questions = (raw['question_count'] as num).toInt();
    final correct = (raw['fully_correct_count'] as num).toInt();
    final partial = (raw['partial_count'] as num).toInt();
    final score = (raw['practice_score'] as num).toDouble();
    final fingerprint = raw['question_edition_fingerprint'] as String;
    final kind = raw['practice_kind'] as String;
    if (questions < 1 || questions > 500 ||
        correct < 0 || partial < 0 || correct + partial > questions ||
        score < 0 || score > 1 ||
        !{'diagnostic', 'mock'}.contains(kind) ||
        fingerprint.length < 16) {
      throw const FormatException('Invalid exam attempt history row.');
    }
    return ExamPartPracticeAttempt(
      id: raw['id'] as String,
      ownerId: owner as String,
      targetId: raw['target_id'] as String,
      targetVersionId: targetVersionId,
      examPartKey: examPartKey,
      curriculumRootNodeId: raw['curriculum_root_node_id'] as String,
      practiceKind: kind,
      completedAt: DateTime.parse(raw['completed_at'] as String),
      questionCount: questions,
      fullyCorrectCount: correct,
      partialCount: partial,
      practiceScore: score,
      questionEditionFingerprint: fingerprint,
    );
  }

  Map<String, dynamic> toPrivateExport() => {
    'id': id,
    'owner_id': ownerId,
    'target_id': targetId,
    'target_version_id': targetVersionId,
    'exam_part_key': examPartKey,
    'curriculum_root_node_id': curriculumRootNodeId,
    'practice_kind': practiceKind,
    'completed_at': completedAt.toUtc().toIso8601String(),
    'question_count': questionCount,
    'fully_correct_count': fullyCorrectCount,
    'partial_count': partialCount,
    'practice_score': practiceScore,
    'question_edition_fingerprint': questionEditionFingerprint,
    'official_exam_result': false,
  };
}
