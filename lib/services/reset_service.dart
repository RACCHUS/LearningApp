import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/data_snapshot.dart';

/// Service for reset/revert functionality with snapshot management
class ResetService {
  final SupabaseClient _supabase;
  final _uuid = const Uuid();

  /// Number of days before snapshots expire
  static const int snapshotExpiryDays = 30;

  ResetService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ============================================================================
  // SKILL RESET
  // ============================================================================

  /// Reset a skill's stats and assessment history
  /// Returns the snapshot ID for potential revert
  Future<String> resetSkill(String skillId, {String? reason}) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get the skill name for snapshot
      final skillResponse =
          await _supabase.from('skills').select('name').eq('id', skillId).single();
      final skillName = skillResponse['name'] as String;

      // Gather current state for snapshot
      final snapshotData = await _gatherSkillData(skillId);

      // Create snapshot
      final snapshotId = await _createSnapshot(
        type: SnapshotType.skillReset,
        targetId: skillId,
        targetName: skillName,
        data: snapshotData,
        reason: reason,
      );

      // Soft-delete all assessment attempts for this skill
      await _supabase.rpc('soft_delete_skill_attempts', params: {
        'p_user_id': userId,
        'p_skill_id': skillId,
      }).catchError((_) async {
        // Fallback if RPC doesn't exist - do it manually
        final assessmentIds = await _supabase
            .from('skill_assessments')
            .select('id')
            .eq('skill_id', skillId);

        for (final assessment in assessmentIds as List) {
          await _supabase
              .from('assessment_attempts')
              .update({'is_deleted': true, 'is_verified': false})
              .eq('user_id', userId)
              .eq('assessment_id', assessment['id']);
        }
      });

      // Reset skill stats
      await _supabase
          .from('user_skill_stats')
          .update({
            'level': 0,
            'best_score': 0,
            'average_score': 0,
            'total_assessments': 0,
            'is_verified': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('skill_id', skillId);

      debugPrint('✅ Skill reset: $skillName (snapshot: $snapshotId)');
      return snapshotId;
    } catch (e) {
      debugPrint('❌ Error resetting skill: $e');
      rethrow;
    }
  }

  /// Gather all skill data for snapshot
  Future<Map<String, dynamic>> _gatherSkillData(String skillId) async {
    final userId = _userId!;

    // Get skill stats
    final stats = await _supabase
        .from('user_skill_stats')
        .select()
        .eq('user_id', userId)
        .eq('skill_id', skillId)
        .maybeSingle();

    // Get all assessment attempts for this skill
    final assessmentIds = await _supabase
        .from('skill_assessments')
        .select('id')
        .eq('skill_id', skillId);

    final attempts = <Map<String, dynamic>>[];
    for (final assessment in assessmentIds as List) {
      final assessmentAttempts = await _supabase
          .from('assessment_attempts')
          .select()
          .eq('user_id', userId)
          .eq('assessment_id', assessment['id'])
          .eq('is_deleted', false);
      attempts.addAll((assessmentAttempts as List).cast<Map<String, dynamic>>());
    }

    return {
      'skill_stats': stats,
      'attempts': attempts,
    };
  }

  // ============================================================================
  // CAREER PATH RESET
  // ============================================================================

  /// Reset a career path's progress (all courses in path)
  Future<String> resetCareerPath(String pathId, {String? reason}) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get path name
      final pathResponse = await _supabase
          .from('career_paths')
          .select('title')
          .eq('id', pathId)
          .single();
      final pathName = pathResponse['title'] as String;

      // Gather current state
      final snapshotData = await _gatherCareerPathData(pathId);

      // Create snapshot
      final snapshotId = await _createSnapshot(
        type: SnapshotType.careerReset,
        targetId: pathId,
        targetName: pathName,
        data: snapshotData,
        reason: reason,
      );

      // Get all courses in the path
      final pathCourses = await _supabase
          .from('career_path_courses')
          .select('course_id')
          .eq('career_path_id', pathId);

      // Reset course progress for each course
      for (final course in pathCourses as List) {
        await _supabase
            .from('course_progress')
            .update({
              'lessons_completed': 0,
              'status': 'not_started',
              'completed_at': null,
              'total_time_minutes': 0,
            })
            .eq('user_id', userId)
            .eq('course_id', course['course_id']);
      }

