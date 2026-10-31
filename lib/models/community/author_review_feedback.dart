import 'package:flutter/foundation.dart';

/// Represents author-facing decision feedback for a community submission (ECO-02).
///
/// Designed to provide learners actionable editorial guidance without exposing
/// internal moderator notes, other users' submissions, or reviewer identity.
@immutable
class AuthorReviewFeedback {
  final String id;
  final String targetType; // 'question' | 'answer'
  final String targetId;
  final String action; // 'publish' | 'reject' | 'archive' | 'flag'
  final String newStatus;
  final String feedback;
  final DateTime createdAt;

  const AuthorReviewFeedback({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.action,
    required this.newStatus,
    required this.feedback,
    required this.createdAt,
  });

  bool get isQuestion => targetType == 'question';
  bool get isAnswer => targetType == 'answer';

  factory AuthorReviewFeedback.fromJson(Map<String, dynamic> json) {
    return AuthorReviewFeedback(
      id: json['id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      action: json['action'] as String,
      newStatus: json['new_status'] as String,
      feedback: json['feedback'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_type': targetType,
      'target_id': targetId,
      'action': action,
      'new_status': newStatus,
      'feedback': feedback,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
