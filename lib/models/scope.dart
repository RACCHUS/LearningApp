import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';

enum ScopeRole {
  core,
  supporting,
  related;

  static ScopeRole fromString(String value) {
    return ScopeRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ScopeRole.core,
    );
  }
}

/// Review batches are queries, not durable scheduled activities.
enum ScopedActivityKind {
  lesson,
  studySet;

  static ScopedActivityKind fromString(String value) {
    return ScopedActivityKind.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ScopedActivityKind.lesson,
    );
  }
}

class ScopedLearningActivity {
  final String activityId;
  final ScopedActivityKind kind;
  final String? curriculumNodeId;
  final int curriculumOrder;
  final int activityOrder;
  final ScopeRole role;
  final String title;
  final Duration estimatedDuration;
  final String? courseId;
  final String? courseTitle;
  final String? moduleId;
  final String? moduleTitle;

  const ScopedLearningActivity({
    required this.activityId,
    required this.kind,
    this.curriculumNodeId,
    this.curriculumOrder = 0,
    this.activityOrder = 0,
    this.role = ScopeRole.core,
    required this.title,
    this.estimatedDuration = const Duration(minutes: 10),
    this.courseId,
    this.courseTitle,
    this.moduleId,
    this.moduleTitle,
  });

  factory ScopedLearningActivity.fromJson(Map<String, dynamic> json) {
    return ScopedLearningActivity(
      activityId: json['activity_id'] as String,
      kind: ScopedActivityKind.fromString(json['kind'] as String? ?? 'lesson'),
      curriculumNodeId: json['curriculum_node_id'] as String?,
      curriculumOrder: (json['curriculum_order'] as num?)?.toInt() ?? 0,
      activityOrder: (json['activity_order'] as num?)?.toInt() ?? 0,
      role: ScopeRole.fromString(json['role'] as String? ?? 'core'),
      title: json['title'] as String? ?? '',
      estimatedDuration: Duration(
        minutes: (json['estimated_minutes'] as num?)?.toInt() ?? 10,
      ),
      courseId: json['course_id'] as String?,
      courseTitle: json['course_title'] as String?,
      moduleId: json['module_id'] as String?,
      moduleTitle: json['module_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'activity_id': activityId,
        'kind': kind.name,
        'curriculum_node_id': curriculumNodeId,
        'curriculum_order': curriculumOrder,
        'activity_order': activityOrder,
        'role': role.name,
        'title': title,
        'estimated_minutes': estimatedDuration.inMinutes,
        'course_id': courseId,
        'course_title': courseTitle,
        'module_id': moduleId,
        'module_title': moduleTitle,
      };
}

class ResolvedScope {
  final String contextId;
  final Set<String> coreConceptIds;
  final Set<String> supportingConceptIds;
  final Set<String> relatedConceptIds;
  final Set<String> curriculumNodeIds;

  /// Deterministically ordered teaching candidates for NextActionEngine
  final List<ScopedLearningActivity> orderedActivities;

  final Set<String> questionIds;
  final Set<String> termIds;
  final Set<String> flashcardIds;
  final DateTime resolvedAt;

  const ResolvedScope({
    required this.contextId,
    this.coreConceptIds = const {},
    this.supportingConceptIds = const {},
    this.relatedConceptIds = const {},
    this.curriculumNodeIds = const {},
    this.orderedActivities = const [],
    this.questionIds = const {},
    this.termIds = const {},
    this.flashcardIds = const {},
    required this.resolvedAt,
  });

  /// All concepts in the active learning boundary (core + supporting)
  Set<String> get activeConceptIds => {...coreConceptIds, ...supportingConceptIds};

  bool containsConcept(String conceptId) =>
      coreConceptIds.contains(conceptId) || supportingConceptIds.contains(conceptId);

  bool containsActivity(String activityId) =>
      orderedActivities.any((a) => a.activityId == activityId);

  factory ResolvedScope.fromJson(Map<String, dynamic> json) {
    return ResolvedScope(
      contextId: json['context_id'] as String,
      coreConceptIds: (json['core_concept_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      supportingConceptIds: (json['supporting_concept_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      relatedConceptIds: (json['related_concept_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      curriculumNodeIds: (json['curriculum_node_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      orderedActivities: (json['ordered_activities'] as List?)
              ?.map((e) => ScopedLearningActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      questionIds: (json['question_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      termIds: (json['term_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      flashcardIds: (json['flashcard_ids'] as List?)?.map((e) => e.toString()).toSet() ?? const {},
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'context_id': contextId,
        'core_concept_ids': coreConceptIds.toList(),
        'supporting_concept_ids': supportingConceptIds.toList(),
        'related_concept_ids': relatedConceptIds.toList(),
        'curriculum_node_ids': curriculumNodeIds.toList(),
        'ordered_activities': orderedActivities.map((a) => a.toJson()).toList(),
        'question_ids': questionIds.toList(),
        'term_ids': termIds.toList(),
        'flashcard_ids': flashcardIds.toList(),
        'resolved_at': resolvedAt.toIso8601String(),
      };
}

class SnapshotNode {
  final String id;
  final String? parentId;
  final String title;
  final String? code;
  final String nodeType;
  final int sortOrder;

  const SnapshotNode({
    required this.id,
    this.parentId,
    required this.title,
    this.code,
    required this.nodeType,
    this.sortOrder = 0,
  });

  factory SnapshotNode.fromJson(Map<String, dynamic> json) => SnapshotNode(
        id: json['id'] as String,
        parentId: json['parent_id'] as String?,
        title: json['title'] as String? ?? '',
        code: json['code'] as String?,
        nodeType: json['node_type'] as String? ?? 'domain',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_id': parentId,
        'title': title,
        'code': code,
        'node_type': nodeType,
        'sort_order': sortOrder,
      };
}

class ContextCurriculumSnapshot {
  final String contextId;
  final String targetVersionId;
  final List<SnapshotNode> nodes;
  final String? activeFocusId;
  final DateTime snapshotAt;

  const ContextCurriculumSnapshot({
    required this.contextId,
    required this.targetVersionId,
    required this.nodes,
    this.activeFocusId,
    required this.snapshotAt,
  });

  factory ContextCurriculumSnapshot.fromJson(Map<String, dynamic> json) =>
      ContextCurriculumSnapshot(
        contextId: json['context_id'] as String,
        targetVersionId: json['target_version_id'] as String,
        nodes: (json['nodes'] as List?)
                ?.map((e) => SnapshotNode.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        activeFocusId: json['active_focus_id'] as String?,
        snapshotAt: json['snapshot_at'] != null
            ? DateTime.parse(json['snapshot_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'context_id': contextId,
        'target_version_id': targetVersionId,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'active_focus_id': activeFocusId,
        'snapshot_at': snapshotAt.toIso8601String(),
      };
}

class ResolvedScopeAdapter extends TypeAdapter<ResolvedScope> {
  @override
  final int typeId = HiveTypeIds.resolvedScopeCache;

  @override
  ResolvedScope read(BinaryReader reader) {
    final jsonStr = reader.readString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ResolvedScope.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, ResolvedScope obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

class ContextCurriculumSnapshotAdapter
    extends TypeAdapter<ContextCurriculumSnapshot> {
  @override
  final int typeId = HiveTypeIds.contextCurriculumSnapshot;

  @override
  ContextCurriculumSnapshot read(BinaryReader reader) {
    final jsonStr = reader.readString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return ContextCurriculumSnapshot.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, ContextCurriculumSnapshot obj) {
    writer.writeString(jsonEncode(obj.toJson()));
  }
}

