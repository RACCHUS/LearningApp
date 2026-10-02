/// A learner-owned lesson attached to one version-specific curriculum node.
/// This never represents an official required curriculum binding.
class UserCurriculumResource {
  final String id;
  final String userId;
  final String curriculumNodeId;
  final String lessonId;
  final String? lessonTitle;
  final String relationship;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserCurriculumResource({
    required this.id,
    required this.userId,
    required this.curriculumNodeId,
    required this.lessonId,
    required this.lessonTitle,
    required this.relationship,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserCurriculumResource.fromJson(Map<String, dynamic> json) {
    final lesson = json['lessons'];
    return UserCurriculumResource(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      curriculumNodeId: json['curriculum_node_id'] as String,
      lessonId: json['lesson_id'] as String,
      lessonTitle: lesson is Map ? lesson['title'] as String? : null,
      relationship: json['relationship'] as String? ?? 'personal_study',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
