class Module {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final String? emoji;
  final int sortOrder;
  final bool isRequired;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Module({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.emoji,
    this.sortOrder = 0,
    this.isRequired = true,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
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
      'course_id': courseId,
      'title': title,
      'description': description,
      'emoji': emoji,
      'sort_order': sortOrder,
      'is_required': isRequired,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Module copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    String? emoji,
    int? sortOrder,
    bool? isRequired,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Module(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      sortOrder: sortOrder ?? this.sortOrder,
      isRequired: isRequired ?? this.isRequired,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
