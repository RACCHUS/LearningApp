class OfflineContent {
  final String id;
  final String userId;
  final String lessonId;
  final DateTime cachedAt;

  OfflineContent({
    required this.id,
    required this.userId,
    required this.lessonId,
    required this.cachedAt,
  });

  factory OfflineContent.fromJson(Map<String, dynamic> json) {
    return OfflineContent(
      id: json['id'],
      userId: json['user_id'],
      lessonId: json['lesson_id'],
      cachedAt: DateTime.parse(json['cached_at']),
    );
  }
}
