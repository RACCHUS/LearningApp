/// Target Crosswalk Occupation projection
/// Represents an authoritative career occupation linked to a learning target
/// via official educational CIP-to-SOC federal crosswalks and field bindings.
class TargetCrosswalkOccupation {
  final String occupationId;
  final String occupationCode; // e.g. '15-1252', '15-1211'
  final String occupationTitle; // e.g. 'Software Developers'
  final String occupationLevel; // 'major_group', 'detailed_occupation', 'onet_extension'
  final int? jobZone; // 1 to 5
  final String fieldId;
  final String fieldName;
  final String fieldRole; // 'primary', 'supporting'
  final String mappingKind; // 'official_qualitative', 'advisory_board', 'curated_extension'
  final String? classificationCode; // e.g. '11', '11.0701'
  final String? classificationTitle; // e.g. 'Computer Science'

  const TargetCrosswalkOccupation({
    required this.occupationId,
    required this.occupationCode,
    required this.occupationTitle,
    required this.occupationLevel,
    this.jobZone,
    required this.fieldId,
    required this.fieldName,
    required this.fieldRole,
    this.mappingKind = 'official_qualitative',
    this.classificationCode,
    this.classificationTitle,
  });

  bool get isPrimaryField => fieldRole == 'primary';
  bool get isOnetExtension => occupationLevel == 'onet_extension';

  /// Human-friendly Job Zone description based on official USDOL/O*NET definitions:
  /// Zone 1: Little or No Preparation Needed
  /// Zone 2: Some Preparation Needed (High school / certificate)
  /// Zone 3: Medium Preparation Needed (Vocational / Associate's)
  /// Zone 4: Considerable Preparation Needed (Bachelor's degree)
  /// Zone 5: Extensive Preparation Needed (Master's / Doctoral / Professional)
  String get jobZoneLabel {
    switch (jobZone) {
      case 1:
        return 'Job Zone 1: Little Preparation';
      case 2:
        return 'Job Zone 2: Some Preparation';
      case 3:
        return 'Job Zone 3: Medium Preparation';
      case 4:
        return 'Job Zone 4: Considerable Preparation (B.S./B.A.)';
      case 5:
        return 'Job Zone 5: Extensive Preparation (Graduate/Doctoral)';
      default:
        return 'Preparation Zone: Standard';
    }
  }

  factory TargetCrosswalkOccupation.fromJson(Map<String, dynamic> json) {
    return TargetCrosswalkOccupation(
      occupationId: (json['occupation_id'] ?? json['id']) as String,
      occupationCode: json['occupation_code'] as String? ?? json['code'] as String? ?? '',
      occupationTitle: json['occupation_title'] as String? ?? json['title'] as String? ?? '',
      occupationLevel: json['occupation_level'] as String? ?? json['level'] as String? ?? 'detailed_occupation',
      jobZone: (json['job_zone'] as num?)?.toInt(),
      fieldId: json['field_id'] as String? ?? '',
      fieldName: json['field_name'] as String? ?? '',
      fieldRole: json['field_role'] as String? ?? 'primary',
      mappingKind: json['mapping_kind'] as String? ?? 'official_qualitative',
      classificationCode: json['classification_code'] as String?,
      classificationTitle: json['classification_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'occupation_id': occupationId,
        'occupation_code': occupationCode,
        'occupation_title': occupationTitle,
        'occupation_level': occupationLevel,
        'job_zone': jobZone,
        'field_id': fieldId,
        'field_name': fieldName,
        'field_role': fieldRole,
        'mapping_kind': mappingKind,
        'classification_code': classificationCode,
        'classification_title': classificationTitle,
      };
}
