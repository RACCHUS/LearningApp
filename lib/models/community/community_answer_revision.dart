/// An earlier version of a community answer: the text of a rejected answer
/// that a later answer revises (`learning.answer_revisions`). [editReason]
/// is the learner-facing review note it was rejected with, if any.
class CommunityAnswerRevision {
  final String id;
  final String answerId;
  final int revisionNumber;
  final String bodyMarkdown;
  final String editorId;
  final String? editReason;
  final String? sourceAnswerId;
  final DateTime createdAt;

  const CommunityAnswerRevision({
    required this.id,
    required this.answerId,
    required this.revisionNumber,
    required this.bodyMarkdown,
    required this.editorId,
    this.editReason,
    this.sourceAnswerId,
    required this.createdAt,
  });

  factory CommunityAnswerRevision.fromJson(Map<String, dynamic> json) {
    return CommunityAnswerRevision(
      id: json['id'] as String,
      answerId: json['answer_id'] as String,
      revisionNumber: (json['revision_number'] as num?)?.toInt() ?? 1,
      bodyMarkdown: json['body_markdown'] as String? ?? '',
      editorId: json['editor_id'] as String? ?? '',
      editReason: json['edit_reason'] as String?,
      sourceAnswerId: json['source_answer_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'answer_id': answerId,
        'revision_number': revisionNumber,
        'body_markdown': bodyMarkdown,
        'editor_id': editorId,
        if (editReason != null) 'edit_reason': editReason,
        if (sourceAnswerId != null) 'source_answer_id': sourceAnswerId,
        'created_at': createdAt.toIso8601String(),
      };
}
