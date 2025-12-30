import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Types of recommendations
enum RecommendationType {
  popularInTag,
  becauseYouStudied,
  continueProgress,
  newContent,
  trending;

  String get displayTitle {
    switch (this) {
      case RecommendationType.popularInTag:
        return 'Popular in';
      case RecommendationType.becauseYouStudied:
        return 'Because you studied';
      case RecommendationType.continueProgress:
        return 'Continue where you left off';
      case RecommendationType.newContent:
        return 'New for you';
      case RecommendationType.trending:
        return 'Trending now';
    }
  }
}

/// A recommendation item
class Recommendation {
  final String id;
  final String title;
  final String? description;
  final RecommendationType type;
  final String? context; // e.g., tag name or related lesson title
  final String targetId; // lesson_id, course_id, etc.
  final String targetType; // 'lesson', 'course', 'study_set'
  final double score; // Relevance score 0-1
  final int? studyCount; // Number of users who studied this

  Recommendation({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.context,
    required this.targetId,
    required this.targetType,
    required this.score,
    this.studyCount,
  });

  factory Recommendation.fromLessonJson(
    Map<String, dynamic> json, {
    required RecommendationType type,
    String? context,
    double score = 0.5,
  }) {
    return Recommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: type,
      context: context,
      targetId: json['id'] as String,
      targetType: 'lesson',
      score: score,
      studyCount: json['study_count'] as int?,
    );
  }
}

/// A group of recommendations with a shared reason
class RecommendationGroup {
  final RecommendationType type;
  final String title;
  final String? context;
  final List<Recommendation> items;

  RecommendationGroup({
    required this.type,
    required this.title,
    this.context,
    required this.items,
  });
}

/// Service for generating personalized recommendations
class RecommendationService {
  final SupabaseClient _supabase;

  RecommendationService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  String? get _userId => _supabase.auth.currentUser?.id;

