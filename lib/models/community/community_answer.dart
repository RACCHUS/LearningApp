import 'package:flutter/foundation.dart';

/// Represents an answer to an educational query in the Community Q&A domain (ECO-01).
///
/// Supports explicit AI generation provenance flags and accepted solution indicators.
@immutable
class CommunityAnswer {
  final String id;
  final String questionId;
  final String authorId;
  final String bodyMarkdown;
  final bool isAiGenerated;
  final String? aiModelName;
  final bool isAccepted;
  final String status; // 'draft', 'under_review', 'published', 'archived', 'flagged'
  final int upvoteCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityAnswer({
    required this.id,
    required this.questionId,
    required this.authorId,
    required this.bodyMarkdown,
    this.isAiGenerated = false,
    this.aiModelName,
    this.isAccepted = false,
    this.status = 'published',
    this.upvoteCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == 'published';
  bool get isFlagged => status == 'flagged';

  factory CommunityAnswer.fromJson(Map<String, dynamic> json) {
    return CommunityAnswer(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      authorId: json['author_id'] as String,
      bodyMarkdown: json['body_markdown'] as String,
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      aiModelName: json['ai_model_name'] as String?,
      isAccepted: json['is_accepted'] as bool? ?? false,
      status: json['status'] as String? ?? 'published',
      upvoteCount: json['upvote_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'author_id': authorId,
      'body_markdown': bodyMarkdown,
      'is_ai_generated': isAiGenerated,
      if (aiModelName != null) 'ai_model_name': aiModelName,
      'is_accepted': isAccepted,
      'status': status,
      'upvote_count': upvoteCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CommunityAnswer copyWith({
    String? id,
    String? questionId,
    String? authorId,
    String? bodyMarkdown,
    bool? isAiGenerated,
    String? aiModelName,
    bool? isAccepted,
    String? status,
    int? upvoteCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityAnswer(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      authorId: authorId ?? this.authorId,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      aiModelName: aiModelName ?? this.aiModelName,
      isAccepted: isAccepted ?? this.isAccepted,
      status: status ?? this.status,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
