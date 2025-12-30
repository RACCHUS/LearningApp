import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course_models.dart';
import '../models/lesson.dart';
import 'lesson_service.dart';

/// Service for managing courses, lesson associations, and course organization
/// 
/// This service provides real Supabase database operations for:
/// - Creating, reading, updating, deleting courses
/// - Managing course-lesson associations
/// - Course progress tracking
class CourseService {
  final SupabaseClient _supabase;
  final LessonService _lessonService;

  CourseService({
    SupabaseClient? supabase,
    LessonService? lessonService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _lessonService = lessonService ?? LessonService();

  // ============================================================================
  // COURSE CRUD OPERATIONS
  // ============================================================================

  /// Create a new course
  Future<Course> createCourse({
    required String title,
    required String description,
    String? category,
    String difficulty = 'beginner',
    List<String> tags = const [],
    String? imageUrl,
    bool isPublic = false,
    int estimatedHours = 0,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated to create a course');
      }

      final data = {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'difficulty': difficulty,
        'tags': tags,
        'image_url': imageUrl,
        'is_public': isPublic,
        'estimated_hours': estimatedHours,
        'status': 'draft',
      };

      final response = await _supabase
          .from('courses')
          .insert(data)
          .select()
          .single();

      debugPrint('✅ Course created: ${response['id']}');
      return _courseFromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating course: $e');
      rethrow;
    }
  }

  /// Get a course by ID
  Future<Course> getCourse(String courseId) async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('id', courseId)
          .single();

      return _courseFromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching course: $e');
      rethrow;
    }
  }

  /// Get all courses for the current user
  Future<List<Course>> getUserCourses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('courses')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (response as List).map((c) => _courseFromJson(c)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching user courses: $e');
      rethrow;
    }
  }

  /// Get all courses with optional filters
  Future<List<Course>> getCourses({
    String? category,
    String? difficulty,
    bool? isPublic,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('courses').select();

      if (category != null) {
        query = query.eq('category', category);
      }
      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }
      if (isPublic != null) {
        query = query.eq('is_public', isPublic);
      }
      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((c) => _courseFromJson(c)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching courses: $e');
      rethrow;
    }
  }

  /// Update a course
  Future<Course> updateCourse(Course course) async {
    try {
      final data = {
        'title': course.title,
        'description': course.description,
        'category': course.category,
        'difficulty': course.difficulty,
        'tags': course.tags,
        'image_url': course.imageUrl,
        'is_public': course.isPublic,
        'estimated_hours': course.estimatedHours,
        'status': course.status.name,
      };

      final response = await _supabase
          .from('courses')
          .update(data)
          .eq('id', course.id)
          .select()
          .single();

      debugPrint('✅ Course updated: ${course.id}');
      return _courseFromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating course: $e');
      rethrow;
    }
  }

  /// Delete a course
  Future<void> deleteCourse(String courseId) async {
    try {
      await _supabase.from('courses').delete().eq('id', courseId);
      debugPrint('✅ Course deleted: $courseId');
    } catch (e) {
      debugPrint('❌ Error deleting course: $e');
      rethrow;
    }
  }

  // ============================================================================
  // COURSE-LESSON ASSOCIATIONS
  // ============================================================================

  /// Add a lesson to a course
  Future<CourseLessonAssociation> addLessonToCourse({
    required String courseId,
    required String lessonId,
    int? orderIndex,
    bool isRequired = true,
    String? sectionTitle,
  }) async {
    try {
      // Get current max order if not specified
      if (orderIndex == null) {
        final existing = await getCourseLessons(courseId);
        orderIndex = existing.isEmpty ? 0 : existing.length;
      }

      final data = {
        'course_id': courseId,
        'lesson_id': lessonId,
        'order_index': orderIndex,
        'is_required': isRequired,
        'section_title': sectionTitle,
      };

      final response = await _supabase
          .from('course_lessons')
          .insert(data)
          .select()
          .single();

      debugPrint('✅ Lesson added to course: $lessonId -> $courseId');
      return _associationFromJson(response);
    } catch (e) {
      debugPrint('❌ Error adding lesson to course: $e');
      rethrow;
    }
  }

  /// Get all lesson associations for a course
  Future<List<CourseLessonAssociation>> getCourseLessons(String courseId) async {
    try {
      final response = await _supabase
          .from('course_lessons')
          .select()
          .eq('course_id', courseId)
          .order('order_index');

      return (response as List).map((a) => _associationFromJson(a)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching course lessons: $e');
      rethrow;
    }
  }

  /// Get course with all its lessons
  Future<CourseWithContent> getCourseWithContent(String courseId) async {
    try {
      final course = await getCourse(courseId);
      final associations = await getCourseLessons(courseId);

      // Fetch all lessons
      final lessons = <Lesson>[];
      for (final assoc in associations) {
        try {
          final lesson = await _lessonService.getLesson(assoc.lessonId);
          lessons.add(lesson);
        } catch (e) {
          debugPrint('⚠️ Could not fetch lesson ${assoc.lessonId}: $e');
        }
      }

      return CourseWithContent(
        course: course,
        series: [], // Series not implemented in current schema
        lessons: lessons,
        associations: associations,
      );
    } catch (e) {
      debugPrint('❌ Error fetching course with content: $e');
      rethrow;
    }
  }

  /// Remove a lesson from a course
  Future<void> removeLessonFromCourse(String courseId, String lessonId) async {
    try {
      await _supabase
          .from('course_lessons')
          .delete()
          .eq('course_id', courseId)
          .eq('lesson_id', lessonId);

      debugPrint('✅ Lesson removed from course: $lessonId from $courseId');

      // Reorder remaining lessons
      await _reorderAfterRemoval(courseId);
    } catch (e) {
      debugPrint('❌ Error removing lesson from course: $e');
      rethrow;
    }
  }

  /// Reorder lessons in a course
  Future<void> reorderLessonsInCourse(
    String courseId,
    List<String> lessonIds,
  ) async {
    try {
      for (int i = 0; i < lessonIds.length; i++) {
        await _supabase
            .from('course_lessons')
            .update({'order_index': i})
            .eq('course_id', courseId)
            .eq('lesson_id', lessonIds[i]);
      }
      debugPrint('✅ Course lessons reordered');
    } catch (e) {
      debugPrint('❌ Error reordering lessons: $e');
      rethrow;
    }
  }

  /// Update lesson section title
  Future<void> updateLessonSection(
    String courseId,
    String lessonId,
    String? sectionTitle,
  ) async {
    try {
      await _supabase
          .from('course_lessons')
          .update({'section_title': sectionTitle})
          .eq('course_id', courseId)
          .eq('lesson_id', lessonId);
      debugPrint('✅ Lesson section updated');
    } catch (e) {
      debugPrint('❌ Error updating lesson section: $e');
      rethrow;
    }
  }

  // ============================================================================
  // COURSE PROGRESS
  // ============================================================================

  /// Get or create course progress for current user
  Future<CourseProgress> getCourseProgress(String courseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      // Try to get existing progress
      final response = await _supabase
          .from('course_progress')
          .select()
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle();

      if (response != null) {
        return _progressFromJson(response);
      }

      // Create new progress record
      final associations = await getCourseLessons(courseId);
      final newProgress = {
        'user_id': userId,
        'course_id': courseId,
        'lessons_completed': 0,
        'total_lessons': associations.length,
        'status': 'not_started',
      };

      final created = await _supabase
          .from('course_progress')
          .insert(newProgress)
          .select()
          .single();

      return _progressFromJson(created);
    } catch (e) {
      debugPrint('❌ Error getting course progress: $e');
      rethrow;
    }
  }

  /// Update course progress
  Future<CourseProgress> updateCourseProgress({
    required String courseId,
    int? lessonsCompleted,
    String? status,
    int? additionalMinutes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      final updates = <String, dynamic>{
        'last_accessed_at': DateTime.now().toIso8601String(),
      };

      if (lessonsCompleted != null) {
        updates['lessons_completed'] = lessonsCompleted;
      }
      if (status != null) {
        updates['status'] = status;
        if (status == 'in_progress') {
          updates['started_at'] = DateTime.now().toIso8601String();
        } else if (status == 'completed') {
          updates['completed_at'] = DateTime.now().toIso8601String();
        }
      }

      final response = await _supabase
          .from('course_progress')
          .update(updates)
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .select()
          .single();

      // Handle time increment separately if needed
      if (additionalMinutes != null && additionalMinutes > 0) {
        await _supabase.rpc('increment_course_time', params: {
          'p_user_id': userId,
          'p_course_id': courseId,
          'p_minutes': additionalMinutes,
        });
      }

      return _progressFromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating course progress: $e');
      rethrow;
    }
  }

  /// Get all course progress for current user
  Future<List<CourseProgress>> getAllCourseProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('course_progress')
          .select()
          .eq('user_id', userId)
          .order('last_accessed_at', ascending: false);

      return (response as List).map((p) => _progressFromJson(p)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all course progress: $e');
      rethrow;
    }
  }

  // ============================================================================
  // COURSE PUBLISHING & VALIDATION
  // ============================================================================

  /// Publish a course (make it public)
  Future<Course> publishCourse(String courseId) async {
    final validation = await validateCourseForPublishing(courseId);
    if (!validation.isValid) {
      throw CourseValidationException(validation.errors);
    }

    final course = await getCourse(courseId);
    return updateCourse(course.copyWith(
      status: CourseStatus.published,
      isPublic: true,
    ));
  }

  /// Archive a course
  Future<Course> archiveCourse(String courseId) async {
    final course = await getCourse(courseId);
    return updateCourse(course.copyWith(
      status: CourseStatus.archived,
    ));
  }

  /// Validate course for publishing
  Future<CourseValidationResult> validateCourseForPublishing(String courseId) async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      final course = await getCourse(courseId);
      final associations = await getCourseLessons(courseId);

      // Check course metadata
      if (course.title.length < 5) {
        errors.add('Course title must be at least 5 characters');
      }
      if (course.description.isEmpty) {
        errors.add('Course description is required');
      }
      if (course.tags.isEmpty) {
        warnings.add('Consider adding tags to improve discoverability');
      }

      // Check lesson content
      if (associations.isEmpty) {
        errors.add('Course must contain at least one lesson');
      } else if (associations.length < 2) {
        warnings.add('Consider adding more lessons for a comprehensive course');
      }

      return CourseValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      return CourseValidationResult(
        isValid: false,
        errors: ['Failed to validate course: $e'],
        warnings: [],
      );
    }
  }

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  Future<void> _reorderAfterRemoval(String courseId) async {
    final remaining = await getCourseLessons(courseId);
    for (int i = 0; i < remaining.length; i++) {
      if (remaining[i].orderInCourse != i) {
        await _supabase
            .from('course_lessons')
            .update({'order_index': i})
            .eq('id', remaining[i].id);
      }
    }
  }

  Course _courseFromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'beginner',
      author: json['user_id'] ?? '',
      estimatedHours: json['estimated_hours'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      skillsAcquired: [], // Not in current schema
      isPublic: json['is_public'] ?? false,
      isFeatured: false, // Not in current schema
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      imageUrl: json['image_url'],
      status: CourseStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CourseStatus.draft,
      ),
    );
  }

  CourseLessonAssociation _associationFromJson(Map<String, dynamic> json) {
    return CourseLessonAssociation(
      id: json['id'],
      courseId: json['course_id'],
      lessonId: json['lesson_id'],
      seriesId: null, // Not in current schema
      orderInCourse: json['order_index'] ?? 0,
      orderInSeries: null,
      isRequired: json['is_required'] ?? true,
      prerequisites: [],
      addedAt: DateTime.parse(json['added_at']),
      metadata: {'section_title': json['section_title']},
    );
  }

  CourseProgress _progressFromJson(Map<String, dynamic> json) {
    return CourseProgress(
      id: json['id'],
      courseId: json['course_id'],
      userId: json['user_id'],
      lessonProgress: {},
      overallProgress: json['total_lessons'] > 0
          ? json['lessons_completed'] / json['total_lessons']
          : 0.0,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      lastAccessedAt: DateTime.parse(json['last_accessed_at']),
      totalTimeSpentMinutes: json['total_time_minutes'] ?? 0,
      status: CourseProgressStatus.values.firstWhere(
        (s) => s.name == json['status']?.replaceAll('_', ''),
        orElse: () => CourseProgressStatus.notStarted,
      ),
    );
  }
}

