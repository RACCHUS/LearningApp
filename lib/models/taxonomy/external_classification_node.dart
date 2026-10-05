/// External Classification Node model
/// Represents an authoritative external classification standard record (e.g. CIP 2020/2030, ISCED-F 2013).
class ExternalClassificationNode {
  final String id;
  final String sourceReleaseId;
  final String? parentId;
  final String system; // 'cip', 'isced_f'
  final String version; // '2020', '2030', '2013'
  final String code; // '11', '11.07', '11.0701'
  final String? sourceParentCode;
  final String levelCode; // 'series', 'group', 'program'
  final int levelDepth; // 1 to 10
  final String title;
  final String? definition;
  final List<String> crossReferences;
  final List<String> illustrativeExamples;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final DateTime? createdAt;

  const ExternalClassificationNode({
    required this.id,
    required this.sourceReleaseId,
    this.parentId,
    required this.system,
    required this.version,
    required this.code,
    this.sourceParentCode,
    required this.levelCode,
    this.levelDepth = 1,
    required this.title,
    this.definition,
    this.crossReferences = const [],
    this.illustrativeExamples = const [],
    this.metadata = const {},
    this.isActive = true,
    this.createdAt,
  });

  factory ExternalClassificationNode.fromJson(Map<String, dynamic> json) {
    return ExternalClassificationNode(
      id: json['id'] as String,
      sourceReleaseId: json['source_release_id'] as String,
      parentId: json['parent_id'] as String?,
      system: json['system'] as String,
      version: json['version'] as String,
      code: json['code'] as String,
      sourceParentCode: json['source_parent_code'] as String?,
      levelCode: json['level_code'] as String? ?? 'series',
      levelDepth: (json['level_depth'] as num?)?.toInt() ?? 1,
      title: json['title'] as String,
      definition: json['definition'] as String?,
      crossReferences: (json['cross_references'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      illustrativeExamples:
          (json['illustrative_examples'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source_release_id': sourceReleaseId,
        'parent_id': parentId,
        'system': system,
        'version': version,
        'code': code,
        'source_parent_code': sourceParentCode,
        'level_code': levelCode,
        'level_depth': levelDepth,
        'title': title,
        'definition': definition,
        'cross_references': crossReferences,
        'illustrative_examples': illustrativeExamples,
        'metadata': metadata,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
