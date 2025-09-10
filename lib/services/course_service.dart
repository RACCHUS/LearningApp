import 'dart:math';
import '../models/course_models.dart';
import '../models/lesson.dart';

/// Service for managing courses, lesson series, and course organization
class CourseService {
  
  /// Create a new course
  static Future<Course> createCourse({
    required String title,
    required String description,
    required String category,
    required String difficulty,
    required String author,
    required List<String> tags,
    required List<String> skillsAcquired,
    int estimatedHours = 0,
    bool isPublic = false,
    bool isFeatured = false,
  }) async {
    final course = Course(
      id: _generateId(),
      title: title,
      description: description,
      category: category,
      difficulty: difficulty,
      author: author,
      estimatedHours: estimatedHours,
      tags: tags,
      skillsAcquired: skillsAcquired,
      isPublic: isPublic,
      isFeatured: isFeatured,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: CourseStatus.draft,
    );
    
    // In a real implementation, save to database
    await _saveCourse(course);
    
    return course;
  }

  /// Create a new lesson series within a course
  static Future<LessonSeries> createLessonSeries({
    required String courseId,
    required String title,
    required String description,
    required int seriesOrder,
    required SeriesType type,
    List<String> prerequisites = const [],
    bool isOptional = false,
    int estimatedMinutes = 0,
  }) async {
    final series = LessonSeries(
      id: _generateId(),
      courseId: courseId,
      title: title,
      description: description,
      seriesOrder: seriesOrder,
      lessonIds: [],
      prerequisites: prerequisites,
      isOptional: isOptional,
      type: type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      estimatedMinutes: estimatedMinutes,
    );
    
    // In a real implementation, save to database
    await _saveLessonSeries(series);
    
    return series;
  }

  /// Add lesson to course
  static Future<CourseLessonAssociation> addLessonToCourse({
    required String courseId,
    required String lessonId,
    String? seriesId,
    required int orderInCourse,
    int? orderInSeries,
    bool isRequired = true,
    List<String> prerequisites = const [],
    DateTime? completionDeadline,
  }) async {
    final association = CourseLessonAssociation(
      id: _generateId(),
      courseId: courseId,
      lessonId: lessonId,
      seriesId: seriesId,
      orderInCourse: orderInCourse,
      orderInSeries: orderInSeries,
      isRequired: isRequired,
      prerequisites: prerequisites,
      addedAt: DateTime.now(),
      completionDeadline: completionDeadline,
    );
    
    // Update series if specified
    if (seriesId != null) {
      await _addLessonToSeries(seriesId, lessonId);
    }
    
    // In a real implementation, save to database
    await _saveCourseLessonAssociation(association);
    
    return association;
  }

  /// Get course with all its series and lessons
  static Future<CourseWithContent> getCourseWithContent(String courseId) async {
    final course = await getCourse(courseId);
    final series = await getLessonSeriesForCourse(courseId);
    final associations = await getCourseLessonAssociations(courseId);
    
    // Get all lessons
    final lessonIds = associations.map((a) => a.lessonId).toSet().toList();
    final lessons = await _getLessons(lessonIds);
    
    return CourseWithContent(
      course: course,
      series: series,
      lessons: lessons,
      associations: associations,
    );
  }

  /// Get course by ID
  static Future<Course> getCourse(String courseId) async {
    // In a real implementation, fetch from database
    return _getMockCourse(courseId);
  }

