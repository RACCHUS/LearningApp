import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/data_snapshot.dart';
import '../models/skill.dart';
import '../models/career_path.dart';
import '../services/reset_service.dart';
import 'skill_stats_provider.dart';
import 'career_path_provider.dart';

/// Service provider
final resetServiceProvider = Provider<ResetService>((ref) {
  return ResetService();
});

/// Available reverts (snapshots that can still be reverted)
final availableRevertsProvider =
    StateNotifierProvider<AvailableRevertsNotifier, AsyncValue<List<UserDataSnapshot>>>(
        (ref) {
  final service = ref.read(resetServiceProvider);
  return AvailableRevertsNotifier(service);
});

class AvailableRevertsNotifier
    extends StateNotifier<AsyncValue<List<UserDataSnapshot>>> {
  final ResetService _service;

  AvailableRevertsNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      state = const AsyncValue.loading();
      final reverts = await _service.getAvailableReverts();
      state = AsyncValue.data(reverts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _load();
  }
}

/// All snapshots (including reverted/expired)
final allSnapshotsProvider = FutureProvider<List<UserDataSnapshot>>((ref) async {
  final service = ref.read(resetServiceProvider);
  return service.getAllSnapshots();
});

/// Revert statistics
final revertStatsProvider = FutureProvider<RevertStats>((ref) async {
  final service = ref.read(resetServiceProvider);
  return service.getRevertStats();
});

// ============================================================================
// RESET STATE
// ============================================================================

/// State for reset operations
class ResetState {
  final bool isResetting;
  final String? lastSnapshotId;
  final String? error;
  final String? successMessage;

  const ResetState({
    this.isResetting = false,
    this.lastSnapshotId,
    this.error,
    this.successMessage,
  });

