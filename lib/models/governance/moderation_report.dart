/// Domain models for ECO-00B: Trust, Safety, Legal & Moderation Architecture.

enum ModerationTargetType {
  course('course', 'Course'),
  lesson('lesson', 'Lesson'),
  studySet('study_set', 'Study Set'),
  comment('comment', 'Comment'),
  userProfile('user_profile', 'User Profile'),
  unknown('unknown', 'Unknown');

  const ModerationTargetType(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ModerationTargetType fromDb(String? value) {
    return ModerationTargetType.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => ModerationTargetType.unknown,
    );
  }
}

enum ReportReason {
  childSafety('child_safety', 'Child Safety & Protection'),
  csamCsae('csam_csae', 'CSAM / CSAE (Zero Tolerance)'),
  harassment('harassment', 'Harassment or Bullying'),
  hateSpeech('hate_speech', 'Hate Speech'),
  copyrightInfringement('copyright_infringement', 'Copyright Infringement (DMCA)'),
  spamPhishing('spam_phishing', 'Spam or Phishing'),
  misinformation('misinformation', 'Harmful Misinformation'),
  inappropriateContent('inappropriate_content', 'Inappropriate Content'),
  promptInjection('prompt_injection', 'Adversarial Prompt Injection'),
  other('other', 'Other');

  const ReportReason(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ReportReason fromDb(String? value) {
    return ReportReason.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => ReportReason.other,
    );
  }
}

enum ReportStatus {
  pending('pending', 'Pending Review'),
  underReview('under_review', 'Under Review'),
  resolvedActionTaken('resolved_action_taken', 'Resolved (Action Taken)'),
  resolvedNoAction('resolved_no_action', 'Resolved (No Action)'),
  dismissed('dismissed', 'Dismissed');

  const ReportStatus(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ReportStatus fromDb(String? value) {
    return ReportStatus.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => ReportStatus.pending,
    );
  }

  bool get isTerminal =>
      this == ReportStatus.resolvedActionTaken ||
      this == ReportStatus.resolvedNoAction ||
      this == ReportStatus.dismissed;
}

enum ModerationActionType {
  approve('approve', 'Approve Content'),
  reject('reject', 'Reject Content'),
  warn('warn', 'Issue Warning'),
  contentHidden('content_hidden', 'Hide Content'),
  contentRemoved('content_removed', 'Remove Content'),
  accountSuspended('account_suspended', 'Suspend Account'),
  accountBanned('account_banned', 'Ban Account'),
  dismissReport('dismiss_report', 'Dismiss Report');

  const ModerationActionType(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ModerationActionType fromDb(String? value) {
    return ModerationActionType.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => ModerationActionType.dismissReport,
    );
  }
}

class ModerationRole {
  final String id;
  final String userId;
  final String role;
  final String? grantedBy;
  final DateTime grantedAt;

  const ModerationRole({
    required this.id,
    required this.userId,
    required this.role,
    this.grantedBy,
    required this.grantedAt,
  });

  bool get isModerator => role == 'moderator' || role == 'admin';
  bool get isAdmin => role == 'admin';

  factory ModerationRole.fromJson(Map<String, dynamic> json) {
    return ModerationRole(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      grantedBy: json['granted_by'] as String?,
      grantedAt: DateTime.parse(json['granted_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'role': role,
        'granted_by': grantedBy,
        'granted_at': grantedAt.toIso8601String(),
      };
}

class ModerationReport {
  final String id;
  final String reporterId;
  final ModerationTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      targetType: ModerationTargetType.fromDb(json['target_type'] as String?),
      targetId: json['target_id'] as String,
      reason: ReportReason.fromDb(json['reason'] as String?),
      description: json['description'] as String?,
      status: ReportStatus.fromDb(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter_id': reporterId,
        'target_type': targetType.dbValue,
        'target_id': targetId,
        'reason': reason.dbValue,
        'description': description,
        'status': status.dbValue,
        'created_at': createdAt.toIso8601String(),
        'resolved_at': resolvedAt?.toIso8601String(),
        'resolved_by': resolvedBy,
        'resolution_notes': resolutionNotes,
      };
}

class ModerationAction {
  final String id;
  final String? reportId;
  final String? moderatorId;
  final ModerationActionType action;
  final ModerationTargetType targetType;
  final String targetId;
  final String reason;
  final String? notes;
  final DateTime createdAt;

  const ModerationAction({
    required this.id,
    this.reportId,
    this.moderatorId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.notes,
    required this.createdAt,
  });

  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    return ModerationAction(
      id: json['id'] as String,
      reportId: json['report_id'] as String?,
      moderatorId: json['moderator_id'] as String?,
      action: ModerationActionType.fromDb(json['action'] as String?),
      targetType: ModerationTargetType.fromDb(json['target_type'] as String?),
      targetId: json['target_id'] as String,
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'report_id': reportId,
        'moderator_id': moderatorId,
        'action': action.dbValue,
        'target_type': targetType.dbValue,
        'target_id': targetId,
        'reason': reason,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
