import 'package:hive/hive.dart';
import 'package:learning_pwa/core/hive_type_ids.dart';

/// Where a [LearningContext] is rooted in the content hierarchy.
enum ContextRootType {
  target,
  path,
  course,
  module,
  lesson,
  concept,
  studySet,
}

/// How prerequisites and secondary concepts are included in scope.
enum ScopeMode {
  coreOnly,
  coreAndPrerequisites,
  custom,
}

/// Activity kinds that can be meaningfully resumed.
///
/// Review sessions are excluded (spec D5): a due-set is a query over items due
/// *right now*, and answering items mutates that set, so a persisted batch
/// would replay items that have left the due window.
enum ResumableKind { lesson, studySet }

/// A user-level pointer to something they are pursuing, at whatever level of
/// the hierarchy that thing happens to live.
///
/// This is what makes the hierarchy optional: the switcher and the Learn screen
/// never care whether the root is a career path, an exam target, or a bare study set.
class LearningContext {
  final String id;
  final String userId;
  final String label;
  final ContextRootType rootType;
  final String rootId;
  final String? emoji;
  final DateTime lastActiveAt;
  final bool isArchived;

  /// `>= 0` pins the context; `-1` leaves it ordered by [lastActiveAt].
  final int sortOrder;

  /// For `target` contexts: the specific version of the target curriculum.
  final String? targetVersionId;

  /// Focused sub-area within the context (e.g. 'exam_domain', 'module').
  final String? activeFocusType;
  final String? activeFocusId;

  /// How prerequisites are included in the scope.
  final ScopeMode scopeMode;

  /// Target/context specific configuration (e.g. elective exclusions).
  final Map<String, dynamic> scopeConfig;

  const LearningContext({
    required this.id,
    required this.userId,
    required this.label,
    required this.rootType,
    required this.rootId,
    required this.lastActiveAt,
    this.emoji,
    this.isArchived = false,
    this.sortOrder = -1,
    this.targetVersionId,
    this.activeFocusType,
    this.activeFocusId,
    this.scopeMode = ScopeMode.coreAndPrerequisites,
    this.scopeConfig = const {},
  });

  bool get isPinned => sortOrder >= 0;

  /// Stable identity for backfill de-duplication (spec §11, P0 risk register).
  String get dedupeKey => '$userId::${rootType.name}::$rootId';