  ResetState copyWith({
    bool? isResetting,
    String? lastSnapshotId,
    String? error,
    String? successMessage,
  }) {
    return ResetState(
      isResetting: isResetting ?? this.isResetting,
      lastSnapshotId: lastSnapshotId ?? this.lastSnapshotId,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Reset operations notifier
final resetProvider =
    StateNotifierProvider<ResetNotifier, ResetState>((ref) {
  final service = ref.read(resetServiceProvider);
  return ResetNotifier(service, ref);
});

class ResetNotifier extends StateNotifier<ResetState> {
  final ResetService _service;
  final Ref _ref;

  ResetNotifier(this._service, this._ref) : super(const ResetState());

  /// Reset a skill's stats and history
  Future<String?> resetSkill(String skillId, {String? reason}) async {
    state = state.copyWith(isResetting: true, error: null, successMessage: null);

    try {
      final snapshotId = await _service.resetSkill(skillId, reason: reason);

      state = state.copyWith(
        isResetting: false,
        lastSnapshotId: snapshotId,
        successMessage: 'Skill reset successfully. You can revert within 30 days.',
      );

      // Refresh related providers
      _ref.read(userSkillStatsProvider.notifier).refresh();
      _ref.read(availableRevertsProvider.notifier).refresh();

      return snapshotId;
    } catch (e) {
      state = state.copyWith(
        isResetting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Reset a career path's progress
  Future<String?> resetCareerPath(String pathId, {String? reason}) async {
    state = state.copyWith(isResetting: true, error: null, successMessage: null);

    try {
      final snapshotId = await _service.resetCareerPath(pathId, reason: reason);

      state = state.copyWith(
        isResetting: false,
        lastSnapshotId: snapshotId,
        successMessage: 'Career path reset successfully. You can revert within 30 days.',
      );

      // Refresh related providers
      _ref.read(userCareerPathsProvider.notifier).refresh();
      _ref.read(availableRevertsProvider.notifier).refresh();

      return snapshotId;
    } catch (e) {
      state = state.copyWith(
        isResetting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Reset a course's progress
  Future<String?> resetCourse(String courseId, {String? reason}) async {
    state = state.copyWith(isResetting: true, error: null, successMessage: null);

    try {
      final snapshotId = await _service.resetCourse(courseId, reason: reason);

      state = state.copyWith(
        isResetting: false,
        lastSnapshotId: snapshotId,
        successMessage: 'Course reset successfully. You can revert within 30 days.',
      );

      // Refresh related providers
      _ref.read(availableRevertsProvider.notifier).refresh();

      return snapshotId;
    } catch (e) {
      state = state.copyWith(
        isResetting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Reset ALL progress
  Future<String?> resetAll({String? reason}) async {
    state = state.copyWith(isResetting: true, error: null, successMessage: null);

    try {
      final snapshotId = await _service.resetAllProgress(reason: reason);

      state = state.copyWith(
        isResetting: false,
        lastSnapshotId: snapshotId,
        successMessage: 'All progress reset. You can revert within 30 days.',
      );

      // Refresh all related providers
      _ref.read(userSkillStatsProvider.notifier).refresh();
      _ref.read(userCareerPathsProvider.notifier).refresh();
      _ref.read(availableRevertsProvider.notifier).refresh();

      return snapshotId;
    } catch (e) {
      state = state.copyWith(
        isResetting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Clear status messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ============================================================================
// REVERT STATE
// ============================================================================

/// State for revert operations
class RevertState {
  final bool isReverting;
  final String? error;
  final String? successMessage;

  const RevertState({
    this.isReverting = false,
    this.error,
    this.successMessage,
  });

  RevertState copyWith({
    bool? isReverting,
    String? error,
    String? successMessage,
  }) {
    return RevertState(
      isReverting: isReverting ?? this.isReverting,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Revert operations notifier
final revertProvider =
    StateNotifierProvider<RevertNotifier, RevertState>((ref) {
  final service = ref.read(resetServiceProvider);
  return RevertNotifier(service, ref);
});

class RevertNotifier extends StateNotifier<RevertState> {
  final ResetService _service;
  final Ref _ref;

  RevertNotifier(this._service, this._ref) : super(const RevertState());

  /// Revert from a snapshot
  Future<bool> revertFromSnapshot(
    String snapshotId, {
    RevertScope scope = RevertScope.full,
    String? specificAttemptId,
  }) async {
    state = state.copyWith(isReverting: true, error: null, successMessage: null);

    try {
      await _service.revertFromSnapshot(
        snapshotId,
        scope: scope,
        specificAttemptId: specificAttemptId,
      );

      state = state.copyWith(
        isReverting: false,
        successMessage: 'Successfully reverted to previous state.',
      );

      // Refresh all related providers
      _ref.read(userSkillStatsProvider.notifier).refresh();
      _ref.read(userCareerPathsProvider.notifier).refresh();
      _ref.read(availableRevertsProvider.notifier).refresh();

      return true;
    } catch (e) {
      state = state.copyWith(
        isReverting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Delete a snapshot (permanently remove revert option)
  Future<bool> deleteSnapshot(String snapshotId) async {
    try {
      await _service.deleteSnapshot(snapshotId);
      _ref.read(availableRevertsProvider.notifier).refresh();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear status messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

// ============================================================================
// RESET CONFIRMATION DIALOG DATA
// ============================================================================

/// Data for reset confirmation dialog
class ResetConfirmationData {
  final SnapshotType type;
  final String? targetId;
  final String targetName;
  final String description;
  final List<String> warnings;

  const ResetConfirmationData({
    required this.type,
    this.targetId,
    required this.targetName,
    required this.description,
    this.warnings = const [],
  });

  static ResetConfirmationData forSkill(Skill skill) {
    return ResetConfirmationData(
      type: SnapshotType.skillReset,
      targetId: skill.id,
      targetName: skill.name,
      description: 'This will reset your ${skill.name} skill level to 0 and mark all assessment attempts as practice.',
      warnings: [
        'Your verified score will be removed from leaderboards',
        'All assessment history will be marked as unverified',
        'You can take new assessments to rebuild your level',
      ],
    );
  }

  static ResetConfirmationData forCareerPath(CareerPath path) {
    return ResetConfirmationData(
      type: SnapshotType.careerReset,
      targetId: path.id,
      targetName: path.title,
      description: 'This will reset your progress in "${path.title}" career path.',
      warnings: [
        'All course progress within this path will be reset',
        'Your enrollment status will be set back to "Active"',
        'Lesson completion and study time will be cleared',
      ],
    );
  }

  static ResetConfirmationData forCourse(String courseId, String courseName) {
    return ResetConfirmationData(
      type: SnapshotType.courseReset,
      targetId: courseId,
      targetName: courseName,
      description: 'This will reset your progress in "$courseName".',
      warnings: [
        'All lesson progress will be cleared',
        'Quiz scores and study time will be reset',
        'You\'ll need to start the course from the beginning',
      ],
    );
  }

  static ResetConfirmationData forFullReset() {
    return const ResetConfirmationData(
      type: SnapshotType.fullReset,
      targetName: 'All Progress',
      description: 'This will reset ALL your learning progress across the entire app.',
      warnings: [
        '⚠️ This is the nuclear option!',
        'All skill levels will be set to 0',
        'All course progress will be cleared',
        'All career path progress will be reset',
        'All assessment history will be marked as practice',
        'Your XP and streaks will NOT be affected',
      ],
    );
  }
}
