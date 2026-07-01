import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/career_path.dart';

/// Service for managing career paths and user enrollment
class CareerPathService {
  final SupabaseClient _supabase;

  CareerPathService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  // ============================================================================
  // CAREER PATH CRUD
  // ============================================================================

  /// Get all public/featured career paths
  Future<List<CareerPath>> getCareerPaths({
    bool? featuredOnly,
    bool? officialOnly,
    String? category,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('career_paths').select('''
        *,
        career_path_skills(*, skills(*)),
        career_path_courses(*, courses(*))
      ''').eq('is_public', true);

      if (featuredOnly == true) {
        query = query.eq('is_featured', true);
      }
      if (officialOnly == true) {
        query = query.eq('is_official', true);
      }

      final response =
          await query.order('title').range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => CareerPath.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching career paths: $e');
      rethrow;
    }
  }

  /// Get a single career path with full details
  Future<CareerPath> getCareerPath(String pathId) async {
    try {
      final response = await _supabase.from('career_paths').select('''
        *,
        career_path_skills(*, skills(*)),
        career_path_courses(*, courses(*))
      ''').eq('id', pathId).single();

      return CareerPath.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching career path: $e');
      rethrow;
    }
  }

  /// Get career path by slug
  Future<CareerPath?> getCareerPathBySlug(String slug) async {
    try {
      final response = await _supabase.from('career_paths').select('''
        *,
        career_path_skills(*, skills(*)),
        career_path_courses(*, courses(*))
      ''').eq('slug', slug).maybeSingle();

      return response != null ? CareerPath.fromJson(response) : null;
    } catch (e) {
      debugPrint('❌ Error fetching career path by slug: $e');
      rethrow;
    }
  }

  /// Create a new career path (community-created)
  Future<CareerPath> createCareerPath({
    required String title,
    required String slug,
    String? description,
    String? imageUrl,
    int estimatedMonths = 6,
    bool isPublic = false,
  }) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('career_paths')
          .insert({
            'title': title,
            'slug': slug,
            'description': description,
            'image_url': imageUrl,
            'estimated_months': estimatedMonths,
            'is_public': isPublic,
            'is_official': false, // Community-created
            'created_by': userId,
          })
          .select()
          .single();