// ============================================================================
// SUPPORTING CLASSES
// ============================================================================

/// Course with all its content loaded
class CourseWithContent {
  final Course course;
  final List<LessonSeries> series;
  final List<Lesson> lessons;
  final List<CourseLessonAssociation> associations;

  CourseWithContent({
    required this.course,
    required this.series,
    required this.lessons,
    required this.associations,
  });

  /// Get lessons in order
  List<Lesson> get orderedLessons {
    final ordered = <Lesson>[];
    final sortedAssocs = List<CourseLessonAssociation>.from(associations)
      ..sort((a, b) => a.orderInCourse.compareTo(b.orderInCourse));
    
    for (final assoc in sortedAssocs) {
      final lesson = lessons.firstWhere(
        (l) => l.id == assoc.lessonId,
        orElse: () => throw Exception('Lesson not found: ${assoc.lessonId}'),
      );
      ordered.add(lesson);
    }
    return ordered;
  }

  /// Get lessons grouped by section
  Map<String?, List<Lesson>> get lessonsBySection {
    final grouped = <String?, List<Lesson>>{};
    final sortedAssocs = List<CourseLessonAssociation>.from(associations)
      ..sort((a, b) => a.orderInCourse.compareTo(b.orderInCourse));
    
    for (final assoc in sortedAssocs) {
      final sectionTitle = assoc.metadata?['section_title'] as String?;
      final lesson = lessons.firstWhere((l) => l.id == assoc.lessonId);
      grouped.putIfAbsent(sectionTitle, () => []).add(lesson);
    }
    return grouped;
  }
}

/// Result of course validation
class CourseValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  CourseValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}

/// Exception thrown when course validation fails
class CourseValidationException implements Exception {
  final List<String> errors;
  CourseValidationException(this.errors);

  @override
  String toString() => 'Course validation failed: ${errors.join(', ')}';
}
