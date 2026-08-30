import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/lesson.dart';
import '../models/term.dart';
import '../models/question.dart';
import '../models/concept.dart';
import '../services/lesson_service.dart';

/// State for the lesson editor
class LessonEditorState {
  final String? lessonId;
  final String title;
  final String? description;
  final List<String> tags;
  final List<Term> terms;
  final List<Question> questions;
  final List<Concept> concepts;
  final bool isDirty;
  final bool isSaving;
  final bool isLoading;
  final String? errorMessage;

  const LessonEditorState({
    this.lessonId,
    this.title = '',
    this.description,
    this.tags = const [],
    this.terms = const [],
    this.questions = const [],
    this.concepts = const [],
    this.isDirty = false,
    this.isSaving = false,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isNewLesson => lessonId == null;

  bool get isValid => title.trim().length >= 3 && hasContent;

  bool get hasContent =>
      terms.isNotEmpty || questions.isNotEmpty || concepts.isNotEmpty;

  int get totalContentCount =>
      terms.length + questions.length + concepts.length;

  LessonEditorState copyWith({
    String? lessonId,
    String? title,
    String? description,
    List<String>? tags,
    List<Term>? terms,
    List<Question>? questions,
    List<Concept>? concepts,
    bool? isDirty,
    bool? isSaving,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LessonEditorState(
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      terms: terms ?? this.terms,
      questions: questions ?? this.questions,
      concepts: concepts ?? this.concepts,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for managing lesson editor state
class LessonEditorNotifier extends StateNotifier<LessonEditorState> {
  final LessonService _lessonService;
  final String? _userId;
  final Uuid _uuid = const Uuid();

  LessonEditorNotifier({
    required LessonService lessonService,
    String? userId,
    String? lessonId,
  })  : _lessonService = lessonService,
        _userId = userId,
        super(const LessonEditorState()) {
    if (lessonId != null) {
      _loadLesson(lessonId);
    }
  }

  Future<void> _loadLesson(String lessonId) async {
    state = state.copyWith(isLoading: true);
    try {
      final lesson = await _lessonService.getLesson(lessonId);
      state = LessonEditorState(
        lessonId: lesson.id,
        title: lesson.title,
        description: lesson.description,
        tags: lesson.tags,
        terms: lesson.terms,
        questions: lesson.questions,
        concepts: lesson.concepts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load lesson: $e',
      );
    }
  }

  // ============================================================================
  // BASIC FIELDS
  // ============================================================================

  void setTitle(String title) {
    state = state.copyWith(title: title, isDirty: true);
  }

  void setDescription(String? description) {
    state = state.copyWith(description: description, isDirty: true);
  }

  void setTags(List<String> tags) {
    state = state.copyWith(tags: tags, isDirty: true);
  }

  void addTag(String tag) {
    if (tag.trim().isEmpty) return;
    final newTags = [...state.tags, tag.trim()];
    state = state.copyWith(tags: newTags, isDirty: true);
  }

  void removeTag(String tag) {
    final newTags = state.tags.where((t) => t != tag).toList();
    state = state.copyWith(tags: newTags, isDirty: true);
  }

  // ============================================================================
  // TERMS
  // ============================================================================

  void addTerm(Term term) {
    final newTerms = [...state.terms, term];
    state = state.copyWith(terms: newTerms, isDirty: true);
  }

  void updateTerm(String termId, Term updatedTerm) {
    final newTerms = state.terms.map((t) {
      return t.id == termId ? updatedTerm : t;
    }).toList();
    state = state.copyWith(terms: newTerms, isDirty: true);
  }

  void removeTerm(String termId) {
    final newTerms = state.terms.where((t) => t.id != termId).toList();
    state = state.copyWith(terms: newTerms, isDirty: true);
  }

  void reorderTerms(int oldIndex, int newIndex) {
    final newTerms = List<Term>.from(state.terms);
    if (newIndex > oldIndex) newIndex--;
    final item = newTerms.removeAt(oldIndex);
    newTerms.insert(newIndex, item);
    state = state.copyWith(terms: newTerms, isDirty: true);
  }

  Term createEmptyTerm() {
    return Term(
      id: _uuid.v4(),
      term: '',
      definition: '',
      createdBy: _userId ?? 'unknown',
    );
  }

  // ============================================================================
  // QUESTIONS
  // ============================================================================

  void addQuestion(Question question) {
    final newQuestions = [...state.questions, question];
    state = state.copyWith(questions: newQuestions, isDirty: true);
  }

  void updateQuestion(String questionId, Question updatedQuestion) {
    final newQuestions = state.questions.map((q) {
      return q.id == questionId ? updatedQuestion : q;
    }).toList();
    state = state.copyWith(questions: newQuestions, isDirty: true);
  }

  void removeQuestion(String questionId) {
    final newQuestions =
        state.questions.where((q) => q.id != questionId).toList();
    state = state.copyWith(questions: newQuestions, isDirty: true);
  }

  void reorderQuestions(int oldIndex, int newIndex) {
    final newQuestions = List<Question>.from(state.questions);
    if (newIndex > oldIndex) newIndex--;
    final item = newQuestions.removeAt(oldIndex);
    newQuestions.insert(newIndex, item);
    state = state.copyWith(questions: newQuestions, isDirty: true);
  }

  Question createEmptyQuestion() {
    return Question(
      id: _uuid.v4(),
      questionText: '',
      options: ['', '', '', ''],
      correctAnswer: 0,
      type: 'multiple_choice',
      createdBy: _userId ?? 'unknown',
      createdAt: DateTime.now(),
    );
  }

  // ============================================================================
  // CONCEPTS
  // ============================================================================

  void addConcept(Concept concept) {
    final newConcepts = [...state.concepts, concept];
    state = state.copyWith(concepts: newConcepts, isDirty: true);
  }

  void updateConcept(String conceptId, Concept updatedConcept) {
    final newConcepts = state.concepts.map((c) {
      return c.id == conceptId ? updatedConcept : c;
    }).toList();
    state = state.copyWith(concepts: newConcepts, isDirty: true);
  }

  void removeConcept(String conceptId) {
    final newConcepts =
        state.concepts.where((c) => c.id != conceptId).toList();
    state = state.copyWith(concepts: newConcepts, isDirty: true);
  }

  void reorderConcepts(int oldIndex, int newIndex) {
    final newConcepts = List<Concept>.from(state.concepts);
    if (newIndex > oldIndex) newIndex--;
    final item = newConcepts.removeAt(oldIndex);
    newConcepts.insert(newIndex, item);
    state = state.copyWith(concepts: newConcepts, isDirty: true);
  }

  Concept createEmptyConcept(String lessonId) {
    return Concept(
      id: _uuid.v4(),
      lessonId: lessonId,
      conceptText: '',
      createdBy: _userId ?? 'unknown',
      createdAt: DateTime.now(),
    );
  }

  // ============================================================================
  // SAVE
  // ============================================================================

  Future<Lesson?> save() async {
    if (!state.isValid) {
      state = state.copyWith(
        errorMessage: 'Please add a title and at least one content item',
      );
      return null;
    }

    if (_userId == null) {
      state = state.copyWith(errorMessage: 'User not authenticated');
      return null;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      Lesson lesson;

      if (state.isNewLesson) {
        // Create new lesson
        lesson = await _lessonService.addLesson(
          state.title,
          state.description,
          _userId,
          tags: state.tags,
        );

        // Add content
        if (state.terms.isNotEmpty) {
          await _lessonService.addTerms(lesson.id, state.terms);
        }
        if (state.questions.isNotEmpty) {
          await _lessonService.addQuestions(lesson.id, state.questions);
        }
        if (state.concepts.isNotEmpty) {
          await _lessonService.addConcepts(lesson.id, state.concepts);
        }

        // Refresh to get complete lesson
        lesson = await _lessonService.getLesson(lesson.id);
      } else {
        // Update existing lesson metadata
        lesson = await _lessonService.updateLesson(
          state.lessonId!,
          title: state.title,
          description: state.description,
          tags: state.tags,
        );
        
        // Refresh to get complete lesson with content
        lesson = await _lessonService.getLesson(lesson.id);
        
        // Return updated lesson with current content
        lesson = lesson.copyWith(
          terms: state.terms,
          questions: state.questions,
          concepts: state.concepts,
        );
      }

      state = state.copyWith(
        lessonId: lesson.id,
        isSaving: false,
        isDirty: false,
      );

      debugPrint('✅ Lesson saved: ${lesson.id}');
      return lesson;
    } catch (e) {
      debugPrint('❌ Error saving lesson: $e');
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save lesson: $e',
      );
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// Provider for lesson editor
final lessonEditorProvider = StateNotifierProvider.autoDispose
    .family<LessonEditorNotifier, LessonEditorState, String?>(
  (ref, lessonId) {
    final lessonService = LessonService();
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    
    return LessonEditorNotifier(
      lessonService: lessonService,
      userId: userId,
      lessonId: lessonId,
    );
  },
);
