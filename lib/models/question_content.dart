import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:learning_pwa/models/lesson_content.dart';

part 'question_content.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
class QuestionContent extends LessonContent {
  @HiveField(6)
  final String questionText;

  @HiveField(7)
  final List<String> options;

  @HiveField(8)
  final int correctAnswer;

  @HiveField(9)
  final String? explanation;

  /// Declared kind: 'mcq', 'true_false' or 'short_answer'.
  @HiveField(10)
  final String? questionType;

  /// Short answer: every response that counts as correct.
  @HiveField(11)
  final List<String>? acceptedAnswers;

  /// Short answer: 'exact', 'normalized_text' (default) or 'numeric'.
  @HiveField(12)
  final String? gradingMethod;

  /// Numeric grading: allowed absolute difference.
  @HiveField(13)
  final double? numericTolerance;

  QuestionContent({
    required super.id,
    required super.lessonId,
    required super.order,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.questionType,
    this.acceptedAnswers,
    this.gradingMethod,
    this.numericTolerance,
    required super.createdAt,
    required super.updatedAt,
  }) : super(
          type: 'question',
        );

  static const supportedQuestionTypes = {'mcq', 'true_false', 'short_answer'};

  /// The declared type, or one inferred from the options for older data.
  String get effectiveQuestionType {
    final declared = questionType?.trim().toLowerCase();
    if (declared != null && supportedQuestionTypes.contains(declared)) {
      return declared;
    }
    if ((acceptedAnswers?.isNotEmpty ?? false) || options.length <= 1) {
      return 'short_answer';
    }
    final lower = options.map((o) => o.trim().toLowerCase()).toList();
    if (lower.length == 2 && lower[0] == 'true' && lower[1] == 'false') {
      return 'true_false';
    }
    return 'mcq';
  }

  factory QuestionContent.fromJson(Map<String, dynamic> json) => 
    _$QuestionContentFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = _$QuestionContentToJson(this);
    json['type'] = type;
    return json;
  }
}
