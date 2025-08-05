import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/supabase_service.dart';
import 'package:learning_pwa/services/hive_service.dart';

class StudyService {
  static final StudyService _instance = StudyService._internal();
  factory StudyService() => _instance;

  final SupabaseService _supabase = SupabaseService();
  final HiveService _hive = hiveService;
  
  StudyService._internal();

  Future<Lesson> getLessonWithContent(String lessonId, {bool useCache = false}) async {
    if (useCache) {
      final cached = await _hive.getLesson(lessonId);
      if (cached != null) return cached;
    }

    final response = await _supabase.from('lessons').select('''
      *,
      lesson_terms(terms(*)),
      lesson_questions(questions(*)),
      lesson_concepts(concepts(*)
    ''').eq('id', lessonId).single();

    final lesson = Lesson.fromJson(response);
    if (useCache) {
      await _hive.saveLesson(lesson);
    }
    return lesson;
  }

  Future<void> recordProgress(UserProgress progress) async {
    if (!progress.isSynced) {
      await _hive.saveProgress(progress);
    } else {
      await _supabase.from('user_progress').upsert({
        'user_id': progress.userId,
        'lesson_id': progress.lessonId,
        'date': progress.date.toIso8601String().split('T')[0],
        'questions_answered': progress.questionsAnswered,
        'correct_count': progress.correctCount,
        'lesson_completed': progress.lessonCompleted,
        'study_time_minutes': progress.studyTimeMinutes,
      });
    }
  }

  Future<List<UserProgress>> getProgress({
    required String userId,
    String? lessonId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase.from('user_progress').select().eq('user_id', userId);
    
    if (lessonId != null) {
      query = query.eq('lesson_id', lessonId);
    }
    
    if (startDate != null) {
      query = query.gte('date', startDate.toIso8601String().split('T')[0]);
    }
    
    if (endDate != null) {
      query = query.lte('date', endDate.toIso8601String().split('T')[0]);
    }

    final response = await query;
    return response.map((json) => UserProgress.fromJson(json)).toList();
  }

  Future<Map<String, int>> getStudyStreaks(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    final progress = await getProgress(
      userId: userId,
      startDate: thirtyDaysAgo,
      endDate: now,
    );

    // Group by date and count questions answered
    final dailyProgress = <String, int>{};
    for (var p in progress) {
      final date = p.date.toIso8601String().split('T')[0];
      dailyProgress[date] = (dailyProgress[date] ?? 0) + p.questionsAnswered;
    }

    return dailyProgress;
  }
}