  /// Get all recommendation groups for the user
  Future<List<RecommendationGroup>> getRecommendations() async {
    final groups = <RecommendationGroup>[];

    try {
      // Run recommendation queries in parallel
      final results = await Future.wait([
        _getPopularInUserTags(),
        _getBecauseYouStudied(),
        _getContinueProgress(),
        _getNewContent(),
      ]);

      for (final group in results) {
        if (group != null && group.items.isNotEmpty) {
          groups.add(group);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recommendations: $e');
      }
    }

    return groups;
  }

  /// "Popular in [tag]" - Get popular lessons in tags the user has studied
  Future<RecommendationGroup?> _getPopularInUserTags() async {
    if (_userId == null) return null;

    try {
      // Get tags from lessons the user has studied
      final studiedLessons = await _supabase
          .from('study_progress')
          .select('lesson_id')
          .eq('user_id', _userId!);

      if ((studiedLessons as List).isEmpty) return null;

      final lessonIds = studiedLessons.map((e) => e['lesson_id']).toList();

      // Get tags from these lessons
      final lessonTags = await _supabase
          .from('lessons')
          .select('tags')
          .inFilter('id', lessonIds);

      // Extract unique tags
      final allTags = <String>{};
      for (final lesson in lessonTags as List) {
        final tags = lesson['tags'];
        if (tags is List) {
          allTags.addAll(tags.cast<String>());
        }
      }

      if (allTags.isEmpty) return null;

      // Pick the most common tag
      final primaryTag = allTags.first;

      // Get popular lessons with this tag that user hasn't studied
      final popularLessons = await _supabase
          .from('lessons')
          .select('id, title, description, tags')
          .contains('tags', [primaryTag])
          .not('id', 'in', lessonIds)
          .limit(5);

      if ((popularLessons as List).isEmpty) return null;

      final recommendations = popularLessons.map((lesson) {
        return Recommendation.fromLessonJson(
          lesson,
          type: RecommendationType.popularInTag,
          context: primaryTag,
          score: 0.8,
        );
      }).toList();

      return RecommendationGroup(
        type: RecommendationType.popularInTag,
        title: 'Popular in $primaryTag',
        context: primaryTag,
        items: recommendations,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching popular in tag: $e');
      }
      return null;
    }
  }

  /// "Because you studied X" - Collaborative filtering based on similar users
  Future<RecommendationGroup?> _getBecauseYouStudied() async {
    if (_userId == null) return null;

    try {
      // Get user's recently studied lessons
      final recentLessons = await _supabase
          .from('study_progress')
          .select('lesson_id, lessons(title)')
          .eq('user_id', _userId!)
          .order('updated_at', ascending: false)
          .limit(3);

      if ((recentLessons as List).isEmpty) return null;

      final recentLessonIds = recentLessons.map((e) => e['lesson_id']).toList();
      final referenceLessonTitle =
          recentLessons.first['lessons']?['title'] as String? ?? 'recent lessons';

      // Find other users who studied the same lessons
      final similarUsers = await _supabase
          .from('study_progress')
          .select('user_id')
          .inFilter('lesson_id', recentLessonIds)
          .neq('user_id', _userId!)
          .limit(20);

      if ((similarUsers as List).isEmpty) return null;

      final similarUserIds = similarUsers.map((e) => e['user_id']).toSet().toList();

      // Get lessons those users studied that current user hasn't
      final suggestedLessons = await _supabase
          .from('study_progress')
          .select('lesson_id, lessons(id, title, description)')
          .inFilter('user_id', similarUserIds)
          .not('lesson_id', 'in', recentLessonIds)
          .limit(10);

      // Count occurrences to rank by popularity among similar users
      final lessonCounts = <String, Map<String, dynamic>>{};
      for (final entry in suggestedLessons as List) {
        final lessonId = entry['lesson_id'] as String;
        final lessonData = entry['lessons'] as Map<String, dynamic>?;
        if (lessonData != null) {
          lessonCounts[lessonId] ??= {...lessonData, 'count': 0};
          lessonCounts[lessonId]!['count'] =
              (lessonCounts[lessonId]!['count'] as int) + 1;
        }
      }

      if (lessonCounts.isEmpty) return null;

      // Sort by count and take top 5
      final sortedLessons = lessonCounts.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      final recommendations = sortedLessons.take(5).map((lesson) {
        final count = lesson['count'] as int;
        final maxCount = sortedLessons.first['count'] as int;
        return Recommendation.fromLessonJson(
          lesson,
          type: RecommendationType.becauseYouStudied,
          context: referenceLessonTitle,
          score: count / maxCount,
        );
      }).toList();

      return RecommendationGroup(
        type: RecommendationType.becauseYouStudied,
        title: 'Because you studied "$referenceLessonTitle"',
        context: referenceLessonTitle,
        items: recommendations,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching because you studied: $e');
      }
      return null;
    }
  }

  /// Continue progress - Lessons user started but didn't complete
  Future<RecommendationGroup?> _getContinueProgress() async {
    if (_userId == null) return null;

    try {
      final inProgressLessons = await _supabase
          .from('study_progress')
          .select('lesson_id, progress_percent, lessons(id, title, description)')
          .eq('user_id', _userId!)
          .gt('progress_percent', 0)
          .lt('progress_percent', 100)
          .order('updated_at', ascending: false)
          .limit(5);

      if ((inProgressLessons as List).isEmpty) return null;

      final recommendations = inProgressLessons.map((progress) {
        final lesson = progress['lessons'] as Map<String, dynamic>;
        final progressPercent = progress['progress_percent'] as int;
        return Recommendation(
          id: lesson['id'] as String,
          title: lesson['title'] as String,
          description: '${progressPercent}% complete',
          type: RecommendationType.continueProgress,
          targetId: lesson['id'] as String,
          targetType: 'lesson',
          score: 1.0 - (progressPercent / 100), // Higher score for less progress
        );
      }).toList();

      return RecommendationGroup(
        type: RecommendationType.continueProgress,
        title: 'Continue where you left off',
        items: recommendations,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching continue progress: $e');
      }
      return null;
    }
  }

  /// New content - Recently added lessons user hasn't seen
  Future<RecommendationGroup?> _getNewContent() async {
    try {
      final studiedLessonIds = <String>[];

      if (_userId != null) {
        final studied = await _supabase
            .from('study_progress')
            .select('lesson_id')
            .eq('user_id', _userId!);

        studiedLessonIds.addAll(
          (studied as List).map((e) => e['lesson_id'] as String),
        );
      }

      // Get recently created lessons
      var query = _supabase
          .from('lessons')
          .select('id, title, description, created_at')
          .order('created_at', ascending: false)
          .limit(10);

      final newLessons = await query;

      // Filter out already studied lessons
      final filtered = (newLessons as List)
          .where((l) => !studiedLessonIds.contains(l['id']))
          .take(5)
          .toList();

      if (filtered.isEmpty) return null;

      final recommendations = filtered.map((lesson) {
        return Recommendation.fromLessonJson(
          lesson,
          type: RecommendationType.newContent,
          score: 0.6,
        );
      }).toList();

      return RecommendationGroup(
        type: RecommendationType.newContent,
        title: 'New for you',
        items: recommendations,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching new content: $e');
      }
      return null;
    }
  }
}

/// Provider for RecommendationService
final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService();
});

/// Provider for all recommendations
final recommendationsProvider =
    FutureProvider<List<RecommendationGroup>>((ref) async {
  final service = ref.read(recommendationServiceProvider);
  return service.getRecommendations();
});

/// Provider for a specific recommendation type
final recommendationsByTypeProvider =
    FutureProvider.family<RecommendationGroup?, RecommendationType>(
        (ref, type) async {
  final allRecs = await ref.watch(recommendationsProvider.future);
  return allRecs.where((g) => g.type == type).firstOrNull;
});
