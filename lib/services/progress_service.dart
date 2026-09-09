import 'dart:math';
import '../models/course_models.dart';

/// Service for managing user progress in courses and lessons
class ProgressService {
  
  /// Start course enrollment for a user
  static Future<CourseProgress> enrollInCourse({
    required String userId,
    required String courseId,
  }) async {
    final progress = CourseProgress(
      id: _generateId(),
      userId: userId,
      courseId: courseId,
      lessonProgress: {},
      overallProgress: 0.0,
      startedAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
      totalTimeSpentMinutes: 0,
      status: CourseProgressStatus.notStarted,
    );
    
    await _saveCourseProgress(progress);
    return progress;
  }

  /// Get course progress for a user
  static Future<CourseProgress?> getCourseProgress(String userId, String courseId) async {
    // In a real implementation, fetch from database
    return _getMockCourseProgress(userId, courseId);
  }

  /// Get all course progress for a user
  static Future<List<CourseProgress>> getUserCourseProgress(String userId) async {
    // In a real implementation, fetch from database
    return _getMockUserProgress(userId);
  }

  /// Start a lesson for a user
  static Future<LessonProgress> startLesson({
    required String userId,
    required String lessonId,
    required String courseId,
  }) async {
    final progress = LessonProgress(
      lessonId: lessonId,
      progress: 0.0,
      status: LessonProgressStatus.inProgress,
      startedAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
      timeSpentMinutes: 0,
      contentProgress: {},
      attempts: 1,
    );
    
    await _updateCourseProgressWithLessonProgress(userId, courseId, progress);
    
    return progress;
  }

  /// Update lesson progress
  static Future<LessonProgress> updateLessonProgress({
    required String userId,
    required String lessonId,
    required String courseId,
    required double progressPercentage,
    Map<String, dynamic> contentProgress = const {},
    double? score,
    int? timeSpentMinutes,
  }) async {
    final existingProgress = await getLessonProgress(userId, lessonId, courseId);
    
    final updatedProgress = LessonProgress(
      lessonId: lessonId,
      progress: progressPercentage,
      status: progressPercentage >= 100.0 
          ? LessonProgressStatus.completed
          : LessonProgressStatus.inProgress,
      startedAt: existingProgress.startedAt,
      completedAt: progressPercentage >= 100.0 ? DateTime.now() : null,
      lastAccessedAt: DateTime.now(),
      timeSpentMinutes: timeSpentMinutes ?? existingProgress.timeSpentMinutes,
      contentProgress: contentProgress.isNotEmpty ? contentProgress : existingProgress.contentProgress,
      score: score,
      attempts: existingProgress.attempts,
    );
    
    await _updateCourseProgressWithLessonProgress(userId, courseId, updatedProgress);
    
    return updatedProgress;
  }

  /// Complete a lesson
  static Future<LessonProgress> completeLesson({
    required String userId,
    required String lessonId,
    required String courseId,
    double? finalScore,
    int? timeSpent,
  }) async {
    return await updateLessonProgress(
      userId: userId,
      lessonId: lessonId,
      courseId: courseId,
      progressPercentage: 100.0,
      score: finalScore,
      timeSpentMinutes: timeSpent,
    );
  }

  /// Get lesson progress
  static Future<LessonProgress> getLessonProgress(
    String userId, 
    String lessonId, 
    String courseId,
  ) async {
    final courseProgress = await getCourseProgress(userId, courseId);
    if (courseProgress?.lessonProgress.containsKey(lessonId) == true) {
      return courseProgress!.lessonProgress[lessonId]!;
    }
    
    // Return default progress if not found
    return LessonProgress(
      lessonId: lessonId,
      progress: 0.0,
      status: LessonProgressStatus.notStarted,
      lastAccessedAt: DateTime.now(),
      timeSpentMinutes: 0,
      contentProgress: {},
      attempts: 0,
    );
  }

  /// Get all lesson progress for a course
  static Future<List<LessonProgress>> getCourseLessonProgress(
    String userId, 
    String courseId,
  ) async {
    final courseProgress = await getCourseProgress(userId, courseId);
    return courseProgress?.lessonProgress.values.toList() ?? [];
  }