      debugPrint('✅ Career path created: ${response['id']}');
      return CareerPath.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating career path: $e');
      rethrow;
    }
  }

  /// Update a career path
  Future<CareerPath> updateCareerPath(
    String pathId, {
    String? title,
    String? description,
    String? imageUrl,
    int? estimatedMonths,
    bool? isPublic,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (estimatedMonths != null) updates['estimated_months'] = estimatedMonths;
      if (isPublic != null) updates['is_public'] = isPublic;

      final response = await _supabase
          .from('career_paths')
          .update(updates)
          .eq('id', pathId)
          .select()
          .single();

      return CareerPath.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating career path: $e');
      rethrow;
    }
  }

  /// Delete a career path
  Future<void> deleteCareerPath(String pathId) async {
    try {
      await _supabase.from('career_paths').delete().eq('id', pathId);
      debugPrint('✅ Career path deleted: $pathId');
    } catch (e) {
      debugPrint('❌ Error deleting career path: $e');
      rethrow;
    }
  }

  // ============================================================================
  // COURSE ASSOCIATIONS
  // ============================================================================

  /// Add a course to a career path
  Future<void> addCourseToPath({
    required String pathId,
    required String courseId,
    int orderIndex = 0,
    bool isRequired = true,
    String? sectionTitle,
  }) async {
    try {
      await _supabase.from('career_path_courses').insert({
        'career_path_id': pathId,
        'course_id': courseId,
        'order_index': orderIndex,
        'is_required': isRequired,
        'section_title': sectionTitle,
      });
      debugPrint('✅ Course added to career path');
    } catch (e) {
      debugPrint('❌ Error adding course to path: $e');
      rethrow;
    }
  }

  /// Remove a course from a career path
  Future<void> removeCourseFromPath({
    required String pathId,
    required String courseId,
  }) async {
    try {
      await _supabase
          .from('career_path_courses')
          .delete()
          .eq('career_path_id', pathId)
          .eq('course_id', courseId);
      debugPrint('✅ Course removed from career path');
    } catch (e) {
      debugPrint('❌ Error removing course from path: $e');
      rethrow;
    }
  }

  /// Reorder courses in a career path
  Future<void> reorderCourses(
    String pathId,
    List<String> courseIds,
  ) async {
    try {
      for (int i = 0; i < courseIds.length; i++) {
        await _supabase
            .from('career_path_courses')
            .update({'order_index': i})
            .eq('career_path_id', pathId)
            .eq('course_id', courseIds[i]);
      }
      debugPrint('✅ Courses reordered');
    } catch (e) {
      debugPrint('❌ Error reordering courses: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SKILL ASSOCIATIONS
  // ============================================================================

  /// Add a skill to a career path
  Future<void> addSkillToPath({
    required String pathId,
    required String skillId,
    SkillImportance importance = SkillImportance.core,
  }) async {
    try {
      await _supabase.from('career_path_skills').insert({
        'career_path_id': pathId,
        'skill_id': skillId,
        'importance': importance.value,
      });
      debugPrint('✅ Skill added to career path');
    } catch (e) {
      debugPrint('❌ Error adding skill to path: $e');
      rethrow;
    }
  }

  /// Remove a skill from a career path
  Future<void> removeSkillFromPath({
    required String pathId,
    required String skillId,
  }) async {
    try {
      await _supabase
          .from('career_path_skills')
          .delete()
          .eq('career_path_id', pathId)
          .eq('skill_id', skillId);
      debugPrint('✅ Skill removed from career path');
    } catch (e) {
      debugPrint('❌ Error removing skill from path: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USER ENROLLMENT
  // ============================================================================

  /// Enroll user in a career path
  Future<UserCareerPath> enrollInCareerPath(String pathId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_career_paths')
          .upsert({
            'user_id': userId,
            'career_path_id': pathId,
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
            'is_deleted': false,
          }, onConflict: 'user_id,career_path_id')
          .select('*, career_paths(*)')
          .single();

      debugPrint('✅ Enrolled in career path: $pathId');
      return UserCareerPath.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error enrolling in career path: $e');
      rethrow;
    }
  }

  /// Get user's enrolled career paths
  Future<List<UserCareerPath>> getUserCareerPaths() async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final response = await _supabase
          .from('user_career_paths')
          .select('*, career_paths(*, career_path_skills(*, skills(*)), career_path_courses(*, courses(*)))')
          .eq('user_id', userId)
          .eq('is_deleted', false)
          .order('started_at', ascending: false);

      return (response as List)
          .map((json) => UserCareerPath.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching user career paths: $e');
      rethrow;
    }
  }

  /// Update career path enrollment status
  Future<void> updateEnrollmentStatus(
    String pathId,
    CareerPathStatus status,
  ) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      final updates = <String, dynamic>{
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == CareerPathStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('user_career_paths')
          .update(updates)
          .eq('user_id', userId)
          .eq('career_path_id', pathId);

      debugPrint('✅ Enrollment status updated: $status');
    } catch (e) {
      debugPrint('❌ Error updating enrollment status: $e');
      rethrow;
    }
  }

  /// Leave a career path (soft delete)
  Future<void> leaveCareerPath(String pathId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      await _supabase
          .from('user_career_paths')
          .update({
            'status': CareerPathStatus.abandoned.value,
            'is_deleted': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('career_path_id', pathId);

      debugPrint('✅ Left career path: $pathId');
    } catch (e) {
      debugPrint('❌ Error leaving career path: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PROGRESS TRACKING
  // ============================================================================

  /// Calculate user's progress in a career path
  Future<CareerPathProgress> getCareerPathProgress(String pathId) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
      // Get path courses
      final pathCourses = await _supabase
          .from('career_path_courses')
          .select('course_id')
          .eq('career_path_id', pathId);

      final courseIds =
          (pathCourses as List).map((c) => c['course_id'] as String).toList();

      if (courseIds.isEmpty) {
        return CareerPathProgress(
          pathId: pathId,
          totalCourses: 0,
          completedCourses: 0,
          inProgressCourses: 0,
          progressPercent: 0,
        );
      }

      // Get user's course progress
      final courseProgress = await _supabase
          .from('course_progress')
          .select('course_id, status')
          .eq('user_id', userId)
          .inFilter('course_id', courseIds);

      int completed = 0;
      int inProgress = 0;

      for (final progress in courseProgress as List) {
        if (progress['status'] == 'completed') {
          completed++;
        } else if (progress['status'] == 'in_progress') {
          inProgress++;
        }
      }

      return CareerPathProgress(
        pathId: pathId,
        totalCourses: courseIds.length,
        completedCourses: completed,
        inProgressCourses: inProgress,
        progressPercent:
            courseIds.isNotEmpty ? (completed / courseIds.length) * 100 : 0,
      );
    } catch (e) {
      debugPrint('❌ Error calculating career path progress: $e');
      rethrow;
    }
  }
}

/// Progress within a career path
class CareerPathProgress {
  final String pathId;
  final int totalCourses;
  final int completedCourses;
  final int inProgressCourses;
  final double progressPercent;

  const CareerPathProgress({
    required this.pathId,
    required this.totalCourses,
    required this.completedCourses,
    required this.inProgressCourses,
    required this.progressPercent,
  });

  int get notStartedCourses =>
      totalCourses - completedCourses - inProgressCourses;

  bool get isCompleted => completedCourses == totalCourses && totalCourses > 0;
}