      // Reset career path enrollment
      await _supabase
          .from('user_career_paths')
          .update({
            'status': 'active',
            'completed_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('career_path_id', pathId);

      debugPrint('✅ Career path reset: $pathName (snapshot: $snapshotId)');
      return snapshotId;
    } catch (e) {
      debugPrint('❌ Error resetting career path: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _gatherCareerPathData(String pathId) async {
    final userId = _userId!;

    // Get enrollment
    final enrollment = await _supabase
        .from('user_career_paths')
        .select()
        .eq('user_id', userId)
        .eq('career_path_id', pathId)
        .maybeSingle();

    // Get all course progress
    final pathCourses = await _supabase
        .from('career_path_courses')
        .select('course_id')
        .eq('career_path_id', pathId);

    final courseProgress = <Map<String, dynamic>>[];
    for (final course in pathCourses as List) {
      final progress = await _supabase
          .from('course_progress')
          .select()
          .eq('user_id', userId)
          .eq('course_id', course['course_id'])
          .maybeSingle();
      if (progress != null) {
        courseProgress.add(progress);
      }
    }

    return {
      'enrollment': enrollment,
      'course_progress': courseProgress,
    };
  }

  // ============================================================================
  // COURSE RESET
  // ============================================================================

  /// Reset a single course's progress
  Future<String> resetCourse(String courseId, {String? reason}) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get course name
      final courseResponse = await _supabase
          .from('courses')
          .select('title')
          .eq('id', courseId)
          .single();
      final courseName = courseResponse['title'] as String;

      // Gather current state
      final snapshotData = await _gatherCourseData(courseId);

      // Create snapshot
      final snapshotId = await _createSnapshot(
        type: SnapshotType.courseReset,
        targetId: courseId,
        targetName: courseName,
        data: snapshotData,
        reason: reason,
      );

      // Reset course progress
      await _supabase
          .from('course_progress')
          .update({
            'lessons_completed': 0,
            'status': 'not_started',
            'completed_at': null,
            'total_time_minutes': 0,
          })
          .eq('user_id', userId)
          .eq('course_id', courseId);

      // Reset lesson progress for all lessons in course
      final courseLessons = await _supabase
          .from('course_lessons')
          .select('lesson_id')
          .eq('course_id', courseId);

      for (final lesson in courseLessons as List) {
        await _supabase
            .from('user_progress')
            .update({
              'questions_answered': 0,
              'correct_count': 0,
              'lesson_completed': false,
              'study_time_minutes': 0,
            })
            .eq('user_id', userId)
            .eq('lesson_id', lesson['lesson_id']);
      }

      debugPrint('✅ Course reset: $courseName (snapshot: $snapshotId)');
      return snapshotId;
    } catch (e) {
      debugPrint('❌ Error resetting course: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _gatherCourseData(String courseId) async {
    final userId = _userId!;

    // Get course progress
    final courseProgress = await _supabase
        .from('course_progress')
        .select()
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .maybeSingle();

    // Get lesson progress
    final courseLessons = await _supabase
        .from('course_lessons')
        .select('lesson_id')
        .eq('course_id', courseId);

    final lessonProgress = <Map<String, dynamic>>[];
    for (final lesson in courseLessons as List) {
      final progress = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lesson['lesson_id']);
      lessonProgress.addAll((progress as List).cast<Map<String, dynamic>>());
    }

    return {
      'course_progress': courseProgress,
      'lesson_progress': lessonProgress,
    };
  }

  // ============================================================================
  // FULL RESET
  // ============================================================================

  /// Reset ALL user progress (nuclear option)
  Future<String> resetAllProgress({String? reason}) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Gather everything
      final snapshotData = await _gatherAllData();

      // Create snapshot
      final snapshotId = await _createSnapshot(
        type: SnapshotType.fullReset,
        targetId: null,
        targetName: 'All Progress',
        data: snapshotData,
        reason: reason,
      );

      // Track completed steps for partial rollback
      final completedTables = <String>[];
      
      try {
        // Reset all skill stats
        await _supabase
            .from('user_skill_stats')
            .update({
              'level': 0,
              'best_score': 0,
              'average_score': 0,
              'total_assessments': 0,
              'is_verified': false,
            })
            .eq('user_id', userId);
        completedTables.add('user_skill_stats');

        // Soft-delete all assessment attempts
        await _supabase
            .from('assessment_attempts')
            .update({'is_deleted': true, 'is_verified': false})
            .eq('user_id', userId);
        completedTables.add('assessment_attempts');

        // Reset all course progress
        await _supabase
            .from('course_progress')
            .update({
              'lessons_completed': 0,
              'status': 'not_started',
              'completed_at': null,
              'total_time_minutes': 0,
            })
            .eq('user_id', userId);
        completedTables.add('course_progress');

        // Reset all career path enrollments
        await _supabase
            .from('user_career_paths')
            .update({
              'status': 'active',
              'completed_at': null,
              'is_deleted': true,
            })
            .eq('user_id', userId);
        completedTables.add('user_career_paths');

        // Reset all user progress
        await _supabase
            .from('user_progress')
            .update({
              'questions_answered': 0,
              'correct_count': 0,
              'lesson_completed': false,
              'study_time_minutes': 0,
            })
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('❌ Full reset failed after updating: ${completedTables.join(", ")}');
        debugPrint('⚠️ Attempting automatic revert from snapshot: $snapshotId');
        try {
          await revertFromSnapshot(snapshotId);
          debugPrint('✅ Auto-revert succeeded');
        } catch (revertError) {
          debugPrint('❌ Auto-revert also failed: $revertError');
          debugPrint('ℹ️ User can manually revert using snapshot: $snapshotId');
        }
        rethrow;
      }

      debugPrint('✅ Full reset complete (snapshot: $snapshotId)');
      return snapshotId;
    } catch (e) {
      debugPrint('❌ Error performing full reset: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _gatherAllData() async {
    final userId = _userId!;

    final skillStats = await _supabase
        .from('user_skill_stats')
        .select()
        .eq('user_id', userId);

    final assessmentAttempts = await _supabase
        .from('assessment_attempts')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false);

    final courseProgress = await _supabase
        .from('course_progress')
        .select()
        .eq('user_id', userId);

    final careerPaths = await _supabase
        .from('user_career_paths')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false);

