import 'package:flutter/foundation.dart';

/// Represents a concept-scoped educational query in the Community Q&A domain (ECO-01).
///
/// Distinct from assessment questions ([Question]), which assess individual learner mastery.
@immutable
class CommunityQuestion {
  final String id;
  final String authorId;
  final String title;
  final String bodyMarkdown;
  final String status; // 'draft', 'under_review', 'published', 'archived'
  final bool isSeeded;
  final String? seedKey;
  final String? conceptId;
  final String? targetId;
  final String? lessonId;
  final String? cipCode;
  final int viewCount;
  final int upvoteCount;
  final int answerCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CommunityQuestion({
    required this.id,
    required this.authorId,
    required this.title,
    required this.bodyMarkdown,
    this.status = 'draft',
    this.isSeeded = false,
    this.seedKey,
    this.conceptId,
    this.targetId,
    this.lessonId,
    this.cipCode,
    this.viewCount = 0,
    this.upvoteCount = 0,
    this.answerCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == 'published';
  bool get isDraft => status == 'draft';
  bool get isUnderReview => status == 'under_review';

  factory CommunityQuestion.fromJson(Map<String, dynamic> json) {
    return CommunityQuestion(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      title: json['title'] as String,
      bodyMarkdown: json['body_markdown'] as String,
      status: json['status'] as String? ?? 'draft',
      isSeeded: json['is_seeded'] as bool? ?? false,
      seedKey: json['seed_key'] as String?,
      conceptId: json['concept_id'] as String?,
      targetId: json['target_id'] as String?,
      lessonId: json['lesson_id'] as String?,
      cipCode: json['cip_code'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      upvoteCount: json['upvote_count'] as int? ?? 0,
      answerCount: json['answer_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'title': title,
      'body_markdown': bodyMarkdown,
      'status': status,
      'is_seeded': isSeeded,
      if (seedKey != null) 'seed_key': seedKey,
      if (conceptId != null) 'concept_id': conceptId,
      if (targetId != null) 'target_id': targetId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (cipCode != null) 'cip_code': cipCode,
      'view_count': viewCount,
      'upvote_count': upvoteCount,
      'answer_count': answerCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CommunityQuestion copyWith({
    String? id,
    String? authorId,
    String? title,
    String? bodyMarkdown,
    String? status,
    bool? isSeeded,
    String? seedKey,
    String? conceptId,
    String? targetId,
    String? lessonId,
    String? cipCode,
    int? viewCount,
    int? upvoteCount,
    int? answerCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityQuestion(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      bodyMarkdown: bodyMarkdown ?? this.bodyMarkdown,
      status: status ?? this.status,
      isSeeded: isSeeded ?? this.isSeeded,
      seedKey: seedKey ?? this.seedKey,
      conceptId: conceptId ?? this.conceptId,
      targetId: targetId ?? this.targetId,
      lessonId: lessonId ?? this.lessonId,
      cipCode: cipCode ?? this.cipCode,
      viewCount: viewCount ?? this.viewCount,
      upvoteCount: upvoteCount ?? this.upvoteCount,
      answerCount: answerCount ?? this.answerCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
