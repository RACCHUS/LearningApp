import 'package:flutter/foundation.dart';

/// Represents a durable review action performed by an educator or moderator
/// on a community question or answer (ECO-02).
@immutable
class CommunityReviewAudit {
  final String id;
  final String targetType; // 'question' | 'answer'
  final String targetId;
  final String? reviewerId;
  final String action; // 'publish' | 'reject' | 'archive' | 'flag'
  final String previousStatus;
  final String newStatus;
  final String? notes;
  final DateTime createdAt;

  const CommunityReviewAudit({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.reviewerId,
    required this.action,
    required this.previousStatus,
    required this.newStatus,
    this.notes,
    required this.createdAt,
  });

  bool get isQuestion => targetType == 'question';
  bool get isAnswer => targetType == 'answer';

  factory CommunityReviewAudit.fromJson(Map<String, dynamic> json) {
    return CommunityReviewAudit(
      id: json['id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      reviewerId: json['reviewer_id'] as String?,
      action: json['action'] as String,
      previousStatus: json['previous_status'] as String,
      newStatus: json['new_status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_type': targetType,
      'target_id': targetId,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      'action': action,
      'previous_status': previousStatus,
      'new_status': newStatus,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