  /// Calculate overall course progress
  static Future<double> calculateCourseProgress(String userId, String courseId) async {
    final lessonProgresses = await getCourseLessonProgress(userId, courseId);
    
    if (lessonProgresses.isEmpty) return 0.0;
    
    final totalProgress = lessonProgresses
        .map((p) => p.progress)
        .fold(0.0, (a, b) => a + b);
    
    return totalProgress / lessonProgresses.length;
  }

  /// Get learning streak for user
  static Future<LearningStreak> getLearningStreak(String userId) async {
    final progresses = await getUserCourseProgress(userId);
    
    // Calculate streak based on daily activity
    final now = DateTime.now();
    int currentStreak = 0;
    int longestStreak = 0;
    DateTime? lastActivity;
    
    // This is a simplified calculation - in real implementation,
    // you'd track daily activity more precisely
    for (final progress in progresses) {
      final daysDiff = now.difference(progress.lastAccessedAt).inDays;
      if (daysDiff == 0) {
        currentStreak++;
      }
      
      if (lastActivity == null || progress.lastAccessedAt.isAfter(lastActivity)) {
        lastActivity = progress.lastAccessedAt;
      }
    }
    
    // Mock longest streak calculation
    longestStreak = max(currentStreak, Random().nextInt(30) + currentStreak);
    
    return LearningStreak(
      userId: userId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastActivityDate: lastActivity,
    );
  }

  /// Get learning analytics for user
  static Future<UserLearningAnalytics> getUserAnalytics(String userId) async {
    final courseProgresses = await getUserCourseProgress(userId);
    final streak = await getLearningStreak(userId);
    
    final completedCourses = courseProgresses
        .where((p) => p.status == CourseProgressStatus.completed)
        .length;
    
    final inProgressCourses = courseProgresses
        .where((p) => p.status == CourseProgressStatus.inProgress)
        .length;
    
    final totalTimeSpent = courseProgresses
        .map((p) => p.totalTimeSpentMinutes)
        .fold(0, (a, b) => a + b);
    
    final averageScore = _calculateAverageScore(courseProgresses);
    
    return UserLearningAnalytics(
      userId: userId,
      totalCoursesEnrolled: courseProgresses.length,
      completedCourses: completedCourses,
      inProgressCourses: inProgressCourses,
      totalTimeSpentMinutes: totalTimeSpent,
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      averageScore: averageScore,
      coursesCompletedThisMonth: _calculateMonthlyCompletions(courseProgresses),
      skillsAcquired: _calculateSkillsAcquired(courseProgresses),
      achievements: _calculateAchievements(courseProgresses, streak),
    );
  }

  /// Reset lesson progress (for retakes)
  static Future<LessonProgress> resetLessonProgress({
    required String userId,
    required String lessonId,
    required String courseId,
  }) async {
    final existingProgress = await getLessonProgress(userId, lessonId, courseId);
    
    final resetProgress = LessonProgress(
      lessonId: lessonId,
      progress: 0.0,
      status: LessonProgressStatus.notStarted,
      startedAt: null,
      completedAt: null,
      lastAccessedAt: DateTime.now(),
      timeSpentMinutes: 0,
      contentProgress: {},
      score: null,
      attempts: existingProgress.attempts + 1,
    );
    
    await _updateCourseProgressWithLessonProgress(userId, courseId, resetProgress);
    return resetProgress;
  }

  /// Get progress summary for dashboard
  static Future<ProgressSummary> getProgressSummary(String userId) async {
    final analytics = await getUserAnalytics(userId);
    final courseProgresses = await getUserCourseProgress(userId);
    
    final recentActivity = courseProgresses
        .where((p) => DateTime.now().difference(p.lastAccessedAt).inDays <= 7)
        .length;
    
    final upcomingDeadlines = _getUpcomingDeadlines(courseProgresses);
    
    return ProgressSummary(
      totalCourses: analytics.totalCoursesEnrolled,
      completedCourses: analytics.completedCourses,
      inProgressCourses: analytics.inProgressCourses,
      currentStreak: analytics.currentStreak,
      totalTimeSpent: analytics.totalTimeSpentMinutes,
      recentActivity: recentActivity,
      upcomingDeadlines: upcomingDeadlines.length,
      averageScore: analytics.averageScore,
    );
  }