  /// Get all courses
  static Future<List<Course>> getCourses({
    String? category,
    String? difficulty,
    bool? isPublic,
    bool? isFeatured,
    CourseStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    // In a real implementation, fetch from database with filters
    return _getMockCourses();
  }

  /// Get lesson series for a course
  static Future<List<LessonSeries>> getLessonSeriesForCourse(String courseId) async {
    // In a real implementation, fetch from database
    return _getMockLessonSeries(courseId);
  }

  /// Get course-lesson associations
  static Future<List<CourseLessonAssociation>> getCourseLessonAssociations(String courseId) async {
    // In a real implementation, fetch from database
    return _getMockAssociations(courseId);
  }

  /// Update course order
  static Future<void> reorderLessonsInCourse(
    String courseId,
    List<String> lessonIds,
  ) async {
    final associations = await getCourseLessonAssociations(courseId);
    
    for (int i = 0; i < lessonIds.length; i++) {
      final lessonId = lessonIds[i];
      final association = associations.firstWhere((a) => a.lessonId == lessonId);
      
      final updatedAssociation = association.copyWith(
        orderInCourse: i + 1,
      );
      
      await _saveCourseLessonAssociation(updatedAssociation);
    }
  }

  /// Update series order
  static Future<void> reorderLessonsInSeries(
    String seriesId,
    List<String> lessonIds,
  ) async {
    final series = await getLessonSeries(seriesId);
    final updatedSeries = series.copyWith(
      lessonIds: lessonIds,
      updatedAt: DateTime.now(),
    );
    
    await _saveLessonSeries(updatedSeries);
    
    // Update associations
    for (int i = 0; i < lessonIds.length; i++) {
      final lessonId = lessonIds[i];
      final associations = await _getAssociationsForLesson(lessonId);
      
      for (final association in associations) {
        if (association.seriesId == seriesId) {
          final updated = association.copyWith(orderInSeries: i + 1);
          await _saveCourseLessonAssociation(updated);
        }
      }
    }
  }

  /// Get lesson series by ID
  static Future<LessonSeries> getLessonSeries(String seriesId) async {
    // In a real implementation, fetch from database
    final series = _getMockLessonSeries('').firstWhere((s) => s.id == seriesId);
    return series;
  }

  /// Remove lesson from course
  static Future<void> removeLessonFromCourse(String courseId, String lessonId) async {
    // Remove association
    final associations = await getCourseLessonAssociations(courseId);
    final association = associations.firstWhere((a) => a.lessonId == lessonId);
    await _deleteCourseLessonAssociation(association.id);
    
    // Remove from series if applicable
    if (association.seriesId != null) {
      await _removeLessonFromSeries(association.seriesId!, lessonId);
    }
    
    // Reorder remaining lessons
    final remainingAssociations = associations.where((a) => a.lessonId != lessonId).toList();
    remainingAssociations.sort((a, b) => a.orderInCourse.compareTo(b.orderInCourse));
    
    for (int i = 0; i < remainingAssociations.length; i++) {
      final updated = remainingAssociations[i].copyWith(orderInCourse: i + 1);
      await _saveCourseLessonAssociation(updated);
    }
  }

  /// Delete course
  static Future<void> deleteCourse(String courseId) async {
    // Delete all associations
    final associations = await getCourseLessonAssociations(courseId);
    for (final association in associations) {
      await _deleteCourseLessonAssociation(association.id);
    }
    
    // Delete all series
    final series = await getLessonSeriesForCourse(courseId);
    for (final s in series) {
      await _deleteLessonSeries(s.id);
    }
    
    // Delete course
    await _deleteCourse(courseId);
  }

  /// Update course
  static Future<Course> updateCourse(Course course) async {
    final updatedCourse = course.copyWith(updatedAt: DateTime.now());
    await _saveCourse(updatedCourse);
    return updatedCourse;
  }

  /// Publish course
  static Future<Course> publishCourse(String courseId) async {
    final course = await getCourse(courseId);
    
    // Validate course is ready for publishing
    final validation = await validateCourseForPublishing(courseId);
    if (!validation.isValid) {
      throw CourseValidationException(validation.errors);
    }
    
    final publishedCourse = course.copyWith(
      status: CourseStatus.published,
      updatedAt: DateTime.now(),
    );
    
    await _saveCourse(publishedCourse);
    return publishedCourse;
  }

  /// Validate course for publishing
  static Future<CourseValidationResult> validateCourseForPublishing(String courseId) async {
    final errors = <String>[];
    final warnings = <String>[];
    
    final course = await getCourse(courseId);
    final associations = await getCourseLessonAssociations(courseId);
    
    // Check course metadata
    if (course.title.length < 10) {
      errors.add('Course title must be at least 10 characters');
    }
    
    if (course.description.length < 50) {
      errors.add('Course description must be at least 50 characters');
    }
    
    if (course.tags.isEmpty) {
      warnings.add('Consider adding tags to improve discoverability');
    }
    
    if (course.skillsAcquired.isEmpty) {
      warnings.add('Consider adding skills that learners will acquire');
    }
    
    // Check lesson content
    if (associations.isEmpty) {
      errors.add('Course must contain at least one lesson');
    } else if (associations.length < 3) {
      warnings.add('Consider adding more lessons for a comprehensive course');
    }
    
    // Check lesson ordering
    final orders = associations.map((a) => a.orderInCourse).toList();
    orders.sort();
    for (int i = 0; i < orders.length; i++) {
      if (orders[i] != i + 1) {
        errors.add('Lesson ordering is inconsistent');
        break;
      }
    }
    
    return CourseValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Get course analytics
  static Future<CourseAnalytics> getCourseAnalytics(String courseId) async {
    // In a real implementation, this would calculate from user progress data
    return CourseAnalytics(
      courseId: courseId,
      totalEnrollments: Random().nextInt(1000) + 100,
      completionRate: Random().nextDouble() * 0.4 + 0.6, // 60-100%
      averageRating: Random().nextDouble() * 2 + 3, // 3-5 stars
      averageCompletionTime: Random().nextInt(10) + 5, // 5-15 hours
      dropoffPoints: _generateMockDropoffPoints(),
      popularLessons: _generateMockPopularLessons(),
      engagementMetrics: _generateMockEngagementMetrics(),
    );
  }

  // Private helper methods
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString().padLeft(3, '0');
  }

  static Future<void> _saveCourse(Course course) async {
    // In a real implementation, save to database/API
    print('Saving course: ${course.title}');
  }

  static Future<void> _saveLessonSeries(LessonSeries series) async {
    // In a real implementation, save to database/API
    print('Saving lesson series: ${series.title}');
  }

  static Future<void> _saveCourseLessonAssociation(CourseLessonAssociation association) async {
    // In a real implementation, save to database/API
    print('Saving course-lesson association: ${association.id}');
  }

  static Future<void> _addLessonToSeries(String seriesId, String lessonId) async {
    // In a real implementation, update series in database
    print('Adding lesson $lessonId to series $seriesId');
  }

  static Future<void> _removeLessonFromSeries(String seriesId, String lessonId) async {
    // In a real implementation, update series in database
    print('Removing lesson $lessonId from series $seriesId');
  }

  static Future<void> _deleteCourseLessonAssociation(String associationId) async {
    // In a real implementation, delete from database
    print('Deleting association: $associationId');
  }

  static Future<void> _deleteLessonSeries(String seriesId) async {
    // In a real implementation, delete from database
    print('Deleting series: $seriesId');
  }

  static Future<void> _deleteCourse(String courseId) async {
    // In a real implementation, delete from database
    print('Deleting course: $courseId');
  }

  static Future<List<Lesson>> _getLessons(List<String> lessonIds) async {
    // In a real implementation, fetch lessons from database
    return lessonIds.map((id) => _getMockLesson(id)).toList();
  }

  static Future<List<CourseLessonAssociation>> _getAssociationsForLesson(String lessonId) async {
    // In a real implementation, fetch from database
    return []; // Mock implementation
  }

  // Mock data generators
  static Course _getMockCourse(String courseId) {
    return Course(
      id: courseId,
      title: 'Complete Web Development Bootcamp',
      description: 'Learn modern web development from scratch with hands-on projects and real-world applications.',
      category: 'Programming',
      difficulty: 'intermediate',
      author: 'instructor_001',
      estimatedHours: 40,
      tags: ['web-development', 'javascript', 'react', 'node.js'],
      skillsAcquired: ['HTML/CSS', 'JavaScript', 'React', 'Node.js', 'Database Design'],
      isPublic: true,
      isFeatured: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      status: CourseStatus.published,
      enrollmentCount: 245,
      rating: 4.6,
      reviewCount: 89,
    );
  }

  static List<Course> _getMockCourses() {
    return [
      Course(
        id: 'course_001',
        title: 'Complete Web Development Bootcamp',
        description: 'Learn modern web development from scratch',
        category: 'Programming',
        difficulty: 'intermediate',
        author: 'instructor_001',
        estimatedHours: 40,
        tags: ['web-development', 'javascript'],
        skillsAcquired: ['HTML/CSS', 'JavaScript'],
        isPublic: true,
        isFeatured: true,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        status: CourseStatus.published,
        enrollmentCount: 245,
        rating: 4.6,
        reviewCount: 89,
      ),
      Course(
        id: 'course_002',
        title: 'Data Science with Python',
        description: 'Master data science concepts and tools',
        category: 'Data Science',
        difficulty: 'advanced',
        author: 'instructor_002',
        estimatedHours: 60,
        tags: ['python', 'data-science', 'machine-learning'],
        skillsAcquired: ['Python', 'Pandas', 'NumPy', 'Scikit-learn'],
        isPublic: true,
        isFeatured: false,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 10)),
        status: CourseStatus.published,
        enrollmentCount: 178,
        rating: 4.8,
        reviewCount: 67,
      ),
    ];
  }

  static List<LessonSeries> _getMockLessonSeries(String courseId) {
    return [
      LessonSeries(
        id: 'series_001',
        courseId: courseId,
        title: 'HTML & CSS Fundamentals',
        description: 'Learn the basics of web markup and styling',
        seriesOrder: 1,
        lessonIds: ['lesson_001', 'lesson_002', 'lesson_003'],
        prerequisites: [],
        isOptional: false,
        type: SeriesType.sequential,
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        estimatedMinutes: 180,
      ),
      LessonSeries(
        id: 'series_002',
        courseId: courseId,
        title: 'JavaScript Essentials',
        description: 'Master JavaScript programming concepts',
        seriesOrder: 2,
        lessonIds: ['lesson_004', 'lesson_005', 'lesson_006'],
        prerequisites: ['series_001'],
        isOptional: false,
        type: SeriesType.sequential,
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        estimatedMinutes: 240,
      ),
    ];
  }

  static List<CourseLessonAssociation> _getMockAssociations(String courseId) {
    return [
      CourseLessonAssociation(
        id: 'assoc_001',
        courseId: courseId,
        lessonId: 'lesson_001',
        seriesId: 'series_001',
        orderInCourse: 1,
        orderInSeries: 1,
        isRequired: true,
        prerequisites: [],
        addedAt: DateTime.now().subtract(const Duration(days: 25)),
      ),
      CourseLessonAssociation(
        id: 'assoc_002',
        courseId: courseId,
        lessonId: 'lesson_002',
        seriesId: 'series_001',
        orderInCourse: 2,
        orderInSeries: 2,
        isRequired: true,
        prerequisites: ['lesson_001'],
        addedAt: DateTime.now().subtract(const Duration(days: 24)),
      ),
    ];
  }

  static Lesson _getMockLesson(String lessonId) {
    // This would typically come from the lesson service
    return Lesson(
      id: lessonId,
      title: 'Sample Lesson',
      description: 'A sample lesson for demonstration',
      userId: 'instructor_001',
      tags: ['sample'],
      terms: [],
      questions: [],
      concepts: [],
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    );
  }

  static List<DropoffPoint> _generateMockDropoffPoints() {
    return [
      DropoffPoint(lessonId: 'lesson_003', dropoffRate: 0.15),
      DropoffPoint(lessonId: 'lesson_006', dropoffRate: 0.22),
      DropoffPoint(lessonId: 'lesson_009', dropoffRate: 0.18),
    ];
  }

  static List<PopularLesson> _generateMockPopularLessons() {
    return [
      PopularLesson(lessonId: 'lesson_001', completionRate: 0.95, averageRating: 4.8),
      PopularLesson(lessonId: 'lesson_004', completionRate: 0.87, averageRating: 4.6),
      PopularLesson(lessonId: 'lesson_007', completionRate: 0.92, averageRating: 4.7),
    ];
  }

  static EngagementMetrics _generateMockEngagementMetrics() {
    return EngagementMetrics(
      averageSessionDuration: 45.3,
      averageLessonsPerSession: 2.1,
      weeklyActiveUsers: 156,
      monthlyActiveUsers: 423,
    );
  }
}

