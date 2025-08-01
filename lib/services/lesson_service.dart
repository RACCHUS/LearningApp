import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/text_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class LessonService {
  final _supabase = Supabase.instance.client;

  // Get all lessons for a user
  Future<List<Lesson>> getLessonsForUser(String userId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      // Handle empty response
      if (response.isEmpty) {
        return [];
      }

      return response.map<Lesson>((data) => Lesson(
        id: data['id']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Untitled',
        description: data['description']?.toString(),
        tags: data['tags'] is List ? List<String>.from(data['tags']) : <String>[],
        createdAt: data['created_at'] != null 
            ? DateTime.parse(data['created_at']) 
            : DateTime.now(),
        updatedAt: data['updated_at'] != null 
            ? DateTime.parse(data['updated_at']) 
            : DateTime.now(),
        userId: data['user_id']?.toString() ?? userId,
        terms: <Term>[], // Load separately if needed
        questions: <Question>[], // Load separately if needed
        concepts: <Concept>[], // Load separately if needed
      )).toList();
    } catch (e) {
      debugPrint('Error getting lessons for user: $e');
      return []; // Return empty list instead of rethrowing
    }
  }

  // Get a lesson with all its content
  Future<Lesson> getLesson(String lessonId) async {
    try {
      // Get the lesson with all related content
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            terms:term_relations(
              term:terms(*)
            ),
            questions:question_relations(
              question:questions(*)
            ),
            concepts:concept_relations(
              concept:concepts(*)
            )
          ''')
          .eq('id', lessonId)
          .single();

      // Transform the response into our Lesson model
      return Lesson(
        id: response['id'],
        title: response['title'],
        description: response['description'],
        tags: List<String>.from(response['tags'] ?? []),
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'],
        terms: _parseTerms(response['terms'] as List<dynamic>?),
        questions: _parseQuestions(response['questions'] as List<dynamic>?),
        concepts: _parseConcepts(response['concepts'] as List<dynamic>?),
      );
    } catch (e) {
      debugPrint('Error getting lesson: $e');
      rethrow;
    }
  }

  List<Term> _parseTerms(List<dynamic>? termsData) {
    if (termsData == null || termsData.isEmpty) {
      return [];
    }
    return termsData
        .map((t) => Term(
              id: t['term']['id'],
              term: t['term']['term'],
              definition: t['term']['definition'],
              example: t['term']['example'],
              createdBy: t['term']['created_by'],
            ))
        .toList();
  }

  List<Question> _parseQuestions(List<dynamic>? questionsData) {
    if (questionsData == null || questionsData.isEmpty) {
      return [];
    }
    return questionsData
        .map((q) => Question(
              id: q['question']['id'],
              questionText: q['question']['question_text'],
              correctAnswer: q['question']['correct_answer'],
              options: List<String>.from(q['question']['options']),
              type: q['question']['type'],
              explanation: q['question']['explanation'],
              createdBy: q['question']['created_by'],
            ))
        .toList();
  }

  List<Concept> _parseConcepts(List<dynamic>? conceptsData) {
    if (conceptsData == null || conceptsData.isEmpty) {
      return [];
    }
    return conceptsData
        .map((c) => Concept(
              id: c['concept']['id'],
              lessonId: c['concept']['lesson_id'],
              conceptText: c['concept']['concept_text'],
              exampleText: c['concept']['example_text'],
              createdBy: c['concept']['created_by'],
              createdAt: DateTime.parse(c['concept']['created_at']),
            ))
        .toList();
  }

  // Add a new lesson
  Future<Lesson> addLesson(String title, String? description, String userId) async {
    try {
      final now = DateTime.now();
      final response = await _supabase
          .from('lessons')
          .insert({
            'id': const Uuid().v4(),
            'title': title,
            'description': description,
            'user_id': userId,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();
      
      return Lesson(
        id: response['id'],
        title: response['title'],
        description: response['description'],
        tags: List<String>.from(response['tags'] ?? []),
        userId: response['user_id'],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        terms: [],
        questions: [],
        concepts: [],
      );
    } catch (e) {
      debugPrint('Error adding lesson: $e');
      rethrow;
    }
  }

    // Add terms to a lesson
  Future<void> addTerms(String lessonId, List<Term> terms) async {
    try {
      for (var term in terms) {
        await _supabase
            .from('terms')
            .insert({
              'id': const Uuid().v4(),
              'lesson_id': lessonId,
              'term': term.term,
              'definition': term.definition,
              'example': term.example,
              'created_by': term.createdBy,
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      debugPrint('Error adding terms: $e');
      rethrow;
    }
  }

  // Add questions to a lesson
  Future<void> addQuestions(String lessonId, List<Question> questions) async {
    try {
      for (var question in questions) {
        await _supabase
            .from('questions')
            .insert({
              'id': const Uuid().v4(),
              'lesson_id': lessonId,
              'question_text': question.questionText,
              'options': question.options,
              'correct_answer': question.correctAnswer,
              'type': question.type,
              'explanation': question.explanation,
              'created_by': question.createdBy,
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      debugPrint('Error adding questions: $e');
      rethrow;
    }
  }

  // Add concepts to a lesson
  Future<void> addConcepts(String lessonId, List<Concept> concepts) async {
    try {
      for (var concept in concepts) {
        await _supabase
            .from('concepts')
            .insert({
              'id': const Uuid().v4(),
              'lesson_id': lessonId,
              'concept_text': concept.conceptText,
              'example_text': concept.exampleText,
              'created_by': concept.createdBy,
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      debugPrint('Error adding concepts: $e');
      rethrow;
    }
  }

  // Import lesson from JSON
  Future<Lesson> importLessonFromJson(String jsonString, String userId) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Extract lesson data
      final lessonData = json['lesson'] as Map<String, dynamic>;
      final contentData = json['content'] as List;
      
      // Create lesson
      final lesson = await addLesson(
        lessonData['title'] as String,
        lessonData['description'] as String?,
        userId,
      );

      // Process content
      final List<LessonContent> content = [];
      
      for (var (index, item) in contentData.indexed) {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type'] as String;
        
        switch (type) {
          case 'term':
            content.add(TermContent(
              id: itemMap['id'] ?? const Uuid().v4(),
              lessonId: lesson.id,
              order: index,
              term: itemMap['term'] as String,
              definition: itemMap['definition'] as String,
              example: itemMap['example'] as String?,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
            break;
            
          case 'mcq':
            content.add(QuestionContent(
              id: itemMap['id'] ?? const Uuid().v4(),
              lessonId: lesson.id,
              order: index,
              questionText: itemMap['question'] as String,
              options: List<String>.from(itemMap['options'] as List),
              correctAnswer: itemMap['correctIndex'] as int,
              explanation: itemMap['explanation'] as String?,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
            break;
            
          case 'concept':
            content.add(ConceptContent(
              id: itemMap['id'] ?? const Uuid().v4(),
              lessonId: lesson.id,
              order: index,
              conceptText: itemMap['title'] as String,
              exampleText: itemMap['description'] as String?,
              keyPoints: itemMap['keyPoints'] != null 
                  ? List<String>.from(itemMap['keyPoints'] as List) 
                  : null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
            break;
            
          case 'text':
            content.add(TextContent(
              id: itemMap['id'] ?? const Uuid().v4(),
              lessonId: lesson.id,
              order: index,
              text: itemMap['text'] as String,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
            break;
        }
      }

      // Add all content to the lesson
      await addLessonContent(lesson.id, content);
      
      return lesson;
    } catch (e) {
      debugPrint('Error importing lesson from JSON: $e');
      rethrow;
    }
  }

  // Add lesson content
  Future<void> addLessonContent(String lessonId, List<LessonContent> content) async {
    try {
      for (var item in content) {
        if (item is TermContent) {
          await _addTermContent(lessonId, item);
        } else if (item is QuestionContent) {
          await _addQuestionContent(lessonId, item);
        } else if (item is ConceptContent) {
          await _addConceptContent(lessonId, item);
        }
      }
    } catch (e) {
      debugPrint('Error adding lesson content: $e');
      rethrow;
    }
  }

  Future<void> _addTermContent(String lessonId, TermContent content) async {
    await _supabase.from('terms').insert({
      'id': content.id,
      'lesson_id': lessonId,
      'term': content.term,
      'definition': content.definition,
      'example': content.example,
      'created_at': content.createdAt.toIso8601String(),
      'updated_at': content.updatedAt.toIso8601String(),
    });
  }

  Future<void> _addQuestionContent(String lessonId, QuestionContent content) async {
    await _supabase.from('questions').insert({
      'id': content.id,
      'lesson_id': lessonId,
      'question_text': content.questionText,
      'options': content.options,
      'correct_answer': content.correctAnswer,
      'explanation': content.explanation,
      'created_at': content.createdAt.toIso8601String(),
      'updated_at': content.updatedAt.toIso8601String(),
    });
  }

  Future<void> _addConceptContent(String lessonId, ConceptContent content) async {
    await _supabase.from('concepts').insert({
      'id': content.id,
      'lesson_id': lessonId,
      'concept_text': content.conceptText,
      'example_text': content.exampleText,
      'key_points': content.keyPoints,
      'created_at': content.createdAt.toIso8601String(),
      'updated_at': content.updatedAt.toIso8601String(),
    });
  }
}
