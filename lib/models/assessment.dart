import 'package:learning_pwa/models/skill.dart';

/// Skill Assessment - test definition for evaluating a skill
class SkillAssessment {
  final String id;
  final String skillId;
  final String title;
  final String? description;
  final int questionCount;
  final int timeLimitMinutes;
  final int passingScore;
  final AssessmentDifficulty difficulty;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Populated from joins
  final Skill? skill;
  final List<AssessmentQuestion>? questions;

  const SkillAssessment({
    required this.id,
    required this.skillId,
    required this.title,
    this.description,
    this.questionCount = 10,
    this.timeLimitMinutes = 15,
    this.passingScore = 70,
    this.difficulty = AssessmentDifficulty.intermediate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.skill,
    this.questions,
  });

  factory SkillAssessment.fromJson(Map<String, dynamic> json) {
    return SkillAssessment(
      id: json['id'] as String,
      skillId: json['skill_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      questionCount: json['question_count'] as int? ?? 10,
      timeLimitMinutes: json['time_limit_minutes'] as int? ?? 15,
      passingScore: json['passing_score'] as int? ?? 70,
      difficulty:
          AssessmentDifficulty.fromString(json['difficulty'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      skill: json['skills'] != null ? Skill.fromJson(json['skills']) : null,
      questions: json['assessment_questions'] != null
          ? (json['assessment_questions'] as List)
              .map((q) => AssessmentQuestion.fromJson(q))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'skill_id': skillId,
        'title': title,
        'description': description,
        'question_count': questionCount,
        'time_limit_minutes': timeLimitMinutes,
        'passing_score': passingScore,
        'difficulty': difficulty.value,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Duration get timeLimit => Duration(minutes: timeLimitMinutes);

  SkillAssessment copyWith({
    String? id,
    String? skillId,
    String? title,
    String? description,
    int? questionCount,
    int? timeLimitMinutes,
    int? passingScore,
    AssessmentDifficulty? difficulty,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Skill? skill,
    List<AssessmentQuestion>? questions,
  }) {
    return SkillAssessment(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      title: title ?? this.title,
      description: description ?? this.description,
      questionCount: questionCount ?? this.questionCount,
      timeLimitMinutes: timeLimitMinutes ?? this.timeLimitMinutes,
      passingScore: passingScore ?? this.passingScore,
      difficulty: difficulty ?? this.difficulty,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      skill: skill ?? this.skill,
      questions: questions ?? this.questions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SkillAssessment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Assessment question
class AssessmentQuestion {
  final String id;
  final String assessmentId;
  final String questionText;
  final List<String> options;
  final int correctAnswer; // 0-based index
  final String? explanation;
  final int orderIndex;
  final DateTime createdAt;

  const AssessmentQuestion({
    required this.id,
    required this.assessmentId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.orderIndex = 0,
    required this.createdAt,
  });

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    return AssessmentQuestion(
      id: json['id'] as String,
      assessmentId: json['assessment_id'] as String,
      questionText: json['question_text'] as String,
      options: (json['options'] as List).cast<String>(),
      correctAnswer: json['correct_answer'] as int,
      explanation: json['explanation'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assessment_id': assessmentId,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'explanation': explanation,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
      };

  bool isCorrect(int answerIndex) => answerIndex == correctAnswer;
}

/// User's attempt at an assessment
class AssessmentAttempt {
  final String id;
  final String assessmentId;
  final String userId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? score;
  final int correctCount;
  final int totalQuestions;
  final int? timeTakenSeconds;
  final bool wasOvertime;
  final bool isVerified;
  final bool isDeleted;
  final Map<String, int>? answers; // question_id -> chosen answer index
  final DateTime createdAt;

  // Populated from joins
  final SkillAssessment? assessment;

  const AssessmentAttempt({
    required this.id,
    required this.assessmentId,
    required this.userId,
    required this.startedAt,
    this.completedAt,
    this.score,
    this.correctCount = 0,
    this.totalQuestions = 0,
    this.timeTakenSeconds,
    this.wasOvertime = false,
    this.isVerified = true,
    this.isDeleted = false,
    this.answers,
    required this.createdAt,
    this.assessment,
  });

  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) {
    return AssessmentAttempt(
      id: json['id'] as String,
      assessmentId: json['assessment_id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      score: json['score'] as int?,
      correctCount: json['correct_count'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      timeTakenSeconds: json['time_taken_seconds'] as int?,
      wasOvertime: json['was_overtime'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? true,
      isDeleted: json['is_deleted'] as bool? ?? false,
      answers: json['answers'] != null
          ? (json['answers'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v as int))
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      assessment: json['skill_assessments'] != null
          ? SkillAssessment.fromJson(json['skill_assessments'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assessment_id': assessmentId,
        'user_id': userId,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'score': score,
        'correct_count': correctCount,
        'total_questions': totalQuestions,
        'time_taken_seconds': timeTakenSeconds,
        'was_overtime': wasOvertime,
        'is_verified': isVerified,
        'is_deleted': isDeleted,
        'answers': answers,
        'created_at': createdAt.toIso8601String(),
      };

  bool get isCompleted => completedAt != null;
  bool get isPassed => score != null && score! >= 70; // Default passing score

  Duration? get timeTaken =>
      timeTakenSeconds != null ? Duration(seconds: timeTakenSeconds!) : null;

  double get accuracy =>
      totalQuestions > 0 ? correctCount / totalQuestions : 0;

  AssessmentAttempt copyWith({
    String? id,
    String? assessmentId,
    String? userId,
    DateTime? startedAt,
    DateTime? completedAt,
    int? score,
    int? correctCount,
    int? totalQuestions,
    int? timeTakenSeconds,
    bool? wasOvertime,
    bool? isVerified,
    bool? isDeleted,
    Map<String, int>? answers,
    DateTime? createdAt,
    SkillAssessment? assessment,
  }) {
    return AssessmentAttempt(
      id: id ?? this.id,
      assessmentId: assessmentId ?? this.assessmentId,
      userId: userId ?? this.userId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      score: score ?? this.score,
      correctCount: correctCount ?? this.correctCount,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      timeTakenSeconds: timeTakenSeconds ?? this.timeTakenSeconds,
      wasOvertime: wasOvertime ?? this.wasOvertime,
      isVerified: isVerified ?? this.isVerified,
      isDeleted: isDeleted ?? this.isDeleted,
      answers: answers ?? this.answers,
      createdAt: createdAt ?? this.createdAt,
      assessment: assessment ?? this.assessment,
    );
  }
}

/// Assessment difficulty levels
enum AssessmentDifficulty {
  beginner('beginner', 'Beginner', '🟢'),
  intermediate('intermediate', 'Intermediate', '🟡'),
  advanced('advanced', 'Advanced', '🔴');

  final String value;
  final String displayName;
  final String emoji;

  const AssessmentDifficulty(this.value, this.displayName, this.emoji);

  static AssessmentDifficulty fromString(String? value) {
    return AssessmentDifficulty.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AssessmentDifficulty.intermediate,
    );
  }

  String get fullDisplayName => '$emoji $displayName';
}

/// Result of a completed assessment (computed, not stored)
class AssessmentResult {
  final AssessmentAttempt attempt;
  final SkillAssessment assessment;
  final int previousLevel;
  final int newLevel;
  final bool passed;
  final List<QuestionResult> questionResults;

  const AssessmentResult({
    required this.attempt,
    required this.assessment,
    required this.previousLevel,
    required this.newLevel,
    required this.passed,
    required this.questionResults,
  });

  int get levelChange => newLevel - previousLevel;
  bool get leveledUp => newLevel > previousLevel;
}

/// Result for a single question (computed, not stored)
class QuestionResult {
  final AssessmentQuestion question;
  final int? userAnswer;
  final bool isCorrect;

  const QuestionResult({
    required this.question,
    this.userAnswer,
    required this.isCorrect,
  });
}
