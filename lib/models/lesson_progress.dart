enum StudyMode { flashcard, mcq, concept, lesson }

class UserProgress {
  final String id;
  final String userId;
  final String lessonId;
  final String? contentId; // ID of the specific content item (term, question, concept)
  final StudyMode studyMode;
  final DateTime date;
  final int questionsAnswered;
  final int correctCount;
  final bool lessonCompleted;
  final int studyTimeSeconds; // More granular than minutes
  final int? lastPosition; // Last position (e.g., index in lesson content) for resume
  final bool isSynced; // Whether this progress has been synced to the server
  final Map<String, dynamic>? metadata; // Additional data like difficulty, tags, etc.
  
  // Getter for backward compatibility with studyTimeMinutes
  int get studyTimeMinutes => (studyTimeSeconds / 60).ceil();

  UserProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    this.contentId,
    required this.studyMode,
    required this.date,
    required this.questionsAnswered,
    required this.correctCount,
    required this.lessonCompleted,
    required this.studyTimeSeconds,
    this.lastPosition,
    this.isSynced = false,
    this.metadata,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      id: json['id'],
      userId: json['user_id'],
      lessonId: json['lesson_id'],
      contentId: json['content_id'],
      studyMode: StudyMode.values.firstWhere(
        (e) => e.toString() == 'StudyMode.${json['study_mode']}',
        orElse: () => StudyMode.lesson,
      ),
      date: DateTime.parse(json['date']),
      questionsAnswered: json['questions_answered'] ?? 0,
      correctCount: json['correct_count'] ?? 0,
      lessonCompleted: json['lesson_completed'] ?? false,
      studyTimeSeconds: json['study_time_seconds'] ?? (json['study_time_minutes'] != null ? (json['study_time_minutes'] as int) * 60 : 0),
      lastPosition: json['last_position'],
      isSynced: json['is_synced'] ?? true, // Assume synced if coming from server
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lesson_id': lessonId,
      'content_id': contentId,
      'study_mode': studyMode.toString().split('.').last,
      'date': date.toIso8601String(),
      'questions_answered': questionsAnswered,
      'correct_count': correctCount,
      'lesson_completed': lessonCompleted,
      'study_time_seconds': studyTimeSeconds,
      'study_time_minutes': studyTimeSeconds ~/ 60, // For backward compatibility
      'last_position': lastPosition,
      'is_synced': isSynced,
      'metadata': metadata,
    };
  }

  /// Create a server-side event without leaking local Hive-only fields.
  /// Question counters and unverified historical time are not uploaded.
  Map<String, dynamic>? toServerProgressEvent() {
    if (id.isEmpty || userId.isEmpty || lessonId.isEmpty) return null;
    final action = lessonCompleted
        ? 'lesson_completed'
        : (metadata?['completion_override'] == true
            ? 'lesson_uncompleted'
            : null);
    if (action == null) return null;
    final explicitKind = metadata?['content_kind'];
    final contentKind = explicitKind == 'legacy_lesson' ||
            explicitKind == 'bundled_asset_lesson' ||
            explicitKind == 'curriculum_node_lesson'
        ? explicitKind as String
        : (isLegacyProgressLessonId(lessonId)
            ? 'legacy_lesson'
            : 'bundled_asset_lesson');
    final rawVersion = metadata?['version_key'];
    final version = rawVersion is String && rawVersion.isNotEmpty
        ? rawVersion
        : 'unversioned';
    return <String, dynamic>{
      'idempotency_key': id,
      'event_type': action,
      'content_kind': contentKind,
      'content_id': lessonId,
      'version_key': version,
      'occurred_at': date.toUtc().toIso8601String(),
    };
  }

  // Helper methods
  double get accuracy => questionsAnswered > 0 ? correctCount / questionsAnswered : 0;
  
  Duration get studyDuration => Duration(seconds: studyTimeSeconds);
  
  UserProgress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    String? contentId,
    StudyMode? studyMode,
    DateTime? date,
    int? questionsAnswered,
    int? correctCount,
    bool? lessonCompleted,
    int? studyTimeSeconds,
    int? lastPosition,
    bool? isSynced,
    Map<String, dynamic>? metadata,
  }) {
    return UserProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      contentId: contentId ?? this.contentId,
      studyMode: studyMode ?? this.studyMode,
      date: date ?? this.date,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctCount: correctCount ?? this.correctCount,
      lessonCompleted: lessonCompleted ?? this.lessonCompleted,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      lastPosition: lastPosition ?? this.lastPosition,
      isSynced: isSynced ?? this.isSynced,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Exact UUID-shape test for legacy lesson routes.
bool isLegacyProgressLessonId(String lessonId) {
  final parts = lessonId.split('-');
  const expectedLengths = <int>[8, 4, 4, 4, 12];
  if (parts.length != expectedLengths.length) return false;
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].length != expectedLengths[i] ||
        RegExp('[^a-fA-F0-9]').hasMatch(parts[i])) return false;
  }
  return true;
}

/// Adapt a server-authoritative daily projection without using local JSON.
UserProgress userProgressFromProjection(
  Map<String, dynamic> row, {
  required String userId,
  StudyMode studyMode = StudyMode.lesson,
}) {
  final lessonId = row['content_id'] as String;
  final kind = row['content_kind'] as String;
  final version = row['version_key'] as String;
  final day = row['reporting_date_utc'] as String;
  final seconds = row['active_seconds'] as int?;
  return UserProgress(
    id: 'remote_${userId}_${kind}_${lessonId}_${version}_${day}',
    userId: userId,
    lessonId: lessonId,
    studyMode: studyMode,
    date: DateTime.parse('${day}T00:00:00Z'),
    questionsAnswered: 0,
    correctCount: 0,
    lessonCompleted: row['completed'] == true,
    studyTimeSeconds: seconds ?? 0,
    isSynced: true,
    metadata: {
      'content_kind': kind,
      'version_key': version,
      'active_time_measured': seconds != null,
      'remote_projection': true,
    },
  );
}
