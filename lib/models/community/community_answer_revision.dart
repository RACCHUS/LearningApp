/// Represents a specific version snapshot of an authored community answer (ECO-01, Priority 5).
class CommunityAnswerRevision {
  final String id;
  final String answerId;
  final int revisionNumber;
  final String bodyMarkdown;
  final String editorId;
  final String? editReason;
  final DateTime createdAt;

  const CommunityAnswerRevision({
    required this.id,
    required this.answerId,
    required this.revisionNumber,
    required this.bodyMarkdown,
    required this.editorId,
    this.editReason,
    required this.createdAt,
  });

  factory CommunityAnswerRevision.fromJson(Map<String, dynamic> json) {
    return CommunityAnswerRevision(
      id: json['id'] as String,
      answerId: json['answer_id'] as String,
      revisionNumber: json['revision_number'] as int? ?? 1,
      bodyMarkdown: json['body_markdown'] as String? ?? '',
      editorId: json['editor_id'] as String? ?? '',
      editReason: json['edit_reason'] as String?,
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
        'created_at': createdAt.toIso8601String(),
      };
}
