class Question {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswer;
  final String type;
  final String? explanation;
  final String createdBy;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.type,
    this.explanation,
    required this.createdBy,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      questionText: json['question_text'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correct_answer'],
      type: json['type'],
      explanation: json['explanation'],
      createdBy: json['created_by'],
    );
  }
}
