import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson.dart';
import '../services/local_lesson_service.dart';
import '../models/base_lesson.dart';

final combinedLessonsProvider = FutureProvider.family<List<BaseLesson>, String>((ref, userId) async {
  final supabase = Supabase.instance.client;
  final List<BaseLesson> allLessons = [];
  
  try {
    // Get cloud lessons if user is authenticated
    if (userId.isNotEmpty) {
      final cloudLessons = await _fetchCloudLessons(supabase);
      allLessons.addAll(cloudLessons);
    }

    // Get local lessons
    final localLessons = await LocalLessonService.getLessons();
    allLessons.addAll(localLessons);

    // Sort by creation date (newest first)
    allLessons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  } catch (e) {
    print('Error combining lessons: $e');
    // Continue with whatever lessons we have
  }

  return allLessons;
});

Future<List<Lesson>> _fetchCloudLessons(SupabaseClient supabase) async {
  try {
    final response = await supabase.from('lessons').select();
    return (response as List)
        .map((json) => Lesson.fromJson(json))
        .toList();
  } catch (e) {
    print('Error fetching cloud lessons: $e');
    return [];
  }
}
