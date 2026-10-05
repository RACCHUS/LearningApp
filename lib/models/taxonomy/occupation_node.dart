/// 5-Tier Hierarchical Labor Taxonomy Occupation Node model
/// Represents BLS Standard Occupational Classification (SOC) and O*NET extension nodes.
class OccupationNode {
  final String id;
  final String? parentId;
  final String code; // '15-0000', '15-1200', '15-1250', '15-1252', '15-1252.00'
  final String title;
  final String? description;
  final String level; // 'major_group', 'minor_group', 'broad_occupation', 'detailed_occupation', 'onet_extension'
  final String taxonomySystem; // 'bls_soc', 'onet_soc'
  final String taxonomyVersion; // 'soc_2018', '2019'
  final String? dataReleaseVersion; // e.g. 'onet_31_0'
  final int? jobZone; // 1 to 5
  final String? sourceReleaseId;
  final Map<String, dynamic> metadata;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OccupationNode({
    required this.id,
    this.parentId,
    required this.code,
    required this.title,
    this.description,
    required this.level,
    required this.taxonomySystem,
    required this.taxonomyVersion,
    this.dataReleaseVersion,
    this.jobZone,
    this.sourceReleaseId,
    this.metadata = const {},
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMajorGroup => level == 'major_group';
  bool get isMinorGroup => level == 'minor_group';
  bool get isBroadOccupation => level == 'broad_occupation';
  bool get isDetailedOccupation => level == 'detailed_occupation';
  bool get isOnetExtension => level == 'onet_extension';

  factory OccupationNode.fromJson(Map<String, dynamic> json) {
    return OccupationNode(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      level: json['level'] as String,
      taxonomySystem: json['taxonomy_system'] as String,
      taxonomyVersion: json['taxonomy_version'] as String,
      dataReleaseVersion: json['data_release_version'] as String?,
      jobZone: (json['job_zone'] as num?)?.toInt(),
      sourceReleaseId: json['source_release_id'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_id': parentId,
        'code': code,
        'title': title,
        'description': description,
        'level': level,
        'taxonomy_system': taxonomySystem,
        'taxonomy_version': taxonomyVersion,
        'data_release_version': dataReleaseVersion,
        'job_zone': jobZone,
        'source_release_id': sourceReleaseId,
        'metadata': metadata,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}
