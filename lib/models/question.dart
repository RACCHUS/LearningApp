import 'package:hive/hive.dart';
import 'package:learning_pwa/core/errors/model_parse_exception.dart';

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
    final id = json['id']?.toString();
    final questionText = json['question_text']?.toString();
    final optionsRaw = json['options'];
    final correctAnswer = json['correct_answer'];
    final type = json['type']?.toString();
    final explanation = json['explanation']?.toString();
    // Accept both 'created_by' and 'user_id' for compatibility
    final createdBy = (json['created_by'] ?? json['user_id'])?.toString();
    final createdAtRaw = json['created_at']?.toString();
    final missing = <String>[
      if (id == null) 'id',
      if (questionText == null) 'question_text',
      if (optionsRaw == null) 'options',
      if (correctAnswer == null) 'correct_answer',
      if (type == null) 'type',
      if (createdBy == null) 'created_by',
      if (createdAtRaw == null) 'created_at',
    ];
    if (missing.isNotEmpty) {
      throw ModelParseException(
        'Question',
        'Missing required field(s)',
        fields: missing,
      );
    }
    List<String> options;
    try {
      options = List<String>.from(optionsRaw as List);
    } catch (_) {
      throw const ModelParseException(
        'Question',
        'Invalid options format (expected a list)',
        fields: ['options'],
      );
    }
    final createdAt = DateTime.tryParse(createdAtRaw!);
    if (createdAt == null) {
      throw const ModelParseException(
        'Question',
        'Invalid date format',
        fields: ['created_at'],
      );
    }
    return Question(
      id: id!,
      questionText: questionText!,
      options: options,
      correctAnswer: correctAnswer is int ? correctAnswer : int.tryParse(correctAnswer.toString()) ?? 0,
      type: type!,
      explanation: explanation,
      createdBy: createdBy!,
      createdAt: createdAt,
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
