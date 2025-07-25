sealed class LessonContent {}

class TermContent extends LessonContent {
  final String id;
  final String term;
  final String definition;
  final String? example;
  final String createdBy;

  TermContent({
    required this.id,
    required this.term,
    required this.definition,
    this.example,
    required this.createdBy,
  });
}

class QuestionContent extends LessonContent {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswer;
  final String type;
  final String? explanation;
  final String createdBy;
  final int orderIndex;

  QuestionContent({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.type,
    this.explanation,
    required this.createdBy,
    required this.orderIndex,
  });
}

class ConceptContent extends LessonContent {
  final String id;
  final String conceptText;
  final String? exampleText;
  final String createdBy;

  ConceptContent({
    required this.id,
    required this.conceptText,
    this.exampleText,
    required this.createdBy,
  });
}
