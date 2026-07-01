/// Snapshot of user data before a reset (for revert functionality)
class UserDataSnapshot {
  final String id;
  final String userId;
  final SnapshotType snapshotType;
  final String? targetId; // skill_id, career_path_id, course_id, or null for full
  final String? targetName; // Human-readable name for display
  final Map<String, dynamic> snapshotData;
  final String? reason;
  final RevertScope revertScope;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isReverted;

  const UserDataSnapshot({
    required this.id,
    required this.userId,
    required this.snapshotType,
    this.targetId,
    this.targetName,
    required this.snapshotData,
    this.reason,
    this.revertScope = RevertScope.full,
    required this.createdAt,
    required this.expiresAt,
    this.isReverted = false,
  });

  factory UserDataSnapshot.fromJson(Map<String, dynamic> json) {
    return UserDataSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      snapshotType: SnapshotType.fromString(json['snapshot_type'] as String),
      targetId: json['target_id'] as String?,
      targetName: json['target_name'] as String?,
      snapshotData: json['snapshot_data'] as Map<String, dynamic>,
      reason: json['reason'] as String?,
      revertScope: RevertScope.fromString(json['revert_scope'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isReverted: json['is_reverted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'snapshot_type': snapshotType.value,
        'target_id': targetId,
        'target_name': targetName,
        'snapshot_data': snapshotData,
        'reason': reason,
        'revert_scope': revertScope.value,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_reverted': isReverted,
      };

  /// Whether this snapshot can still be reverted
  bool get canRevert => !isReverted && DateTime.now().isBefore(expiresAt);

  /// Time remaining until snapshot expires
  Duration get timeRemaining {
    if (DateTime.now().isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }

  /// Days remaining (for display)
  int get daysRemaining => timeRemaining.inDays;

  /// Human-readable description of what was reset
  String get displayDescription {
    final target = targetName ?? 'Unknown';
    switch (snapshotType) {
      case SnapshotType.skillReset:
        return 'Skill reset: $target';
      case SnapshotType.careerReset:
        return 'Career path reset: $target';
      case SnapshotType.courseReset:
        return 'Course reset: $target';
      case SnapshotType.fullReset:
        return 'Full progress reset';
    }
  }

  /// Status label for display
  String get statusLabel {
    if (isReverted) return 'Reverted';
    if (!canRevert) return 'Expired';
    if (daysRemaining <= 3) return 'Expires soon';
    return 'Active';
  }

  UserDataSnapshot copyWith({
    String? id,
    String? userId,
    SnapshotType? snapshotType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? snapshotData,
    String? reason,
    RevertScope? revertScope,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isReverted,
  }) {
    return UserDataSnapshot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      snapshotType: snapshotType ?? this.snapshotType,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      snapshotData: snapshotData ?? this.snapshotData,
      reason: reason ?? this.reason,
      revertScope: revertScope ?? this.revertScope,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isReverted: isReverted ?? this.isReverted,
    );
  }
}

/// Type of reset that created the snapshot
enum SnapshotType {
  skillReset('skill_reset', 'Skill Reset', '🎯'),
  careerReset('career_reset', 'Career Reset', '🛤️'),
  courseReset('course_reset', 'Course Reset', '📚'),
  fullReset('full_reset', 'Full Reset', '💥');

  final String value;
  final String displayName;
  final String emoji;

  const SnapshotType(this.value, this.displayName, this.emoji);

  static SnapshotType fromString(String value) {
    return SnapshotType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SnapshotType.fullReset,
    );
  }

  String get fullDisplayName => '$emoji $displayName';
}

/// Scope of revert operation
enum RevertScope {
  singleAttempt('single_attempt', 'Single Attempt'),
  allAttempts('all_attempts', 'All Attempts'),
  full('full', 'Full State');

  final String value;
  final String displayName;

  const RevertScope(this.value, this.displayName);

  static RevertScope fromString(String? value) {
    return RevertScope.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RevertScope.full,
    );
  }
}

/// Statistics about available reverts
class RevertStats {
  final int totalSnapshots;
  final int activeSnapshots;
  final int revertedSnapshots;
  final int expiredSnapshots;
  final DateTime? oldestActiveExpiry;

  const RevertStats({
    this.totalSnapshots = 0,
    this.activeSnapshots = 0,
    this.revertedSnapshots = 0,
    this.expiredSnapshots = 0,
    this.oldestActiveExpiry,
  });

  factory RevertStats.fromSnapshots(List<UserDataSnapshot> snapshots) {
    final now = DateTime.now();
    final active = snapshots.where((s) => s.canRevert).toList();
    final reverted = snapshots.where((s) => s.isReverted).length;
    final expired =
        snapshots.where((s) => !s.isReverted && now.isAfter(s.expiresAt)).length;

    DateTime? oldestExpiry;
    if (active.isNotEmpty) {
      active.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      oldestExpiry = active.first.expiresAt;
    }

    return RevertStats(
      totalSnapshots: snapshots.length,
      activeSnapshots: active.length,
      revertedSnapshots: reverted,
      expiredSnapshots: expired,
      oldestActiveExpiry: oldestExpiry,
    );
  }
}