// Additional data models for course organization
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
}

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

class CourseValidationException implements Exception {
  final List<String> errors;
  CourseValidationException(this.errors);
  
  @override
  String toString() => 'Course validation failed: ${errors.join(', ')}';
}

class CourseAnalytics {
  final String courseId;
  final int totalEnrollments;
  final double completionRate;
  final double averageRating;
  final int averageCompletionTime;
  final List<DropoffPoint> dropoffPoints;
  final List<PopularLesson> popularLessons;
  final EngagementMetrics engagementMetrics;

  CourseAnalytics({
    required this.courseId,
    required this.totalEnrollments,
    required this.completionRate,
    required this.averageRating,
    required this.averageCompletionTime,
    required this.dropoffPoints,
    required this.popularLessons,
    required this.engagementMetrics,
  });
}

class DropoffPoint {
  final String lessonId;
  final double dropoffRate;

  DropoffPoint({required this.lessonId, required this.dropoffRate});
}

class PopularLesson {
  final String lessonId;
  final double completionRate;
  final double averageRating;

  PopularLesson({
    required this.lessonId,
    required this.completionRate,
    required this.averageRating,
  });
}

class EngagementMetrics {
  final double averageSessionDuration;
  final double averageLessonsPerSession;
  final int weeklyActiveUsers;
  final int monthlyActiveUsers;

  EngagementMetrics({
    required this.averageSessionDuration,
    required this.averageLessonsPerSession,
    required this.weeklyActiveUsers,
    required this.monthlyActiveUsers,
  });
}
