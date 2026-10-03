enum AssessmentStimulusType {
  clinicalCase,
  architectureDiagram,
  codeSnippet,
  dataTable,
  scenario,
  passage;

  static AssessmentStimulusType fromString(String value) {
    switch (value) {
      case 'clinical_case':
      case 'clinicalCase':
        return AssessmentStimulusType.clinicalCase;
      case 'architecture_diagram':
      case 'architectureDiagram':
        return AssessmentStimulusType.architectureDiagram;
      case 'code_snippet':
      case 'codeSnippet':
        return AssessmentStimulusType.codeSnippet;
      case 'data_table':
      case 'dataTable':
        return AssessmentStimulusType.dataTable;
      case 'scenario':
        return AssessmentStimulusType.scenario;
      case 'passage':
        return AssessmentStimulusType.passage;
      default:
        return AssessmentStimulusType.scenario;
    }
  }

  String toDbString() {
    switch (this) {
      case AssessmentStimulusType.clinicalCase:
        return 'clinical_case';
      case AssessmentStimulusType.architectureDiagram:
        return 'architecture_diagram';
      case AssessmentStimulusType.codeSnippet:
        return 'code_snippet';
      case AssessmentStimulusType.dataTable:
        return 'data_table';
      case AssessmentStimulusType.scenario:
        return 'scenario';
      case AssessmentStimulusType.passage:
        return 'passage';
    }
  }
}

class AssessmentStimulus {
  final String id;
  final AssessmentStimulusType stimulusType;
  final String title;
  final String? body;
  final Map<String, dynamic> structuredData;
  final List<dynamic> assetRefs;
  final Map<String, dynamic> metadata;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssessmentStimulus({
    required this.id,
    required this.stimulusType,
    required this.title,
    this.body,
    this.structuredData = const {},
    this.assetRefs = const [],
    this.metadata = const {},
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AssessmentStimulus.fromJson(Map<String, dynamic> json) {
    return AssessmentStimulus(
      id: json['id'] as String,
      stimulusType: AssessmentStimulusType.fromString(
        json['stimulus_type'] as String? ?? 'scenario',
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      structuredData:
          (json['structured_data'] as Map?)?.cast<String, dynamic>() ?? const {},
      assetRefs: (json['asset_refs'] as List?)?.toList() ?? const [],
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdBy: json['created_by'] as String?,
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
      'stimulus_type': stimulusType.toDbString(),
      'title': title,
      'body': body,
      'structured_data': structuredData,
      'asset_refs': assetRefs,
      'metadata': metadata,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AssessmentStimulus copyWith({
    String? id,
    AssessmentStimulusType? stimulusType,
    String? title,
    String? body,
    Map<String, dynamic>? structuredData,
    List<dynamic>? assetRefs,
    Map<String, dynamic>? metadata,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssessmentStimulus(
      id: id ?? this.id,
      stimulusType: stimulusType ?? this.stimulusType,
      title: title ?? this.title,
      body: body ?? this.body,
      structuredData: structuredData ?? this.structuredData,
      assetRefs: assetRefs ?? this.assetRefs,
      metadata: metadata ?? this.metadata,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
