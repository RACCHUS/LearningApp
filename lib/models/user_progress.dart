class UserProgress {
  final String id;
  final String userId;
  final String lessonId;
  final DateTime date;
  final int questionsAnswered;
  final int correctCount;
  final bool lessonCompleted;
  final int studyTimeMinutes;

  UserProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.date,
    required this.questionsAnswered,
    required this.correctCount,
    required this.lessonCompleted,
    required this.studyTimeMinutes,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'],
      userId: json['user_id'],
      lessonId: json['lesson_id'],
      date: DateTime.parse(json['date']),
      questionsAnswered: json['questions_answered'],
      correctCount: json['correct_count'],
      lessonCompleted: json['lesson_completed'],
      studyTimeMinutes: json['study_time_minutes'],
    );
  }
}
