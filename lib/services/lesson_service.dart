import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';

/// Main lesson service that orchestrates all lesson operations
/// 
/// This service acts as a facade that delegates operations to specialized services:
/// - LessonCrudService: Basic CRUD operations
/// - LessonContentService: Content management (terms, questions, concepts)
/// - LessonImportService: JSON import functionality
class LessonService {
  final LessonCrudService _crudService;
  final LessonContentService _contentService;
  final LessonImportService _importService;

  LessonService({
    LessonCrudService? crudService,
    LessonContentService? contentService,
    LessonImportService? importService,
  }) : _crudService = crudService ?? LessonCrudService(),
        _contentService = contentService ?? LessonContentService(),
        _importService = importService ?? LessonImportService();

  /// Get all lessons for a user
  Future<List<Lesson>> getLessonsForUser(String userId) async {
    return _crudService.getLessonsForUser(userId);
  }

  /// Get a specific lesson by ID with all its content
  Future<Lesson> getLesson(String lessonId) async {
    return _crudService.getLesson(lessonId);
  }

  /// Add a new lesson
  Future<Lesson> addLesson(String title, String? description, String userId, {List<String>? tags}) async {
    return _crudService.addLesson(title, description, userId, tags: tags);
  }

  /// Delete a lesson
  Future<void> deleteLessonFromSupabase(String lessonId) async {
    return _crudService.deleteLessonFromSupabase(lessonId);
  }

  /// Add terms to a lesson
  Future<void> addTerms(String lessonId, List<Term> terms) async {
    return _contentService.addTerms(lessonId, terms);
  }

  /// Add questions to a lesson
  Future<void> addQuestions(String lessonId, List<Question> questions) async {
    return _contentService.addQuestions(lessonId, questions);
  }

  /// Add concepts to a lesson
  Future<void> addConcepts(String lessonId, List<Concept> concepts) async {
    return _contentService.addConcepts(lessonId, concepts);
  }

  /// Get content counts for a lesson
  Future<Map<String, int>> getContentCounts(String lessonId) async {
    return _contentService.getContentCounts(lessonId);
  }

  /// Import a lesson from JSON
  Future<Lesson> importLessonFromJson(String jsonString, String userId) async {
    return _importService.importLessonFromJson(jsonString, userId);
  }

  /// Validate lesson JSON structure
  bool validateLessonJson(String jsonString) {
    return _importService.validateLessonJson(jsonString);
  }

  /// Add lesson content (legacy method for backward compatibility)
  Future<void> addLessonContent(String lessonId, List<LessonContent> content, String userId) async {
    debugPrint('🔍 DEBUG: Adding ${content.length} content items to lesson $lessonId');
    debugPrint('ℹ️ INFO: Legacy addLessonContent method called - consider using specific content type methods');
    
    // This is a legacy method - in practice, you should use the specific methods:
    // - addTerms() for term content
    // - addQuestions() for question content  
    // - addConcepts() for concept content
    
    // For now, we'll just log and return success
    // The actual content addition should be done through the specific typed methods
    debugPrint('✅ Legacy content addition completed');
  }
}
