import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:learning_pwa/models/local_lesson.dart';

class LocalLessonService {
  static const String _lessonsKey = 'local_lessons';

  // Save a lesson locally
  static Future<void> saveLesson(LocalLesson lesson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> lessons = prefs.getStringList(_lessonsKey) ?? [];
      
      // Convert lesson to JSON and add to the list
      lessons.add(jsonEncode(lesson.toJson()));
      
      // Save back to shared preferences
      await prefs.setStringList(_lessonsKey, lessons);
    } catch (e) {
      print('Error saving lesson locally: $e');
      rethrow;
    }
  }

  // Get all locally saved lessons
  static Future<List<LocalLesson>> getLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? lessonsJson = prefs.getStringList(_lessonsKey);
      
      if (lessonsJson == null) return [];
      
      return lessonsJson
          .map((lesson) => LocalLesson.fromJson(jsonDecode(lesson)))
          .toList();
    } catch (e) {
      print('Error getting local lessons: $e');
      return [];
    }
  }

  // Delete a locally saved lesson by ID
  static Future<void> deleteLesson(String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? lessonsJson = prefs.getStringList(_lessonsKey);
      
      if (lessonsJson == null) return;
      
      final updatedLessons = lessonsJson.where((lesson) {
        final lessonMap = jsonDecode(lesson) as Map<String, dynamic>;
        return lessonMap['id'] != lessonId;
      }).toList();
      
      await prefs.setStringList(_lessonsKey, updatedLessons);
    } catch (e) {
      print('Error deleting local lesson: $e');
      rethrow;
    }
  }
}
