import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:uuid/uuid.dart';

/// Service for importing lessons from JSON
/// 
/// Handles parsing JSON data and creating lessons with
/// all associated content in the database.
class LessonImportService {
  final LessonCrudService _crudService;
  final LessonContentService _contentService;

  LessonImportService({
    LessonCrudService? crudService,
    LessonContentService? contentService,
  }) : _crudService = crudService ?? LessonCrudService(),
        _contentService = contentService ?? LessonContentService();

  /// Import a lesson from JSON string
  Future<Lesson> importLessonFromJson(String jsonString, String userId) async {
    try {
      debugPrint('🔍 DEBUG: Importing lesson from JSON for user: $userId');
      
      // Parse JSON
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      final title = jsonData['title']?.toString();
      if (title == null || title.trim().isEmpty) {
        throw ArgumentError('Lesson title is required');
      }

      // Extract lesson metadata
      final description = jsonData['description']?.toString();
      final tags = jsonData['tags'] is List 
          ? List<String>.from(jsonData['tags']) 
          : <String>[];

      debugPrint('🔍 DEBUG: Creating lesson: $title');
      
      // Create the lesson
      final lesson = await _crudService.addLesson(
        title, 
        description, 
        userId, 
        tags: tags,
      );

      // Import content
      await _importLessonContent(lesson.id, jsonData, userId);

      debugPrint('✅ Lesson imported successfully: ${lesson.id}');
      return lesson;
    } catch (e) {
      debugPrint('❌ ERROR: Failed to import lesson from JSON: $e');
      rethrow;
    }
  }

  /// Import lesson content from JSON data
  Future<void> _importLessonContent(
    String lessonId, 
    Map<String, dynamic> jsonData, 
    String userId
  ) async {
    try {
      // Import terms
      if (jsonData['terms'] is List) {
        final termsData = jsonData['terms'] as List;
        debugPrint('🔍 Importing ${termsData.length} terms');
        final terms = termsData
            .whereType<Map<String, dynamic>>()
            .map((t) => Term(
                  id: t['id']?.toString() ?? const Uuid().v4(),
                  term: t['term']?.toString() ?? '',
                  definition: t['definition']?.toString() ?? '',
                  example: t['example']?.toString(),
                  createdBy: t['created_by']?.toString() ?? userId,
                ))
            .where((t) => t.term.isNotEmpty && t.definition.isNotEmpty)
            .toList();
        if (terms.isNotEmpty) {
          await _contentService.addTerms(lessonId, terms);
        }
      }

      // Import questions
      if (jsonData['questions'] is List) {
        final questionsData = jsonData['questions'] as List;
        debugPrint('🔍 Importing ${questionsData.length} questions');
        final questions = questionsData
            .whereType<Map<String, dynamic>>()
            .map((q) => Question(
                  id: q['id']?.toString() ?? const Uuid().v4(),
                  questionText: q['question_text']?.toString() ?? q['question']?.toString() ?? '',
                  options: q['options'] is List ? List<String>.from(q['options']) : <String>[],
                  correctAnswer: q['correct_answer'] is int
                      ? q['correct_answer']
                      : int.tryParse(q['correct_answer']?.toString() ?? '') ?? 0,
                  type: q['type']?.toString() ?? 'mcq',
                  explanation: q['explanation']?.toString(),
                  createdBy: q['created_by']?.toString() ?? userId,
                ))
            .where((q) => q.questionText.isNotEmpty && q.options.isNotEmpty)
            .toList();
        if (questions.isNotEmpty) {
          await _contentService.addQuestions(lessonId, questions);
        }
      }

      // Import concepts
      if (jsonData['concepts'] is List) {
        final conceptsData = jsonData['concepts'] as List;
        debugPrint('🔍 Importing ${conceptsData.length} concepts');
        final concepts = conceptsData
            .whereType<Map<String, dynamic>>()
            .map((c) => Concept(
                  id: c['id']?.toString() ?? const Uuid().v4(),
                  lessonId: lessonId,
                  conceptText: c['concept_text']?.toString() ?? c['title']?.toString() ?? '',
                  exampleText: c['example_text']?.toString() ?? c['example']?.toString(),
                  createdBy: c['created_by']?.toString() ?? userId,
                ))
            .where((c) => c.conceptText.isNotEmpty)
            .toList();
        if (concepts.isNotEmpty) {
          await _contentService.addConcepts(lessonId, concepts);
        }
      }

      // Import generic content
      if (jsonData['content'] is List) {
        final contentData = jsonData['content'] as List;
        debugPrint('🔍 Importing ${contentData.length} content items');
        
        await _importGenericContent(lessonId, contentData, userId);
      }
    } catch (e) {
      debugPrint('❌ ERROR: Failed to import lesson content: $e');
      rethrow;
    }
  }

