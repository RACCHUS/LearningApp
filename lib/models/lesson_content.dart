abstract class LessonContent {
  String get id;
  String get type;
  String get createdBy;
  
  Map<String, dynamic> toJson();
}

class TermContent extends LessonContent {
  @override
  final String id;
  @override
  final String type = 'term';
  final String term;
  final String definition;
  final String? example;
  @override
  final String createdBy;

  TermContent({
    required this.id,
    required this.term,
    required this.definition,
    this.example,
    required this.createdBy,
  });
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'term': term,
      'definition': definition,
      'example': example,
      'created_by': createdBy,
    };
  }
  
  factory TermContent.fromJson(Map<String, dynamic> json) {
    return TermContent(
      id: json['id'] as String,
      term: json['term'] as String,
      definition: json['definition'] as String,
      example: json['example'] as String?,
      createdBy: json['created_by'] as String,
    );
  }
}

class QuestionContent extends LessonContent {
  @override
  final String id;
  @override
  final String type = 'question';
  final String questionText;
  final List<String> options;
  final int correctAnswer;
  final String? explanation;
  @override
  final String createdBy;
  final int orderIndex;

  QuestionContent({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    required this.createdBy,
    this.orderIndex = 0,
  });
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'question_text': questionText,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'created_by': createdBy,
      'order_index': orderIndex,
    };
  }
  
  factory QuestionContent.fromJson(Map<String, dynamic> json) {
    return QuestionContent(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correct_answer'] as int,
      explanation: json['explanation'] as String?,
      createdBy: json['created_by'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }
}

class ConceptContent extends LessonContent {
  @override
  final String id;
  @override
  final String type = 'concept';
  final String conceptText;
  final String? exampleText;
  final List<String>? keyPoints;
  @override
  final String createdBy;

  ConceptContent({
    required this.id,
    required this.conceptText,
    this.exampleText,
    this.keyPoints,
    required this.createdBy,
  });
  
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'concept_text': conceptText,
      'example_text': exampleText,
      'key_points': keyPoints,
      'created_by': createdBy,
    };
  }
  
  factory ConceptContent.fromJson(Map<String, dynamic> json) {
    return ConceptContent(
      id: json['id'] as String,
      conceptText: json['concept_text'] as String,
      exampleText: json['example_text'] as String?,
      keyPoints: json['key_points'] != null 
          ? List<String>.from(json['key_points'] as List) 
          : null,
      createdBy: json['created_by'] as String,
    );
  }
}
