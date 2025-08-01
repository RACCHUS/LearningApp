import 'package:hive/hive.dart';

part 'question.g.dart';

@HiveType(typeId: 3)
class Question {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String questionText;

  @HiveField(2)
  final List<String> options;

  @HiveField(3)
  final int correctAnswer;

  @HiveField(4)
  final String type;

  @HiveField(5)
  final String? explanation;

  @HiveField(6)
  final String createdBy;

  @HiveField(7)
  final DateTime createdAt;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.type,
    this.explanation,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Question copyWith({
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
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      type: type ?? this.type,
      explanation: explanation ?? this.explanation,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correct_answer'] as int,
      type: json['type'] as String,
      explanation: json['explanation'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'type': type,
        'explanation': explanation,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Question &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          questionText == other.questionText &&
          correctAnswer == other.correctAnswer;

  @override
  int get hashCode => id.hashCode ^ questionText.hashCode ^ correctAnswer.hashCode;
}
