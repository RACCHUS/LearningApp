import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';

/// Reusable test fixtures for creating test data
class TestFixtures {
  /// Create a test lesson with optional parameters
  static Lesson createTestLesson({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    String? userId,
    List<Term>? terms,
    List<Question>? questions,
    List<Concept>? concepts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return Lesson(
      id: id ?? 'test-lesson-1',
      title: title ?? 'Test Lesson',
      description: description ?? 'Test lesson description',
      tags: tags ?? ['test', 'demo'],
      userId: userId ?? 'test-user-1',
      terms: terms ?? [],
      questions: questions ?? [],
      concepts: concepts ?? [],
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  /// Create a test term
  static Term createTestTerm({
    String? id,
    String? term,
    String? definition,
    String? example,
    String? createdBy,
  }) {
    return Term(
      id: id ?? 'test-term-1',
      term: term ?? 'Test Term',
      definition: definition ?? 'Test definition',
      example: example,
      createdBy: createdBy ?? 'test-user-1',
    );
  }

  /// Create a test question
  static Question createTestQuestion({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctAnswer,
    String? type,
    String? explanation,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? 'test-question-1',
      questionText: questionText ?? 'What is 2+2?',
      options: options ?? ['2', '3', '4', '5'],
      correctAnswer: correctAnswer ?? 2,
      type: type ?? 'mcq',
      explanation: explanation,
      createdBy: createdBy ?? 'test-user-1',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Create a test concept
  static Concept createTestConcept({
    String? id,
    String? lessonId,
    String? conceptText,
    String? exampleText,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Concept(
      id: id ?? 'test-concept-1',
      lessonId: lessonId ?? 'test-lesson-1',
      conceptText: conceptText ?? 'This is a test concept',
      exampleText: exampleText ?? 'This is an example',
      createdBy: createdBy ?? 'test-user-1',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Create test term content
  static TermContent createTestTermContent({
    String? id,
    String? lessonId,
    int? order,
    String? term,
    String? definition,
    String? example,
  }) {
    final now = DateTime.now();
    return TermContent(
      id: id ?? 'test-term-content-1',
      lessonId: lessonId ?? 'test-lesson-1',
      order: order ?? 0,
      term: term ?? 'Test Term',
      definition: definition ?? 'Test definition',
      example: example ?? 'Test example',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create test question content
  static QuestionContent createTestQuestionContent({
    String? id,
    String? lessonId,
    int? order,
    String? questionText,
    List<String>? options,
    int? correctAnswer,
    String? explanation,
  }) {
    final now = DateTime.now();
    return QuestionContent(
      id: id ?? 'test-question-content-1',
      lessonId: lessonId ?? 'test-lesson-1',
      order: order ?? 0,
      questionText: questionText ?? 'What is 2+2?',
      options: options ?? ['2', '3', '4', '5'],
      correctAnswer: correctAnswer ?? 2,
      explanation: explanation,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create test concept content
  static ConceptContent createTestConceptContent({
    String? id,
    String? lessonId,
    int? order,
    String? conceptText,
    String? exampleText,
    List<String>? keyPoints,
  }) {
    final now = DateTime.now();
    return ConceptContent(
      id: id ?? 'test-concept-content-1',
      lessonId: lessonId ?? 'test-lesson-1',
      order: order ?? 0,
      conceptText: conceptText ?? 'Test concept text',
      exampleText: exampleText ?? 'Test example',
      keyPoints: keyPoints,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create test audio lesson settings
  static AudioLessonSettings createTestAudioSettings({
    bool? handsFreeModeEnabled,
    bool? voiceNavigationEnabled,
    bool? confirmationsEnabled,
    Duration? autoProgressDelay,
    Duration? voiceInputTimeout,
    int? voiceRetryAttempts,
    bool? autoReadAllContent,
    double? pauseBetweenItems,
    bool? autoProgressAfterReading,
    bool? immediateAnswerProgression,
    bool? interruptOnNextCommand,
  }) {
    return AudioLessonSettings(
      handsFreeModeEnabled: handsFreeModeEnabled ?? false,
      voiceNavigationEnabled: voiceNavigationEnabled ?? false,
      confirmationsEnabled: confirmationsEnabled ?? true,
      autoProgressDelay: autoProgressDelay ?? const Duration(seconds: 3),
      voiceInputTimeout: voiceInputTimeout ?? const Duration(seconds: 5),
      voiceRetryAttempts: voiceRetryAttempts ?? 2,
      autoReadAllContent: autoReadAllContent ?? true,
      pauseBetweenItems: pauseBetweenItems ?? 1.0,
      autoProgressAfterReading: autoProgressAfterReading ?? false,
      immediateAnswerProgression: immediateAnswerProgression ?? true,
      interruptOnNextCommand: interruptOnNextCommand ?? true,
    );
  }

  /// Create a lesson with full content for testing
  static Lesson createFullTestLesson() {
    return createTestLesson(
      id: 'full-test-lesson',
      title: 'Complete Test Lesson',
      description: 'A lesson with all types of content',
      tags: ['comprehensive', 'test'],
      terms: [
        createTestTerm(id: 'term-1', term: 'Term 1'),
        createTestTerm(id: 'term-2', term: 'Term 2'),
      ],
      questions: [
        createTestQuestion(id: 'q-1', questionText: 'Question 1?'),
        createTestQuestion(id: 'q-2', questionText: 'Question 2?'),
      ],
      concepts: [
        createTestConcept(id: 'c-1', conceptText: 'Concept 1'),
        createTestConcept(id: 'c-2', conceptText: 'Concept 2'),
      ],
    );
  }

  /// Create a list of mixed lesson content
  static List<LessonContent> createMixedContentList() {
    return [
      createTestTermContent(id: 'tc-1', order: 0),
      createTestQuestionContent(id: 'qc-1', order: 1),
      createTestConceptContent(id: 'cc-1', order: 2),
      createTestTermContent(id: 'tc-2', order: 3),
    ];
  }
}
