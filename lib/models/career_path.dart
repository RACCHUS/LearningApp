import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/skill.dart';

/// Career Path - top-level hierarchy grouping courses into career roadmaps
class CareerPath {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? imageUrl;
  final int estimatedMonths;
  final bool isPublic;
  final bool isFeatured;
  final bool isOfficial;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated from joins
  final List<CareerPathCourse>? courses;
  final List<CareerPathSkill>? skills;

  const CareerPath({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.imageUrl,
    this.estimatedMonths = 6,
    this.isPublic = true,
    this.isFeatured = false,
    this.isOfficial = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.courses,
    this.skills,
  });

  factory CareerPath.fromJson(Map<String, dynamic> json) {
    return CareerPath(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      estimatedMonths: json['estimated_months'] as int? ?? 6,
      isPublic: json['is_public'] as bool? ?? true,
      isFeatured: json['is_featured'] as bool? ?? false,
      isOfficial: json['is_official'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      courses: json['career_path_courses'] != null
          ? (json['career_path_courses'] as List)
              .map((c) => CareerPathCourse.fromJson(c))
              .toList()
          : null,
      skills: json['career_path_skills'] != null
          ? (json['career_path_skills'] as List)
              .map((s) => CareerPathSkill.fromJson(s))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'description': description,
        'image_url': imageUrl,
        'estimated_months': estimatedMonths,
        'is_public': isPublic,
        'is_featured': isFeatured,
        'is_official': isOfficial,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  CareerPath copyWith({
    String? id,
    String? title,
    String? slug,
    String? description,
    String? imageUrl,
    int? estimatedMonths,
    bool? isPublic,
    bool? isFeatured,
    bool? isOfficial,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CareerPathCourse>? courses,
    List<CareerPathSkill>? skills,
  }) {
    return CareerPath(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      estimatedMonths: estimatedMonths ?? this.estimatedMonths,
      isPublic: isPublic ?? this.isPublic,
      isFeatured: isFeatured ?? this.isFeatured,
      isOfficial: isOfficial ?? this.isOfficial,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courses: courses ?? this.courses,
      skills: skills ?? this.skills,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CareerPath && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Junction table: Career Path → Course (with ordering)
class CareerPathCourse {
  final String id;
  final String careerPathId;
  final String courseId;
  final int orderIndex;
  final bool isRequired;
  final String? sectionTitle;

  // Populated from joins
  final Course? course;

  const CareerPathCourse({
    required this.id,
    required this.careerPathId,
    required this.courseId,
    this.orderIndex = 0,
    this.isRequired = true,
    this.sectionTitle,
    this.course,
  });

  factory CareerPathCourse.fromJson(Map<String, dynamic> json) {
    return CareerPathCourse(
      id: json['id'] as String,
      careerPathId: json['career_path_id'] as String,
      courseId: json['course_id'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
      sectionTitle: json['section_title'] as String?,
      course:
          json['courses'] != null ? Course.fromJson(json['courses']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'career_path_id': careerPathId,
        'course_id': courseId,
        'order_index': orderIndex,
        'is_required': isRequired,
        'section_title': sectionTitle,
      };
}

/// Junction table: Career Path → Skill (with importance level)
class CareerPathSkill {
  final String careerPathId;
  final String skillId;
  final SkillImportance importance;

  // Populated from joins
  final Skill? skill;

  const CareerPathSkill({
    required this.careerPathId,
    required this.skillId,
    this.importance = SkillImportance.core,
    this.skill,
  });

  factory CareerPathSkill.fromJson(Map<String, dynamic> json) {
    return CareerPathSkill(
      careerPathId: json['career_path_id'] as String,
      skillId: json['skill_id'] as String,
      importance: SkillImportance.fromString(json['importance'] as String?),
      skill: json['skills'] != null ? Skill.fromJson(json['skills']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'career_path_id': careerPathId,
        'skill_id': skillId,
        'importance': importance.value,
      };
}

/// User's enrollment in a career path
class UserCareerPath {
  final String id;
  final String userId;
  final String careerPathId;
  final CareerPathStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated from joins
  final CareerPath? careerPath;

  const UserCareerPath({
    required this.id,
    required this.userId,
    required this.careerPathId,
    this.status = CareerPathStatus.active,
    required this.startedAt,
    this.completedAt,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.careerPath,
  });

  factory UserCareerPath.fromJson(Map<String, dynamic> json) {
    return UserCareerPath(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      careerPathId: json['career_path_id'] as String,
      status: CareerPathStatus.fromString(json['status'] as String?),
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      careerPath: json['career_paths'] != null
          ? CareerPath.fromJson(json['career_paths'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'career_path_id': careerPathId,
        'status': status.value,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  UserCareerPath copyWith({
    String? id,
    String? userId,
    String? careerPathId,
    CareerPathStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    CareerPath? careerPath,
  }) {
    return UserCareerPath(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      careerPathId: careerPathId ?? this.careerPathId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      careerPath: careerPath ?? this.careerPath,
    );
  }
}

/// Status of user's career path enrollment
enum CareerPathStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  abandoned('abandoned');

  final String value;
  const CareerPathStatus(this.value);

  static CareerPathStatus fromString(String? value) {
    return CareerPathStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CareerPathStatus.active,
    );
  }
}

/// Importance level for skills in a career path
enum SkillImportance {
  core('core'),
  recommended('recommended'),
  optional('optional');

  final String value;
  const SkillImportance(this.value);

  static SkillImportance fromString(String? value) {
    return SkillImportance.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SkillImportance.core,
    );
  }

  String get displayName {
    switch (this) {
      case SkillImportance.core:
        return 'Core Skill';
      case SkillImportance.recommended:
        return 'Recommended';
      case SkillImportance.optional:
        return 'Optional';
    }
  }
}