  LearningContext copyWith({
    String? id,
    String? userId,
    String? label,
    ContextRootType? rootType,
    String? rootId,
    String? emoji,
    bool clearEmoji = false,
    DateTime? lastActiveAt,
    bool? isArchived,
    int? sortOrder,
    String? targetVersionId,
    bool clearTargetVersionId = false,
    String? activeFocusType,
    String? activeFocusId,
    bool clearActiveFocus = false,
    ScopeMode? scopeMode,
    Map<String, dynamic>? scopeConfig,
  }) {
    return LearningContext(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      rootType: rootType ?? this.rootType,
      rootId: rootId ?? this.rootId,
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      targetVersionId: clearTargetVersionId
          ? null
          : (targetVersionId ?? this.targetVersionId),
      activeFocusType:
          clearActiveFocus ? null : (activeFocusType ?? this.activeFocusType),
      activeFocusId:
          clearActiveFocus ? null : (activeFocusId ?? this.activeFocusId),
      scopeMode: scopeMode ?? this.scopeMode,
      scopeConfig: scopeConfig ?? this.scopeConfig,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'label': label,
        'root_type': rootType.name,
        'root_id': rootId,
        'emoji': emoji,
        'last_active_at': lastActiveAt.toIso8601String(),
        'is_archived': isArchived,
        'sort_order': sortOrder,
        if (targetVersionId != null) 'target_version_id': targetVersionId,
        if (activeFocusType != null) 'active_focus_type': activeFocusType,
        if (activeFocusId != null) 'active_focus_id': activeFocusId,
        'scope_mode': scopeMode.name,
        'scope_config': scopeConfig,
      };

  factory LearningContext.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final rootId = json['root_id'] as String?;
    if (id == null || id.isEmpty) {
      throw const FormatException('LearningContext.id is required');
    }
    if (rootId == null || rootId.isEmpty) {
      throw const FormatException('LearningContext.root_id is required');
    }
    return LearningContext(
      id: id,
      userId: json['user_id'] as String? ?? '',
      label: json['label'] as String? ?? 'Untitled',
      rootType: _rootTypeFromName(json['root_type'] as String?),
      rootId: rootId,
      emoji: json['emoji'] as String?,
      lastActiveAt: DateTime.tryParse(json['last_active_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isArchived: json['is_archived'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? -1,
      targetVersionId: json['target_version_id'] as String?,
      activeFocusType: json['active_focus_type'] as String?,
      activeFocusId: json['active_focus_id'] as String?,
      scopeMode: _scopeModeFromName(json['scope_mode'] as String?),
      scopeConfig: (json['scope_config'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  static ContextRootType _rootTypeFromName(String? name) {
    return ContextRootType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => ContextRootType.course,
    );
  }

  static ScopeMode _scopeModeFromName(String? name) {
    return ScopeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ScopeMode.coreAndPrerequisites,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LearningContext && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Where the learner stopped inside a context. One per context.
///
/// [courseId] and [moduleId] are breadcrumb-only — they exist solely to render
/// the orientation line. Nothing in the engine may branch on their presence;
/// that coupling is what made a bare study set unrepresentable.
class ResumePointer {
  final String contextId;
  final ResumableKind kind;
  final String activityId;
  final int? itemIndex;
  final String? courseId;
  final String? moduleId;
  final DateTime updatedAt;

  const ResumePointer({
    required this.contextId,
    required this.kind,
    required this.activityId,
    required this.updatedAt,
    this.itemIndex,
    this.courseId,
    this.moduleId,
  });

  ResumePointer copyWith({
    ResumableKind? kind,
    String? activityId,
    int? itemIndex,
    String? courseId,
    String? moduleId,
    DateTime? updatedAt,
  }) {
    return ResumePointer(
      contextId: contextId,
      kind: kind ?? this.kind,
      activityId: activityId ?? this.activityId,
      itemIndex: itemIndex ?? this.itemIndex,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'context_id': contextId,
        'kind': kind.name,
        'activity_id': activityId,
        'item_index': itemIndex,
        'course_id': courseId,
        'module_id': moduleId,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ResumePointer.fromJson(Map<String, dynamic> json) {
    final contextId = json['context_id'] as String?;
    final activityId = json['activity_id'] as String?;
    if (contextId == null || contextId.isEmpty) {
      throw const FormatException('ResumePointer.context_id is required');
    }
    if (activityId == null || activityId.isEmpty) {
      throw const FormatException('ResumePointer.activity_id is required');
    }
    return ResumePointer(
      contextId: contextId,
      kind: ResumableKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => ResumableKind.lesson,
      ),
      activityId: activityId,
      itemIndex: (json['item_index'] as num?)?.toInt(),
      courseId: json['course_id'] as String?,
      moduleId: json['module_id'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// ---------------------------------------------------------------------------
// Hive adapters (hand-written; ids come from the central registry).
// ---------------------------------------------------------------------------

class LearningContextAdapter extends TypeAdapter<LearningContext> {
  @override
  final int typeId = HiveTypeIds.learningContext;

  @override
  LearningContext read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final rawRoot = fields[3];
    ContextRootType rootType;
    if (rawRoot is String) {
      rootType = ContextRootType.values.firstWhere(
        (e) => e.name == rawRoot,
        orElse: () => ContextRootType.course,
      );
    } else if (rawRoot is int) {
      // Deterministic legacy ordinal mapping from v1:
      // 0: path, 1: course, 2: module, 3: lesson, 4: studySet
      switch (rawRoot) {
        case 0:
          rootType = ContextRootType.path;
          break;
        case 1:
          rootType = ContextRootType.course;
          break;
        case 2:
          rootType = ContextRootType.module;
          break;
        case 3:
          rootType = ContextRootType.lesson;
          break;
        case 4:
          rootType = ContextRootType.studySet;
          break;
        default:
          rootType = ContextRootType.course;
      }
    } else {
      rootType = ContextRootType.course;
    }

    final rawScopeMode = fields[12];
    ScopeMode scopeMode = ScopeMode.coreAndPrerequisites;
    if (rawScopeMode is String) {
      scopeMode = ScopeMode.values.firstWhere(
        (m) => m.name == rawScopeMode,
        orElse: () => ScopeMode.coreAndPrerequisites,
      );
    }

    return LearningContext(
      id: fields[0] as String,
      userId: fields[1] as String? ?? '',
      label: fields[2] as String? ?? 'Untitled',
      rootType: rootType,
      rootId: fields[4] as String? ?? '',
      emoji: fields[5] as String?,
      lastActiveAt: fields[6] as DateTime? ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isArchived: fields[7] as bool? ?? false,
      sortOrder: (fields[8] as num?)?.toInt() ?? -1,
      targetVersionId: fields[9] as String?,
      activeFocusType: fields[10] as String?,
      activeFocusId: fields[11] as String?,
      scopeMode: scopeMode,
      scopeConfig: (fields[13] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @override
  void write(BinaryWriter writer, LearningContext obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.rootType.name) // Stable String serialization in v2
      ..writeByte(4)
      ..write(obj.rootId)
      ..writeByte(5)
      ..write(obj.emoji)
      ..writeByte(6)
      ..write(obj.lastActiveAt)
      ..writeByte(7)
      ..write(obj.isArchived)
      ..writeByte(8)
      ..write(obj.sortOrder)
      ..writeByte(9)
      ..write(obj.targetVersionId)
      ..writeByte(10)
      ..write(obj.activeFocusType)
      ..writeByte(11)
      ..write(obj.activeFocusId)
      ..writeByte(12)
      ..write(obj.scopeMode.name)
      ..writeByte(13)
      ..write(obj.scopeConfig);
  }
}

class ResumePointerAdapter extends TypeAdapter<ResumePointer> {
  @override
  final int typeId = HiveTypeIds.resumePointer;

  @override
  ResumePointer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final kindIndex = (fields[1] as num?)?.toInt() ?? 0;
    return ResumePointer(
      contextId: fields[0] as String,
      kind: kindIndex >= 0 && kindIndex < ResumableKind.values.length
          ? ResumableKind.values[kindIndex]
          : ResumableKind.lesson,
      activityId: fields[2] as String? ?? '',
      itemIndex: (fields[3] as num?)?.toInt(),
      courseId: fields[4] as String?,
      moduleId: fields[5] as String?,
      updatedAt:
          fields[6] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  void write(BinaryWriter writer, ResumePointer obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.contextId)
      ..writeByte(1)
      ..write(obj.kind.index)
      ..writeByte(2)
      ..write(obj.activityId)
      ..writeByte(3)
      ..write(obj.itemIndex)
      ..writeByte(4)
      ..write(obj.courseId)
      ..writeByte(5)
      ..write(obj.moduleId)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }
}