  // Private helper methods
  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(1000).toString().padLeft(3, '0');
  }

  static Future<void> _saveCourseProgress(CourseProgress progress) async {
    // In a real implementation, save to database
    print('Saving course progress: ${progress.id}');
  }

  static Future<void> _updateCourseProgressWithLessonProgress(
    String userId, 
    String courseId, 
    LessonProgress lessonProgress,
  ) async {
    final courseProgress = await getCourseProgress(userId, courseId);
    if (courseProgress != null) {
      final updatedLessonProgress = Map<String, LessonProgress>.from(courseProgress.lessonProgress);
      updatedLessonProgress[lessonProgress.lessonId] = lessonProgress;
      
      final overallProgress = await calculateCourseProgress(userId, courseId);
      
      final updatedCourseProgress = CourseProgress(
        id: courseProgress.id,
        courseId: courseId,
        userId: userId,
        lessonProgress: updatedLessonProgress,
        overallProgress: overallProgress,
        startedAt: courseProgress.startedAt,
        completedAt: overallProgress >= 100.0 ? DateTime.now() : null,
        lastAccessedAt: DateTime.now(),
        totalTimeSpentMinutes: courseProgress.totalTimeSpentMinutes + 
                               (lessonProgress.timeSpentMinutes - 
                                (courseProgress.lessonProgress[lessonProgress.lessonId]?.timeSpentMinutes ?? 0)),
        status: overallProgress >= 100.0 
            ? CourseProgressStatus.completed 
            : CourseProgressStatus.inProgress,
      );
      
      await _saveCourseProgress(updatedCourseProgress);
    }
  }

  static double _calculateAverageScore(List<CourseProgress> progresses) {
    // This is simplified - in real implementation, aggregate from lesson scores
    return 85.0 + Random().nextDouble() * 10; // 85-95%
  }

  static int _calculateMonthlyCompletions(List<CourseProgress> progresses) {
    final now = DateTime.now();
    final thisMonth = progresses.where((p) => 
      p.completedAt != null &&
      p.completedAt!.year == now.year &&
      p.completedAt!.month == now.month
    );
    return thisMonth.length;
  }

  static List<String> _calculateSkillsAcquired(List<CourseProgress> progresses) {
    // In real implementation, this would aggregate from completed courses
    return ['JavaScript', 'React', 'Node.js', 'HTML/CSS', 'Python'];
  }

  static List<Achievement> _calculateAchievements(
    List<CourseProgress> progresses, 
    LearningStreak streak,
  ) {
    final achievements = <Achievement>[];
    
    final completedCount = progresses
        .where((p) => p.status == CourseProgressStatus.completed)
        .length;
    
    if (completedCount >= 1) {
      achievements.add(Achievement(
        id: 'first_course',
        title: 'First Course Completed',
        description: 'Completed your first course',
        iconPath: 'assets/icons/trophy.png',
        unlockedAt: DateTime.now(),
      ));
    }
    
    if (completedCount >= 5) {
      achievements.add(Achievement(
        id: 'course_master',
        title: 'Course Master',
        description: 'Completed 5 courses',
        iconPath: 'assets/icons/master.png',
        unlockedAt: DateTime.now(),
      ));
    }
    
    if (streak.currentStreak >= 7) {
      achievements.add(Achievement(
        id: 'week_streak',
        title: 'Week Warrior',
        description: '7-day learning streak',
        iconPath: 'assets/icons/streak.png',
        unlockedAt: DateTime.now(),
      ));
    }
    
    return achievements;
  }

  static List<UpcomingDeadline> _getUpcomingDeadlines(List<CourseProgress> progresses) {
    // In real implementation, this would check course deadlines
    return []; // Mock implementation
  }

  // Mock data generators
  static CourseProgress _getMockCourseProgress(String userId, String courseId) {
    return CourseProgress(
      id: 'progress_${userId}_$courseId',
      userId: userId,
      courseId: courseId,
      lessonProgress: {
        'lesson_001': LessonProgress(
          lessonId: 'lesson_001',
          progress: 100.0,
          status: LessonProgressStatus.completed,
          startedAt: DateTime.now().subtract(const Duration(days: 5)),
          completedAt: DateTime.now().subtract(const Duration(days: 4)),
          lastAccessedAt: DateTime.now().subtract(const Duration(days: 4)),
          timeSpentMinutes: 45,
          contentProgress: {'introduction': true, 'basics': true, 'practice': true},
          score: 92.0,
          attempts: 1,
        ),
        'lesson_002': LessonProgress(
          lessonId: 'lesson_002',
          progress: 60.0,
          status: LessonProgressStatus.inProgress,
          startedAt: DateTime.now().subtract(const Duration(hours: 3)),
          lastAccessedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          timeSpentMinutes: 30,
          contentProgress: {'introduction': true, 'basics': true},
          attempts: 1,
        ),
      },
      overallProgress: 65.0,
      startedAt: DateTime.now().subtract(const Duration(days: 10)),
      lastAccessedAt: DateTime.now().subtract(const Duration(hours: 2)),
      totalTimeSpentMinutes: 180,
      status: CourseProgressStatus.inProgress,
    );
  }

  static List<CourseProgress> _getMockUserProgress(String userId) {
    return [
      CourseProgress(
        id: 'progress_001',
        userId: userId,
        courseId: 'course_001',
        lessonProgress: {},
        overallProgress: 65.0,
        startedAt: DateTime.now().subtract(const Duration(days: 10)),
        lastAccessedAt: DateTime.now().subtract(const Duration(hours: 2)),
        totalTimeSpentMinutes: 180,
        status: CourseProgressStatus.inProgress,
      ),
      CourseProgress(
        id: 'progress_002',
        userId: userId,
        courseId: 'course_002',
        lessonProgress: {},
        overallProgress: 100.0,
        startedAt: DateTime.now().subtract(const Duration(days: 30)),
        completedAt: DateTime.now().subtract(const Duration(days: 5)),
        lastAccessedAt: DateTime.now().subtract(const Duration(days: 5)),
        totalTimeSpentMinutes: 480,
        status: CourseProgressStatus.completed,
      ),
    ];
  }
}

