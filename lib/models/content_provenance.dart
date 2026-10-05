class ContentSourceRelease {
  final String id;
  final String publisher;
  final String title;
  final String version;
  final String? sourceUrl;
  final DateTime retrievedAt;
  final String? license;
  final String? sha256;
  final Map<String, dynamic> metadata;

  const ContentSourceRelease({
    required this.id,
    required this.publisher,
    required this.title,
    required this.version,
    this.sourceUrl,
    required this.retrievedAt,
    this.license,
    this.sha256,
    this.metadata = const {},
  });

  factory ContentSourceRelease.fromJson(Map<String, dynamic> json) {
    return ContentSourceRelease(
      id: json['id'] as String,
      publisher: json['publisher'] as String? ?? '',
      title: json['title'] as String? ?? '',
      version: json['version'] as String? ?? '',
      sourceUrl: json['source_url'] as String?,
      retrievedAt: json['retrieved_at'] != null
          ? DateTime.parse(json['retrieved_at'] as String)
          : DateTime.now(),
      license: json['license'] as String?,
      sha256: json['sha256'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'publisher': publisher,
      'title': title,
      'version': version,
      'source_url': sourceUrl,
      'retrieved_at': retrievedAt.toIso8601String(),
      'license': license,
      'sha256': sha256,
      'metadata': metadata,
    };
  }
}

class ContentSourceMapping {
  final String id;
  final String sourceReleaseId;
  final String entityType;
  final String entityId;
  final String relationship;
  final String? citationLocation;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final ContentSourceRelease? release;

  const ContentSourceMapping({
    required this.id,
    required this.sourceReleaseId,
    required this.entityType,
    required this.entityId,
    this.relationship = 'derived_from',
    this.citationLocation,
    this.notes,
    this.metadata = const {},
    required this.createdAt,
    this.release,
  });

  factory ContentSourceMapping.fromJson(Map<String, dynamic> json) {
    ContentSourceRelease? releaseObj;
    if (json['content_source_releases'] is Map) {
      releaseObj = ContentSourceRelease.fromJson(
        (json['content_source_releases'] as Map).cast<String, dynamic>(),
      );
    } else if (json['release'] is Map) {
      releaseObj = ContentSourceRelease.fromJson(
        (json['release'] as Map).cast<String, dynamic>(),
      );
    }

    return ContentSourceMapping(
      id: json['id'] as String,
      sourceReleaseId: json['source_release_id'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? 'lesson',
      entityId: json['entity_id'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'derived_from',
      citationLocation: json['citation_location'] as String?,
      notes: json['notes'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      release: releaseObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_release_id': sourceReleaseId,
      'entity_type': entityType,
      'entity_id': entityId,
      'relationship': relationship,
      'citation_location': citationLocation,
      'notes': notes,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      if (release != null) 'release': release!.toJson(),
    };
  }
}
