/// Domain models for ECO-00B: Trust, Safety, Legal & Moderation Architecture.
/// Canonical database contract aligned with `public.moderation_*` tables and RPCs.

enum ModerationTargetType {
  course('course', 'Course'),
  lesson('lesson', 'Lesson'),
  studySet('study_set', 'Study Set'),
  wordList('word_list', 'Word List'),
  curriculum('curriculum', 'Curriculum Node'),
  resource('resource', 'User Resource'),
  question('question', 'Question'),
  profile('profile', 'User Profile');

  const ModerationTargetType(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ModerationTargetType fromDb(String? value) {
    if (value == null) {
      throw ArgumentError.notNull('targetType');
    }
    return ModerationTargetType.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => throw FormatException('Unknown target type: $value'),
    );
  }
}

enum ReportReason {
  spam('spam', 'Spam or Phishing'),
  harassment('harassment', 'Harassment or Bullying'),
  misinformation('misinformation', 'Harmful Misinformation'),
  copyright('copyright', 'Copyright Infringement (DMCA)'),
  minorSafety('minor_safety', 'Child Safety & Protection (Zero Tolerance)'),
  inappropriate('inappropriate', 'Inappropriate Content'),
  other('other', 'Other');

  const ReportReason(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ReportReason fromDb(String? value) {
    if (value == null) {
      throw ArgumentError.notNull('reportReason');
    }
    return ReportReason.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => throw FormatException('Unknown report reason: $value'),
    );
  }
}

enum ReportStatus {
  pending('pending', 'Pending Review'),
  underReview('under_review', 'Under Review'),
  actioned('actioned', 'Actioned'),
  dismissed('dismissed', 'Dismissed');

  const ReportStatus(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ReportStatus fromDb(String? value) {
    if (value == null) {
      throw ArgumentError.notNull('reportStatus');
    }
    return ReportStatus.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => throw FormatException('Unknown report status: $value'),
    );
  }

  bool get isTerminal =>
      this == ReportStatus.actioned || this == ReportStatus.dismissed;
}

enum ModerationActionType {
  dismiss('dismiss', 'Dismiss Report'),
  warn('warn', 'Issue Warning'),
  hide('hide', 'Hide Content (Admin Record)'),
  delete('delete', 'Remove Content (Admin Record)'),
  suspendUser('suspend_user', 'Suspend User (Admin Record)'),
  rateLimit('rate_limit', 'Rate Limit User (Admin Record)');

  const ModerationActionType(this.dbValue, this.displayName);
  final String dbValue;
  final String displayName;

  static ModerationActionType fromDb(String? value) {
    if (value == null) {
      throw ArgumentError.notNull('moderationAction');
    }
    return ModerationActionType.values.firstWhere(
      (v) => v.dbValue == value,
      orElse: () => throw FormatException('Unknown moderation action: $value'),
    );
  }
}

class ModerationRole {
  final String id;
  final String userId;
  final String role;
  final String? grantedBy;
  final DateTime createdAt;

  const ModerationRole({
    required this.id,
    required this.userId,
    required this.role,
    this.grantedBy,
    required this.createdAt,
  });

  bool get isModerator => role == 'moderator' || role == 'admin';
  bool get isAdmin => role == 'admin';

  factory ModerationRole.fromJson(Map<String, dynamic> json) {
    return ModerationRole(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      grantedBy: json['granted_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'role': role,
        'granted_by': grantedBy,
        'created_at': createdAt.toIso8601String(),
      };
}

class ModerationReport {
  final String id;
  final String? reporterId;
  final ModerationTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ModerationReport({
    required this.id,
    this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String?,
      targetType: ModerationTargetType.fromDb(json['target_type'] as String?),
      targetId: json['target_id'] as String,
      reason: ReportReason.fromDb(json['reason'] as String?),
      description: json['description'] as String?,
      status: ReportStatus.fromDb(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? json['created_at'] as String,
      ),
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
        'updated_at': updatedAt.toIso8601String(),
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