// Additional data models for progress tracking
class LearningStreak {
  final String userId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  LearningStreak({
    required this.userId,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });
}

class UserLearningAnalytics {
  final String userId;
  final int totalCoursesEnrolled;
  final int completedCourses;
  final int inProgressCourses;
  final int totalTimeSpentMinutes;
  final int currentStreak;
  final int longestStreak;
  final double averageScore;
  final int coursesCompletedThisMonth;
  final List<String> skillsAcquired;
  final List<Achievement> achievements;

  UserLearningAnalytics({
    required this.userId,
    required this.totalCoursesEnrolled,
    required this.completedCourses,
    required this.inProgressCourses,
    required this.totalTimeSpentMinutes,
    required this.currentStreak,
    required this.longestStreak,
    required this.averageScore,
    required this.coursesCompletedThisMonth,
    required this.skillsAcquired,
    required this.achievements,
  });
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final DateTime unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.unlockedAt,
  });
}

class ProgressSummary {
  final int totalCourses;
  final int completedCourses;
  final int inProgressCourses;
  final int currentStreak;
  final int totalTimeSpent;
  final int recentActivity;
  final int upcomingDeadlines;
  final double averageScore;

  ProgressSummary({
    required this.totalCourses,
    required this.completedCourses,
    required this.inProgressCourses,
    required this.currentStreak,
    required this.totalTimeSpent,
    required this.recentActivity,
    required this.upcomingDeadlines,
    required this.averageScore,
  });
}

class UpcomingDeadline {
  final String courseId;
  final String lessonId;
  final DateTime deadline;
  final String title;

  UpcomingDeadline({
    required this.courseId,
    required this.lessonId,
    required this.deadline,
    required this.title,
  });
}
