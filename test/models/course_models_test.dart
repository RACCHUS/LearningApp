import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/course_models.dart';

void main() {
  group('Course Model Tests', () {
    final testCourse = Course(
      id: 'course_001',
      title: 'Test Course',
      description: 'Test Description',
      category: 'Programming',
      difficulty: 'Beginner',
      author: 'Author Name',
      estimatedHours: 10,
      tags: ['dart', 'flutter'],
      skillsAcquired: ['Programming', 'Mobile Development'],
      isPublic: true,
      isFeatured: false,
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 2),
      status: CourseStatus.published,
    );

    test('should create course with all fields', () {
      expect(testCourse.id, 'course_001');
      expect(testCourse.title, 'Test Course');
      expect(testCourse.category, 'Programming');
      expect(testCourse.difficulty, 'Beginner');
      expect(testCourse.estimatedHours, 10);
      expect(testCourse.tags, ['dart', 'flutter']);
      expect(testCourse.status, CourseStatus.published);
    });

    test('should serialize to JSON', () {
      final json = testCourse.toJson();
      
      expect(json['id'], 'course_001');
      expect(json['title'], 'Test Course');
      expect(json['category'], 'Programming');
      expect(json['status'], 'published');
      expect(json['tags'], ['dart', 'flutter']);
      expect(json['createdAt'], isA<String>());
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'course_002',
        'title': 'Another Course',
        'description': 'Description',
        'category': 'Design',
        'difficulty': 'Intermediate',
        'author': 'Author',
        'estimatedHours': 20,
        'tags': ['design'],
        'skillsAcquired': ['UI/UX'],
        'isPublic': false,
        'isFeatured': true,
        'createdAt': '2023-01-01T00:00:00.000Z',
        'updatedAt': '2023-01-02T00:00:00.000Z',
        'status': 'draft',
        'enrollmentCount': 100,
        'rating': 4.5,
        'reviewCount': 50,
      };
      
      final course = Course.fromJson(json);
      
      expect(course.id, 'course_002');
      expect(course.status, CourseStatus.draft);
      expect(course.enrollmentCount, 100);
      expect(course.rating, 4.5);
    });

    test('should create copy with modified fields', () {
      final modified = testCourse.copyWith(
        title: 'Modified Title',
        status: CourseStatus.draft,
      );
      
      expect(modified.title, 'Modified Title');
      expect(modified.status, CourseStatus.draft);
      expect(modified.id, testCourse.id); // Unchanged
    });

    test('should handle equality correctly', () {
      final course1 = Course(
        id: 'same_id',
        title: 'Title',
        description: 'Desc',
        category: 'Cat',
        difficulty: 'Diff',
        author: 'Author',
        estimatedHours: 10,
        tags: [],
        skillsAcquired: [],
        isPublic: true,
        isFeatured: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: CourseStatus.published,
      );
      
      final course2 = Course(
        id: 'same_id',
        title: 'Different Title',
        description: 'Different Desc',
        category: 'Different Cat',
        difficulty: 'Different Diff',
        author: 'Different Author',
        estimatedHours: 20,
        tags: ['different'],
        skillsAcquired: ['different'],
        isPublic: false,
        isFeatured: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: CourseStatus.draft,
      );
      
      // Equality is based on ID only
      expect(course1 == course2, true);
    });
  });

  group('CourseProgress Tests', () {
    test('should create CourseProgress', () {
      final progress = CourseProgress(
        id: 'progress_001',
        userId: 'user_001',
        courseId: 'course_001',
        lessonProgress: {},
        overallProgress: 0.0,
        startedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        totalTimeSpentMinutes: 0,
        status: CourseProgressStatus.notStarted,
      );
      
      expect(progress.id, 'progress_001');
      expect(progress.courseId, 'course_001');
      expect(progress.overallProgress, 0.0);
      expect(progress.status, CourseProgressStatus.notStarted);
    });
  });

  group('LessonProgress Tests', () {
    test('should create LessonProgress', () {
      final progress = LessonProgress(
        lessonId: 'lesson_001',
        progress: 50.0,
        status: LessonProgressStatus.inProgress,
        startedAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
        timeSpentMinutes: 30,
        contentProgress: {},
        attempts: 1,
      );
      
      expect(progress.lessonId, 'lesson_001');
      expect(progress.progress, 50.0);
      expect(progress.status, LessonProgressStatus.inProgress);
      expect(progress.attempts, 1);
    });
  });
}

