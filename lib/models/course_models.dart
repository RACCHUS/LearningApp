/// Course entity for organizing lesson collections
class Course {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final String author;
  final int estimatedHours;
  final List<String> tags;
  final List<String> skillsAcquired;
  final bool isPublic;
  final bool isFeatured;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final CourseStatus status;
  final int enrollmentCount;
  final double rating;
  final int reviewCount;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.author,
    required this.estimatedHours,
    required this.tags,
    required this.skillsAcquired,
    required this.isPublic,
    required this.isFeatured,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    required this.status,
    this.enrollmentCount = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? difficulty,
    String? author,
    int? estimatedHours,
    List<String>? tags,
    List<String>? skillsAcquired,
    bool? isPublic,
    bool? isFeatured,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    CourseStatus? status,
    int? enrollmentCount,
    double? rating,
    int? reviewCount,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      author: author ?? this.author,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      tags: tags ?? this.tags,
      skillsAcquired: skillsAcquired ?? this.skillsAcquired,
      isPublic: isPublic ?? this.isPublic,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      enrollmentCount: enrollmentCount ?? this.enrollmentCount,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'author': author,
      'estimatedHours': estimatedHours,
      'tags': tags,
      'skillsAcquired': skillsAcquired,
      'isPublic': isPublic,
      'isFeatured': isFeatured,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'status': status.name,
      'enrollmentCount': enrollmentCount,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      difficulty: json['difficulty'],
      author: json['author'],
      estimatedHours: json['estimatedHours'],
      tags: List<String>.from(json['tags']),
      skillsAcquired: List<String>.from(json['skillsAcquired']),
      isPublic: json['isPublic'],
      isFeatured: json['isFeatured'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      imageUrl: json['imageUrl'],
      status: CourseStatus.values.firstWhere((e) => e.name == json['status']),
      enrollmentCount: json['enrollmentCount'] ?? 0,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
    );
  }
}

/// Lesson series for structured progression within courses
class LessonSeries {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int seriesOrder;
  final List<String> lessonIds;
  final List<String> prerequisites;
  final bool isOptional;
  final SeriesType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int estimatedMinutes;
  final String? imageUrl;

  const LessonSeries({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.seriesOrder,
    required this.lessonIds,
    required this.prerequisites,
    required this.isOptional,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.estimatedMinutes,
    this.imageUrl,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonSeries && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  LessonSeries copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? seriesOrder,
    List<String>? lessonIds,
    List<String>? prerequisites,
    bool? isOptional,
    SeriesType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? estimatedMinutes,
    String? imageUrl,
  }) {
    return LessonSeries(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      seriesOrder: seriesOrder ?? this.seriesOrder,
      lessonIds: lessonIds ?? this.lessonIds,
      prerequisites: prerequisites ?? this.prerequisites,
      isOptional: isOptional ?? this.isOptional,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'seriesOrder': seriesOrder,
      'lessonIds': lessonIds,
      'prerequisites': prerequisites,
      'isOptional': isOptional,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'estimatedMinutes': estimatedMinutes,
      'imageUrl': imageUrl,
    };
  }

  factory LessonSeries.fromJson(Map<String, dynamic> json) {
    return LessonSeries(
      id: json['id'],
      courseId: json['courseId'],
      title: json['title'],
      description: json['description'],
      seriesOrder: json['seriesOrder'],
      lessonIds: List<String>.from(json['lessonIds']),
      prerequisites: List<String>.from(json['prerequisites']),
      isOptional: json['isOptional'],
      type: SeriesType.values.firstWhere((e) => e.name == json['type']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      estimatedMinutes: json['estimatedMinutes'],
      imageUrl: json['imageUrl'],
    );
  }
}

/// Course lesson association with ordering and metadata
class CourseLessonAssociation {
  final String id;
  final String courseId;
  final String lessonId;
  final String? seriesId;
  final int orderInCourse;
  final int? orderInSeries;
  final bool isRequired;
  final List<String> prerequisites;
  final DateTime addedAt;
  final DateTime? completionDeadline;
  final Map<String, dynamic>? metadata;