    final userProgress = await _supabase
        .from('user_progress')
        .select()
        .eq('user_id', userId);

    return {
      'skill_stats': skillStats,
      'assessment_attempts': assessmentAttempts,
      'course_progress': courseProgress,
      'career_paths': careerPaths,
      'user_progress': userProgress,
    };
  }

  // ============================================================================
  // REVERT
  // ============================================================================

  /// Revert from a snapshot (restore previous state)
  Future<void> revertFromSnapshot(
    String snapshotId, {
    RevertScope scope = RevertScope.full,
    String? specificAttemptId,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get the snapshot
      final snapshotResponse = await _supabase
          .from('user_data_snapshots')
          .select()
          .eq('id', snapshotId)
          .eq('user_id', userId)
          .single();

      final snapshot = UserDataSnapshot.fromJson(snapshotResponse);

      if (!snapshot.canRevert) {
        throw Exception('Snapshot cannot be reverted (expired or already reverted)');
      }

      // Restore based on snapshot type
      switch (snapshot.snapshotType) {
        case SnapshotType.skillReset:
          await _revertSkillReset(snapshot, scope, specificAttemptId);
          break;
        case SnapshotType.careerReset:
          await _revertCareerReset(snapshot);
          break;
        case SnapshotType.courseReset:
          await _revertCourseReset(snapshot);
          break;
        case SnapshotType.fullReset:
          await _revertFullReset(snapshot);
          break;
      }

      // Mark snapshot as reverted
      await _supabase
          .from('user_data_snapshots')
          .update({'is_reverted': true})
          .eq('id', snapshotId);

      debugPrint('✅ Reverted from snapshot: $snapshotId');
    } catch (e) {
      debugPrint('❌ Error reverting from snapshot: $e');
      rethrow;
    }
  }

  Future<void> _revertSkillReset(
    UserDataSnapshot snapshot,
    RevertScope scope,
    String? specificAttemptId,
  ) async {
    final data = snapshot.snapshotData;

    // Restore skill stats
    if (data['skill_stats'] != null) {
      final stats = data['skill_stats'] as Map<String, dynamic>;
      await _supabase
          .from('user_skill_stats')
          .upsert(stats, onConflict: 'user_id,skill_id');
    }

    // Restore attempts based on scope
    final attempts = (data['attempts'] as List?) ?? [];

    if (scope == RevertScope.singleAttempt && specificAttemptId != null) {
      // Restore only the specific attempt
      final attempt = attempts.firstWhere(
        (a) => a['id'] == specificAttemptId,
        orElse: () => null,
      );
      if (attempt != null) {
        attempt['is_deleted'] = false;
        attempt['is_verified'] = true;
        await _supabase.from('assessment_attempts').upsert(attempt);
      }
    } else {
      // Restore all attempts
      for (final attempt in attempts) {
        attempt['is_deleted'] = false;
        attempt['is_verified'] = true;
        await _supabase.from('assessment_attempts').upsert(attempt);
      }
    }
  }

  Future<void> _revertCareerReset(UserDataSnapshot snapshot) async {
    final data = snapshot.snapshotData;

    // Restore enrollment
    if (data['enrollment'] != null) {
      await _supabase.from('user_career_paths').upsert(
        data['enrollment'] as Map<String, dynamic>,
        onConflict: 'user_id,career_path_id',
      );
    }

    // Restore course progress
    final courseProgress = (data['course_progress'] as List?) ?? [];
    for (final progress in courseProgress) {
      await _supabase.from('course_progress').upsert(
        progress as Map<String, dynamic>,
        onConflict: 'user_id,course_id',
      );
    }
  }

  Future<void> _revertCourseReset(UserDataSnapshot snapshot) async {
    final data = snapshot.snapshotData;

    // Restore course progress
    if (data['course_progress'] != null) {
      await _supabase.from('course_progress').upsert(
        data['course_progress'] as Map<String, dynamic>,
        onConflict: 'user_id,course_id',
      );
    }

    // Restore lesson progress
    final lessonProgress = (data['lesson_progress'] as List?) ?? [];
    for (final progress in lessonProgress) {
      await _supabase.from('user_progress').upsert(
        progress as Map<String, dynamic>,
        onConflict: 'user_id,lesson_id,date',
      );
    }
  }

  Future<void> _revertFullReset(UserDataSnapshot snapshot) async {
    final data = snapshot.snapshotData;

    // Restore skill stats
    final skillStats = (data['skill_stats'] as List?) ?? [];
    for (final stats in skillStats) {
      await _supabase.from('user_skill_stats').upsert(
        stats as Map<String, dynamic>,
        onConflict: 'user_id,skill_id',
      );
    }

    // Restore assessment attempts
    final attempts = (data['assessment_attempts'] as List?) ?? [];
    for (final attempt in attempts) {
      attempt['is_deleted'] = false;
      attempt['is_verified'] = true;
      await _supabase.from('assessment_attempts').upsert(attempt);
    }

    // Restore course progress
    final courseProgress = (data['course_progress'] as List?) ?? [];
    for (final progress in courseProgress) {
      await _supabase.from('course_progress').upsert(
        progress as Map<String, dynamic>,
        onConflict: 'user_id,course_id',
      );
    }

    // Restore career paths
    final careerPaths = (data['career_paths'] as List?) ?? [];
    for (final path in careerPaths) {
      path['is_deleted'] = false;
      await _supabase.from('user_career_paths').upsert(
        path as Map<String, dynamic>,
        onConflict: 'user_id,career_path_id',
      );
    }

    // Restore user progress
    final userProgress = (data['user_progress'] as List?) ?? [];
    for (final progress in userProgress) {
      await _supabase.from('user_progress').upsert(
        progress as Map<String, dynamic>,
        onConflict: 'user_id,lesson_id,date',
      );
    }
  }

  // ============================================================================
  // SNAPSHOT MANAGEMENT
  // ============================================================================

  /// Create a snapshot before reset
  Future<String> _createSnapshot({
    required SnapshotType type,
    String? targetId,
    String? targetName,
    required Map<String, dynamic> data,
    String? reason,
  }) async {
    final userId = _userId!;
    final id = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: snapshotExpiryDays));

    await _supabase.from('user_data_snapshots').insert({
      'id': id,
      'user_id': userId,
      'snapshot_type': type.value,
      'target_id': targetId,
      'target_name': targetName,
      'snapshot_data': data,
      'reason': reason,
      'revert_scope': RevertScope.full.value,
      'created_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'is_reverted': false,
    });

    return id;
  }

  /// Get all available snapshots (that can still be reverted)
  Future<List<UserDataSnapshot>> getAvailableReverts() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_data_snapshots')
          .select()
          .eq('user_id', userId)
          .eq('is_reverted', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => UserDataSnapshot.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching available reverts: $e');
      rethrow;
    }
  }

  /// Get all snapshots (including reverted and expired)
  Future<List<UserDataSnapshot>> getAllSnapshots({int limit = 50}) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_data_snapshots')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => UserDataSnapshot.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching all snapshots: $e');
      rethrow;
    }
  }

  /// Get revert statistics
  Future<RevertStats> getRevertStats() async {
    final snapshots = await getAllSnapshots();
    return RevertStats.fromSnapshots(snapshots);
  }

  /// Delete a snapshot (before expiry if user wants)
  Future<void> deleteSnapshot(String snapshotId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      await _supabase
          .from('user_data_snapshots')
          .delete()
          .eq('id', snapshotId)
          .eq('user_id', userId);

      debugPrint('✅ Snapshot deleted: $snapshotId');
    } catch (e) {
      debugPrint('❌ Error deleting snapshot: $e');
      rethrow;
    }
  }
}
