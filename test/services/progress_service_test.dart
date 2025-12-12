import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/services/progress_service.dart';

void main() {
  const userId = 'test-user';
  const courseId = 'course-123';

  group('ProgressService', () {
    test('enrollInCourse initializes course progress', () async {
      final progress = await ProgressService.enrollInCourse(
        userId: userId,
        courseId: courseId,
      );

      expect(progress.userId, userId);
      expect(progress.courseId, courseId);
      expect(progress.lessonProgress, isEmpty);
      expect(progress.overallProgress, 0.0);
      expect(progress.status, CourseProgressStatus.notStarted);
    });

    test('startLesson creates in-progress lesson entry', () async {
      final lessonProgress = await ProgressService.startLesson(
        userId: userId,
        lessonId: 'lesson-001',
        courseId: courseId,
      );

      expect(lessonProgress.status, LessonProgressStatus.inProgress);
      expect(lessonProgress.progress, 0.0);
      expect(lessonProgress.attempts, 1);
    });

    test('updateLessonProgress marks lesson completed at 100%', () async {
      final updated = await ProgressService.updateLessonProgress(
        userId: userId,
        lessonId: 'lesson-new',
        courseId: courseId,
        progressPercentage: 100.0,
        timeSpentMinutes: 15,
        contentProgress: const {'intro': true},
      );

      expect(updated.status, LessonProgressStatus.completed);
      expect(updated.progress, 100.0);
      expect(updated.timeSpentMinutes, 15);
      expect(updated.contentProgress['intro'], isTrue);
    });

    test('getLearningStreak returns non-negative streak values', () async {
      final streak = await ProgressService.getLearningStreak(userId);

      expect(streak.currentStreak, greaterThanOrEqualTo(0));
      expect(streak.longestStreak, greaterThanOrEqualTo(streak.currentStreak));
    });

    test('getProgressSummary aggregates analytics safely', () async {
      final summary = await ProgressService.getProgressSummary(userId);

      expect(summary.totalCourses, greaterThanOrEqualTo(0));
      expect(summary.averageScore, inInclusiveRange(0, 100));
      expect(summary.completedCourses, greaterThanOrEqualTo(0));
      expect(summary.inProgressCourses, greaterThanOrEqualTo(0));
    });
  });
}