  /// Import generic content that can be any type
  Future<void> _importGenericContent(
    String lessonId, 
    List<dynamic> contentData, 
    String userId
  ) async {
    for (final item in contentData) {
      if (item is! Map<String, dynamic>) continue;
      
      final type = item['type']?.toString();
      
      switch (type) {
        case 'term':
          await _importTermFromContent(lessonId, item, userId);
          break;
        case 'mcq':
        case 'question':
          await _importQuestionFromContent(lessonId, item, userId);
          break;
        case 'concept':
          await _importConceptFromContent(lessonId, item, userId);
          break;
        default:
          debugPrint('⚠️ WARNING: Unknown content type: $type');
      }
    }
  }

  /// Import a term from content data
  Future<void> _importTermFromContent(
    String lessonId, 
    Map<String, dynamic> data, 
    String userId
  ) async {
    final term = Term(
      id: data['id']?.toString() ?? const Uuid().v4(),
      term: data['term']?.toString() ?? '',
      definition: data['definition']?.toString() ?? '',
      example: data['example']?.toString(),
      createdBy: data['created_by']?.toString() ?? userId,
    );
    if (term.term.isEmpty || term.definition.isEmpty) {
      debugPrint('⚠️ Skipping term with empty term/definition');
      return;
    }
    await _contentService.addTerms(lessonId, [term]);
  }

  /// Import a question from content data
  Future<void> _importQuestionFromContent(
    String lessonId, 
    Map<String, dynamic> data, 
    String userId
  ) async {
    final question = Question(
      id: data['id']?.toString() ?? const Uuid().v4(),
      questionText: data['question_text']?.toString() ?? data['question']?.toString() ?? '',
      options: data['options'] is List ? List<String>.from(data['options']) : <String>[],
      correctAnswer: data['correct_answer'] is int
          ? data['correct_answer']
          : int.tryParse(data['correct_answer']?.toString() ?? '') ?? 0,
      type: data['type']?.toString() ?? 'mcq',
      explanation: data['explanation']?.toString(),
      createdBy: data['created_by']?.toString() ?? userId,
    );
    if (question.questionText.isEmpty || question.options.isEmpty) {
      debugPrint('⚠️ Skipping question with empty text/options');
      return;
    }
    await _contentService.addQuestions(lessonId, [question]);
  }

  /// Import a concept from content data
  Future<void> _importConceptFromContent(
    String lessonId, 
    Map<String, dynamic> data, 
    String userId
  ) async {
    final concept = Concept(
      id: data['id']?.toString() ?? const Uuid().v4(),
      lessonId: lessonId,
      conceptText: data['concept_text']?.toString() ?? data['title']?.toString() ?? '',
      exampleText: data['example_text']?.toString() ?? data['example']?.toString(),
      createdBy: data['created_by']?.toString() ?? userId,
    );
    if (concept.conceptText.isEmpty) {
      debugPrint('⚠️ Skipping concept with empty text');
      return;
    }
    await _contentService.addConcepts(lessonId, [concept]);
  }

  /// Validate JSON structure
  bool validateLessonJson(String jsonString) {
    try {
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Check required fields
      if (jsonData['title'] == null || jsonData['title'].toString().trim().isEmpty) {
        return false;
      }
      
      // Check content structure
      if (jsonData['content'] is List || 
          jsonData['terms'] is List || 
          jsonData['questions'] is List || 
          jsonData['concepts'] is List) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ ERROR: Invalid JSON structure: $e');
      return false;
    }
  }
}
