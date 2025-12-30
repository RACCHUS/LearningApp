import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/term.dart';
import '../models/concept.dart';
import '../models/question.dart';

/// A saved study set that can mix content from multiple sources
class SavedStudySet {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final List<String> lessonIds;
  final List<String> questionIds;
  final List<String> termIds;
  final List<String> conceptIds;
  final bool isFavorite;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedStudySet({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.lessonIds = const [],
    this.questionIds = const [],
    this.termIds = const [],
    this.conceptIds = const [],
    this.isFavorite = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total number of content items in this study set
  int get totalItems => lessonIds.length + questionIds.length + termIds.length + conceptIds.length;

  /// Check if study set is empty
  bool get isEmpty => totalItems == 0;

  SavedStudySet copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    List<String>? lessonIds,
    List<String>? questionIds,
    List<String>? termIds,
    List<String>? conceptIds,
    bool? isFavorite,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedStudySet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      lessonIds: lessonIds ?? this.lessonIds,
      questionIds: questionIds ?? this.questionIds,
      termIds: termIds ?? this.termIds,
      conceptIds: conceptIds ?? this.conceptIds,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'lesson_ids': lessonIds,
      'question_ids': questionIds,
      'term_ids': termIds,
      'concept_ids': conceptIds,
      'is_favorite': isFavorite,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SavedStudySet.fromJson(Map<String, dynamic> json) {
    return SavedStudySet(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      lessonIds: List<String>.from(json['lesson_ids'] ?? []),
      questionIds: List<String>.from(json['question_ids'] ?? []),
      termIds: List<String>.from(json['term_ids'] ?? []),
      conceptIds: List<String>.from(json['concept_ids'] ?? []),
      isFavorite: json['is_favorite'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Content loaded from a study set
class StudySetContent {
  final SavedStudySet studySet;
  final List<Term> terms;
  final List<Concept> concepts;
  final List<Question> questions;

  StudySetContent({
    required this.studySet,
    required this.terms,
    required this.concepts,
    required this.questions,
  });

  /// Total number of study items
  int get totalItems => terms.length + concepts.length + questions.length;
}

/// Progress tracking for a study set
class StudySetProgress {
  final String id;
  final String userId;
  final String studySetId;
  final int itemsCompleted;
  final int totalItems;
  final int correctCount;
  final DateTime? lastStudiedAt;
  final int sessionsCount;
  final int totalTimeMinutes;

  const StudySetProgress({
    required this.id,
    required this.userId,
    required this.studySetId,
    this.itemsCompleted = 0,
    this.totalItems = 0,
    this.correctCount = 0,
    this.lastStudiedAt,
    this.sessionsCount = 0,
    this.totalTimeMinutes = 0,
  });

  double get completionRate => totalItems > 0 ? itemsCompleted / totalItems : 0.0;
  double get accuracyRate => itemsCompleted > 0 ? correctCount / itemsCompleted : 0.0;

  factory StudySetProgress.fromJson(Map<String, dynamic> json) {
    return StudySetProgress(
      id: json['id'],
      userId: json['user_id'],
      studySetId: json['study_set_id'],
      itemsCompleted: json['items_completed'] ?? 0,
      totalItems: json['total_items'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
      lastStudiedAt: json['last_studied_at'] != null
          ? DateTime.parse(json['last_studied_at'])
          : null,
      sessionsCount: json['sessions_count'] ?? 0,
      totalTimeMinutes: json['total_time_minutes'] ?? 0,
    );
  }
}

/// Service for managing saved study sets
/// 
/// Provides CRUD operations for study sets and their progress tracking
class SavedStudySetService {
  final SupabaseClient _supabase;

  SavedStudySetService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================================
  // STUDY SET CRUD
  // ============================================================================

  /// Create a new study set
  Future<SavedStudySet> createStudySet({
    required String title,
    String? description,
    List<String> lessonIds = const [],
    List<String> questionIds = const [],
    List<String> termIds = const [],
    List<String> conceptIds = const [],
    List<String> tags = const [],
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated to create a study set');
      }

      final data = {
        'user_id': userId,
        'title': title,
        'description': description,
        'lesson_ids': lessonIds,
        'question_ids': questionIds,
        'term_ids': termIds,
        'concept_ids': conceptIds,
        'tags': tags,
        'is_favorite': false,
      };

      final response = await _supabase
          .from('study_sets')
          .insert(data)
          .select()
          .single();

      debugPrint('✅ Study set created: ${response['id']}');
      return SavedStudySet.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating study set: $e');
      rethrow;
    }
  }

  /// Get a study set by ID
  Future<SavedStudySet> getStudySet(String id) async {
    try {
      final response = await _supabase
          .from('study_sets')
          .select()
          .eq('id', id)
          .single();

      return SavedStudySet.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching study set: $e');
      rethrow;
    }
  }

  /// Get all study sets for the current user
  Future<List<SavedStudySet>> getUserStudySets() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('study_sets')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (response as List).map((s) => SavedStudySet.fromJson(s)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching user study sets: $e');
      rethrow;
    }
  }

  /// Get favorite study sets
  Future<List<SavedStudySet>> getFavoriteStudySets() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('study_sets')
          .select()
          .eq('user_id', userId)
          .eq('is_favorite', true)
          .order('updated_at', ascending: false);

      return (response as List).map((s) => SavedStudySet.fromJson(s)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching favorite study sets: $e');
      rethrow;
    }
  }

  /// Update a study set
  Future<SavedStudySet> updateStudySet(SavedStudySet studySet) async {
    try {
      final data = {
        'title': studySet.title,
        'description': studySet.description,
        'lesson_ids': studySet.lessonIds,
        'question_ids': studySet.questionIds,
        'term_ids': studySet.termIds,
        'concept_ids': studySet.conceptIds,
        'is_favorite': studySet.isFavorite,
        'tags': studySet.tags,
      };

      final response = await _supabase
          .from('study_sets')
          .update(data)
          .eq('id', studySet.id)
          .select()
          .single();

      debugPrint('✅ Study set updated: ${studySet.id}');
      return SavedStudySet.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating study set: $e');
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<SavedStudySet> toggleFavorite(String id) async {
    try {
      final current = await getStudySet(id);
      return updateStudySet(current.copyWith(isFavorite: !current.isFavorite));
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Delete a study set
  Future<void> deleteStudySet(String id) async {
    try {
      await _supabase.from('study_sets').delete().eq('id', id);
      debugPrint('✅ Study set deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting study set: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CONTENT FETCHING
  // ============================================================================

  /// Fetch all content for a study set
  Future<StudySetContent> fetchStudySetContent(SavedStudySet studySet) async {
    try {
      final terms = <Term>[];
      final concepts = <Concept>[];
      final questions = <Question>[];

      // Fetch content from lessons
      if (studySet.lessonIds.isNotEmpty) {
        final lessonContent = await _fetchContentFromLessons(studySet.lessonIds);
        terms.addAll(lessonContent.terms);
        concepts.addAll(lessonContent.concepts);
        questions.addAll(lessonContent.questions);
      }

      // Fetch individual terms
      if (studySet.termIds.isNotEmpty) {
        final individualTerms = await _fetchTermsByIds(studySet.termIds);
        terms.addAll(individualTerms);
      }

      // Fetch individual concepts
      if (studySet.conceptIds.isNotEmpty) {
        final individualConcepts = await _fetchConceptsByIds(studySet.conceptIds);
        concepts.addAll(individualConcepts);
      }

      // Fetch individual questions
      if (studySet.questionIds.isNotEmpty) {
        final individualQuestions = await _fetchQuestionsByIds(studySet.questionIds);
        questions.addAll(individualQuestions);
      }

      return StudySetContent(
        studySet: studySet,
        terms: terms,
        concepts: concepts,
        questions: questions,
      );
    } catch (e) {
      debugPrint('❌ Error fetching study set content: $e');
      rethrow;
    }
  }

  Future<({List<Term> terms, List<Concept> concepts, List<Question> questions})>
      _fetchContentFromLessons(List<String> lessonIds) async {
    final terms = <Term>[];
    final concepts = <Concept>[];
    final questions = <Question>[];

    // Fetch terms
    final termsResponse = await _supabase
        .from('terms')
        .select()
        .inFilter('lesson_id', lessonIds);
    terms.addAll((termsResponse as List).map((t) => Term.fromJson(t)));

    // Fetch concepts
    final conceptsResponse = await _supabase
        .from('concepts')
        .select()
        .inFilter('lesson_id', lessonIds);
    concepts.addAll((conceptsResponse as List).map((c) => Concept.fromJson(c)));

    // Fetch questions
    final questionsResponse = await _supabase
        .from('questions')
        .select()
        .inFilter('lesson_id', lessonIds);
    questions.addAll((questionsResponse as List).map((q) => Question.fromJson(q)));

    return (terms: terms, concepts: concepts, questions: questions);
  }

  Future<List<Term>> _fetchTermsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await _supabase
        .from('terms')
        .select()
        .inFilter('id', ids);
    return (response as List).map((t) => Term.fromJson(t)).toList();
  }

  Future<List<Concept>> _fetchConceptsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await _supabase
        .from('concepts')
        .select()
        .inFilter('id', ids);
    return (response as List).map((c) => Concept.fromJson(c)).toList();
  }

  Future<List<Question>> _fetchQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final response = await _supabase
        .from('questions')
        .select()
        .inFilter('id', ids);
    return (response as List).map((q) => Question.fromJson(q)).toList();
  }

  // ============================================================================
  // PROGRESS TRACKING
  // ============================================================================

  /// Get or create progress for a study set
  Future<StudySetProgress> getProgress(String studySetId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      // Try to get existing progress
      final response = await _supabase
          .from('study_set_progress')
          .select()
          .eq('user_id', userId)
          .eq('study_set_id', studySetId)
          .maybeSingle();

      if (response != null) {
        return StudySetProgress.fromJson(response);
      }

      // Create new progress record
      final studySet = await getStudySet(studySetId);
      final content = await fetchStudySetContent(studySet);

      final newProgress = {
        'user_id': userId,
        'study_set_id': studySetId,
        'items_completed': 0,
        'total_items': content.totalItems,
        'correct_count': 0,
        'sessions_count': 0,
        'total_time_minutes': 0,
      };

      final created = await _supabase
          .from('study_set_progress')
          .insert(newProgress)
          .select()
          .single();

      return StudySetProgress.fromJson(created);
    } catch (e) {
      debugPrint('❌ Error getting study set progress: $e');
      rethrow;
    }
  }

  /// Update progress after answering an item
  Future<StudySetProgress> recordAnswer({
    required String studySetId,
    required bool isCorrect,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      // Get current progress
      final current = await getProgress(studySetId);

      final updates = {
        'items_completed': current.itemsCompleted + 1,
        'correct_count': isCorrect ? current.correctCount + 1 : current.correctCount,
        'last_studied_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('study_set_progress')
          .update(updates)
          .eq('user_id', userId)
          .eq('study_set_id', studySetId)
          .select()
          .single();

      return StudySetProgress.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error recording answer: $e');
      rethrow;
    }
  }

  /// Start a new study session
  Future<StudySetProgress> startSession(String studySetId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      final current = await getProgress(studySetId);

      final updates = {
        'sessions_count': current.sessionsCount + 1,
        'last_studied_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('study_set_progress')
          .update(updates)
          .eq('user_id', userId)
          .eq('study_set_id', studySetId)
          .select()
          .single();

      return StudySetProgress.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error starting session: $e');
      rethrow;
    }
  }

  /// Reset progress for a study set
  Future<StudySetProgress> resetProgress(String studySetId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }

      final studySet = await getStudySet(studySetId);
      final content = await fetchStudySetContent(studySet);

      final updates = {
        'items_completed': 0,
        'correct_count': 0,
        'total_items': content.totalItems,
      };

      final response = await _supabase
          .from('study_set_progress')
          .update(updates)
          .eq('user_id', userId)
          .eq('study_set_id', studySetId)
          .select()
          .single();

      debugPrint('✅ Progress reset for study set: $studySetId');
      return StudySetProgress.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error resetting progress: $e');
      rethrow;
    }
  }

  /// Get all study set progress for current user
  Future<List<StudySetProgress>> getAllProgress() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return [];
      }

      final response = await _supabase
          .from('study_set_progress')
          .select()
          .eq('user_id', userId)
          .order('last_studied_at', ascending: false);

      return (response as List).map((p) => StudySetProgress.fromJson(p)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all progress: $e');
      rethrow;
    }
  }

  // ============================================================================
  // QUICK ACTIONS
  // ============================================================================

  /// Create study set from lesson selection (quick create)
  Future<SavedStudySet> createFromLessons({
    required String title,
    required List<String> lessonIds,
    String? description,
  }) async {
    return createStudySet(
      title: title,
      description: description,
      lessonIds: lessonIds,
    );
  }

  /// Duplicate a study set
  Future<SavedStudySet> duplicateStudySet(String id, {String? newTitle}) async {
    try {
      final original = await getStudySet(id);
      return createStudySet(
        title: newTitle ?? '${original.title} (Copy)',
        description: original.description,
        lessonIds: original.lessonIds,
        questionIds: original.questionIds,
        termIds: original.termIds,
        conceptIds: original.conceptIds,
        tags: original.tags,
      );
    } catch (e) {
      debugPrint('❌ Error duplicating study set: $e');
      rethrow;
    }
  }

  /// Add content to existing study set
  Future<SavedStudySet> addContent({
    required String studySetId,
    List<String> lessonIds = const [],
    List<String> questionIds = const [],
    List<String> termIds = const [],
    List<String> conceptIds = const [],
  }) async {
    try {
      final current = await getStudySet(studySetId);
      return updateStudySet(current.copyWith(
        lessonIds: [...current.lessonIds, ...lessonIds],
        questionIds: [...current.questionIds, ...questionIds],
        termIds: [...current.termIds, ...termIds],
        conceptIds: [...current.conceptIds, ...conceptIds],
      ));
    } catch (e) {
      debugPrint('❌ Error adding content to study set: $e');
      rethrow;
    }
  }

  /// Remove content from study set
  Future<SavedStudySet> removeContent({
    required String studySetId,
    List<String> lessonIds = const [],
    List<String> questionIds = const [],
    List<String> termIds = const [],
    List<String> conceptIds = const [],
  }) async {
    try {
      final current = await getStudySet(studySetId);
      return updateStudySet(current.copyWith(
        lessonIds: current.lessonIds.where((id) => !lessonIds.contains(id)).toList(),
        questionIds: current.questionIds.where((id) => !questionIds.contains(id)).toList(),
        termIds: current.termIds.where((id) => !termIds.contains(id)).toList(),
        conceptIds: current.conceptIds.where((id) => !conceptIds.contains(id)).toList(),
      ));
    } catch (e) {
      debugPrint('❌ Error removing content from study set: $e');
      rethrow;
    }
  }
}
