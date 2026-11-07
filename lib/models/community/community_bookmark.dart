import 'package:flutter/foundation.dart';

/// Represents a learner's bookmarked educational answer or explanation (ECO-04).
///
/// Supports offline-first study review and persistent reference across devices.
@immutable
class CommunityBookmark {
  final String id;
  final String userId;
  final String contentType; // 'answer', 'question', 'explanation'
  final String contentId;
  final String title;
  final String bodySnippet;
  final String? conceptId;
  final String? authorId;
  final String? authorDisplayName;
  final bool isVerifiedAuthor;
  final DateTime createdAt;

  const CommunityBookmark({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.contentId,
    required this.title,
    required this.bodySnippet,
    this.conceptId,
    this.authorId,
    this.authorDisplayName,
    this.isVerifiedAuthor = false,
    required this.createdAt,
  });

  factory CommunityBookmark.fromJson(Map<String, dynamic> json) {
    return CommunityBookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? 'local_user',
      contentType: json['content_type'] as String? ?? 'answer',
      contentId: json['content_id'] as String,
      title: json['title'] as String? ?? '',
      bodySnippet: json['body_snippet'] as String? ?? '',
      conceptId: json['concept_id'] as String?,
      authorId: json['author_id'] as String?,
      authorDisplayName: json['author_display_name'] as String?,
      isVerifiedAuthor: json['is_verified_author'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content_type': contentType,
      'content_id': contentId,
      'title': title,
      'body_snippet': bodySnippet,
      if (conceptId != null) 'concept_id': conceptId,
      if (authorId != null) 'author_id': authorId,
      if (authorDisplayName != null) 'author_display_name': authorDisplayName,
      'is_verified_author': isVerifiedAuthor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CommunityBookmark copyWith({
    String? id,
    String? userId,
    String? contentType,
    String? contentId,
    String? title,
    String? bodySnippet,
    String? conceptId,
    String? authorId,
    String? authorDisplayName,
    bool? isVerifiedAuthor,
    DateTime? createdAt,
  }) {
    return CommunityBookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      bodySnippet: bodySnippet ?? this.bodySnippet,
      conceptId: conceptId ?? this.conceptId,
      authorId: authorId ?? this.authorId,
      authorDisplayName: authorDisplayName ?? this.authorDisplayName,
      isVerifiedAuthor: isVerifiedAuthor ?? this.isVerifiedAuthor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityBookmark &&
        other.id == id &&
        other.userId == userId &&
        other.contentType == contentType &&
        other.contentId == contentId &&
        other.title == title &&
        other.bodySnippet == bodySnippet &&
        other.conceptId == conceptId &&
        other.authorId == authorId &&
        other.authorDisplayName == authorDisplayName &&
        other.isVerifiedAuthor == isVerifiedAuthor &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        contentType,
        contentId,
        title,
        bodySnippet,
        conceptId,
        authorId,
        authorDisplayName,
        isVerifiedAuthor,
        createdAt,
      );
}