  const CourseLessonAssociation({
    required this.id,
    required this.courseId,
    required this.lessonId,
    this.seriesId,
    required this.orderInCourse,
    this.orderInSeries,
    required this.isRequired,
    required this.prerequisites,
    required this.addedAt,
    this.completionDeadline,
    this.metadata,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseLessonAssociation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  CourseLessonAssociation copyWith({
    String? id,
    String? courseId,
    String? lessonId,
    String? seriesId,
    int? orderInCourse,
    int? orderInSeries,
    bool? isRequired,
    List<String>? prerequisites,
    DateTime? addedAt,
    DateTime? completionDeadline,
    Map<String, dynamic>? metadata,
  }) {
    return CourseLessonAssociation(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      seriesId: seriesId ?? this.seriesId,
      orderInCourse: orderInCourse ?? this.orderInCourse,
      orderInSeries: orderInSeries ?? this.orderInSeries,
      isRequired: isRequired ?? this.isRequired,
      prerequisites: prerequisites ?? this.prerequisites,
      addedAt: addedAt ?? this.addedAt,
      completionDeadline: completionDeadline ?? this.completionDeadline,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'lessonId': lessonId,
      'seriesId': seriesId,
      'orderInCourse': orderInCourse,
      'orderInSeries': orderInSeries,
      'isRequired': isRequired,
      'prerequisites': prerequisites,
      'addedAt': addedAt.toIso8601String(),
      'completionDeadline': completionDeadline?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory CourseLessonAssociation.fromJson(Map<String, dynamic> json) {
    return CourseLessonAssociation(
      id: json['id'],
      courseId: json['courseId'],
      lessonId: json['lessonId'],
      seriesId: json['seriesId'],
      orderInCourse: json['orderInCourse'],
      orderInSeries: json['orderInSeries'],
      isRequired: json['isRequired'],
      prerequisites: List<String>.from(json['prerequisites']),
      addedAt: DateTime.parse(json['addedAt']),
      completionDeadline: json['completionDeadline'] != null
          ? DateTime.parse(json['completionDeadline'])
          : null,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }
}

/// Course progress tracking
class CourseProgress {
  final String id;
  final String courseId;
  final String userId;
  final Map<String, LessonProgress> lessonProgress;
  final double overallProgress;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime lastAccessedAt;
  final int totalTimeSpentMinutes;
  final CourseProgressStatus status;
  final Map<String, dynamic>? metadata;

  const CourseProgress({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.lessonProgress,
    required this.overallProgress,
    required this.startedAt,
    this.completedAt,
    required this.lastAccessedAt,
    required this.totalTimeSpentMinutes,
    required this.status,
    this.metadata,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourseProgress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'userId': userId,
      'lessonProgress': lessonProgress.map((key, value) => MapEntry(key, value.toJson())),
      'overallProgress': overallProgress,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'totalTimeSpentMinutes': totalTimeSpentMinutes,
      'status': status.name,
      'metadata': metadata,
    };
  }

  factory CourseProgress.fromJson(Map<String, dynamic> json) {
    return CourseProgress(
      id: json['id'],
      courseId: json['courseId'],
      userId: json['userId'],
      lessonProgress: (json['lessonProgress'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, LessonProgress.fromJson(value)),
      ),
      overallProgress: (json['overallProgress'] ?? 0.0).toDouble(),
      startedAt: DateTime.parse(json['startedAt']),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      lastAccessedAt: DateTime.parse(json['lastAccessedAt']),
      totalTimeSpentMinutes: json['totalTimeSpentMinutes'] ?? 0,
      status: CourseProgressStatus.values.firstWhere((e) => e.name == json['status']),
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }
}

/// Individual lesson progress within a course
class LessonProgress {
  final String lessonId;
  final double progress;
  final LessonProgressStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime lastAccessedAt;
  final int timeSpentMinutes;
  final Map<String, dynamic> contentProgress;
  final double? score;
  final int attempts;

  const LessonProgress({
    required this.lessonId,
    required this.progress,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.lastAccessedAt,
    required this.timeSpentMinutes,
    required this.contentProgress,
    this.score,
    required this.attempts,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LessonProgress && other.lessonId == lessonId;
  }

  @override
  int get hashCode => lessonId.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'lessonId': lessonId,
      'progress': progress,
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'timeSpentMinutes': timeSpentMinutes,
      'contentProgress': contentProgress,
      'score': score,
      'attempts': attempts,
    };
  }

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      lessonId: json['lessonId'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      status: LessonProgressStatus.values.firstWhere((e) => e.name == json['status']),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      lastAccessedAt: DateTime.parse(json['lastAccessedAt']),
      timeSpentMinutes: json['timeSpentMinutes'] ?? 0,
      contentProgress: Map<String, dynamic>.from(json['contentProgress']),
      score: json['score']?.toDouble(),
      attempts: json['attempts'] ?? 0,
    );
  }
}

// Enums
enum CourseStatus {
  draft,
  published,
  archived,
  underReview,
}

enum SeriesType {
  sequential,
  modular,
  assessment,
  practice,
  bonus,
}

enum CourseProgressStatus {
  notStarted,
  inProgress,
  completed,
  paused,
  dropped,
}

enum LessonProgressStatus {
  notStarted,
  inProgress,
  completed,
  skipped,
  failed,
}
