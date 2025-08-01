import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/services/hive_service.dart';

final combinedLessonsProvider = FutureProvider.family<List<BaseLesson>, String>(
  (ref, userId) async {
    final lessonService = LessonService();
    final hiveServiceRef = hiveService;
    
    try {
      // Try to get online lessons first
      List<BaseLesson> onlineLessons = [];
      try {
        onlineLessons = await lessonService.getLessonsForUser(userId);
      } catch (e) {
        debugPrint('Failed to get online lessons: $e');
        // Continue with offline lessons only
      }
      
      // Get offline lessons
      List<BaseLesson> offlineLessons = [];
      try {
        offlineLessons = await hiveServiceRef.getOfflineLessons(userId);
      } catch (e) {
        debugPrint('Failed to get offline lessons: $e');
        // Continue with empty list
      }
      
      // Combine and sort by most recent
      final allLessons = [...onlineLessons, ...offlineLessons];
      allLessons.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return allLessons;
    } catch (e) {
      debugPrint('Error in combinedLessonsProvider: $e');
      // Return empty list as fallback
      return <BaseLesson>[];
    }
  },
);
