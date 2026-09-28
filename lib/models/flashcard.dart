class Flashcard {
  final String id;
  final String? lessonId;
  final String front;
  final String back;
  final String? explanation;
  final String? userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Flashcard({
    required this.id,
    this.lessonId,
    required this.front,
    required this.back,
    this.explanation,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isStandalone => lessonId == null;

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String?,
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      explanation: json['explanation'] as String?,
      userId: json['user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'front': front,
      'back': back,
      'explanation': explanation,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Flashcard copyWith({
    String? id,
    String? lessonId,
    String? front,
    String? back,
    String? explanation,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Flashcard(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      front: front ?? this.front,
      back: back ?? this.back,
      explanation: explanation ?? this.explanation,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudySetFlashcard {
  final String studySetId;
  final String flashcardId;
  final int sortOrder;

  const StudySetFlashcard({
    required this.studySetId,
    required this.flashcardId,
    this.sortOrder = 0,
  });

  factory StudySetFlashcard.fromJson(Map<String, dynamic> json) {
    return StudySetFlashcard(
      studySetId: json['study_set_id'] as String,
      flashcardId: json['flashcard_id'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'study_set_id': studySetId,
        'flashcard_id': flashcardId,
        'sort_order': sortOrder,
      };
}
