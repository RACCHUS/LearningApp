import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/taxonomy/taxonomy.dart';

/// Taxonomy Ingestion Result
class TaxonomyIngestionResult {
  final int externalNodesIngested;
  final int fieldsIngested;
  final int fieldClassificationsLinked;
  final int occupationNodesIngested;
  final int crosswalkMappingsIngested;
  final int lineageTransitionsIngested;
  final List<String> warnings;
  final List<String> errors;

  const TaxonomyIngestionResult({
    this.externalNodesIngested = 0,
    this.fieldsIngested = 0,
    this.fieldClassificationsLinked = 0,
    this.occupationNodesIngested = 0,
    this.crosswalkMappingsIngested = 0,
    this.lineageTransitionsIngested = 0,
    this.warnings = const [],
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Version/Release-Driven Taxonomy Importer
///
/// Implements the authoritative ingestion rules from CANONICAL_TAXONOMY_ARCHITECTURE.md:
///   - Dual-layer plane separation: External classification standards vs. permanent internal fields.
///   - Two-pass hierarchy resolution for parent_id foreign keys.
///   - 5-tier labor taxonomy segregation (BLS SOC vs. O*NET SOC extensions).
///   - Qualitative CIP-SOC crosswalk with mandatory source release provenance.
///   - Decennial lineage validation with valid null endpoints.
class TaxonomyImporter {
  /// Computes SHA256 checksum for provenance recording in taxonomy_source_artifacts.
  static String calculateChecksum(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Produces a stable RFC-4122 UUID from a source identity so repeated
  /// imports resolve to the same primary keys without depending on insertion
  /// order or random UUID generation.
  static String deterministicUuid(String identity) {
    final bytes = sha256.convert(utf8.encode(identity)).bytes.take(16).toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x50; // Version 5-style deterministic UUID.
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC-4122 variant.

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final raw = bytes.map(hex).join();
    return '${raw.substring(0, 8)}-'
        '${raw.substring(8, 12)}-'
        '${raw.substring(12, 16)}-'
        '${raw.substring(16, 20)}-'
        '${raw.substring(20, 32)}';
  }

  static String _recordId(Object? rawId, String identity) {
    if (rawId == null) return deterministicUuid(identity);
    final id = rawId.toString();
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}
  /// Validates and parses raw CIP records with two-pass parent resolution.
  static List<ExternalClassificationNode> parseCipNodes({
    required List<Map<String, dynamic>> rawRecords,
    required String sourceReleaseId,
    String version = '2020',
  }) {
    final nodesByCode = <String, ExternalClassificationNode>{};

    // Pass 1: Instantiate nodes with source parent codes
    for (final r in rawRecords) {
      final code = r['code']?.toString().trim() ?? '';
      final title = r['title']?.toString().trim() ?? '';
      if (code.isEmpty || title.isEmpty) continue;

      final levelCode = r['level_code']?.toString().trim() ??
          (code.length <= 2
              ? 'series'
              : code.contains('.') && code.split('.').last.length <= 2
                  ? 'group'
                  : 'program');

      final depth = levelCode == 'series'
          ? 1
          : levelCode == 'group'
              ? 2
              : 3;

      final sourceParentCode = r['source_parent_code']?.toString().trim() ??
          (levelCode == 'program'
              ? code.substring(0, code.indexOf('.') + 3)
              : levelCode == 'group'
                  ? code.split('.').first
                  : null);

      final id = _recordId(
        r['id'],
        'external|$sourceReleaseId|cip|$version|$code',
      );

      final node = ExternalClassificationNode(
        id: id,
        sourceReleaseId: sourceReleaseId,
        system: 'cip',
        version: version,
        code: code,
        sourceParentCode: sourceParentCode,
        levelCode: levelCode,
        levelDepth: depth,
        title: title,
        definition: r['definition']?.toString(),
        crossReferences: (r['cross_references'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        illustrativeExamples: (r['illustrative_examples'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
        isActive: r['is_active'] as bool? ?? true,
      );

      nodesByCode[code] = node;
    }

    // Pass 2: Resolve parent_id from sourceParentCode
    final resolvedNodes = <ExternalClassificationNode>[];
    for (final node in nodesByCode.values) {
      String? resolvedParentId;
      if (node.sourceParentCode != null) {
        resolvedParentId = nodesByCode[node.sourceParentCode]?.id;
      }
      resolvedNodes.add(ExternalClassificationNode(
        id: node.id,
        sourceReleaseId: node.sourceReleaseId,
        parentId: resolvedParentId,
        system: node.system,
        version: node.version,
        code: node.code,
        sourceParentCode: node.sourceParentCode,
        levelCode: node.levelCode,
        levelDepth: node.levelDepth,
        title: node.title,
        definition: node.definition,
        crossReferences: node.crossReferences,
        illustrativeExamples: node.illustrativeExamples,
        metadata: node.metadata,
        isActive: node.isActive,
      ));
    }

    return resolvedNodes;
  }

  /// Parses 5-tier SOC and O*NET occupation nodes enforcing system segregation.
  static List<OccupationNode> parseOccupationNodes({
    required List<Map<String, dynamic>> rawRecords,
    String? baseSourceReleaseId,
    String? onetSourceReleaseId,
  }) {
    final nodesByCode = <String, OccupationNode>{};

    // Pass 1: Parse and validate check constraints
    for (final r in rawRecords) {
      final code = r['code']?.toString().trim() ?? '';
      final title = r['title']?.toString().trim() ?? '';
      final rawLevel = r['level']?.toString().trim() ?? 'detailed_occupation';

      if (code.isEmpty || title.isEmpty) continue;

      final isOnet = rawLevel == 'onet_extension' || code.contains('.');
      final level = isOnet ? 'onet_extension' : rawLevel;
      final taxonomySystem = isOnet ? 'onet_soc' : 'bls_soc';
      final taxonomyVersion = isOnet
          ? (r['taxonomy_version']?.toString() ?? '2019')
          : (r['taxonomy_version']?.toString() ?? 'soc_2018');
      final dataReleaseVersion = isOnet
          ? (r['data_release_version']?.toString() ?? 'onet_31_0')
          : null;
      final releaseId = isOnet ? onetSourceReleaseId : baseSourceReleaseId;

      final id = _recordId(
        r['id'],
        'occupation|${releaseId ?? 'no-release'}|$taxonomySystem|'
        '$taxonomyVersion|${dataReleaseVersion ?? ''}|$code',
      );

      nodesByCode[code] = OccupationNode(
        id: id,
        code: code,
        title: title,
        description: r['description']?.toString(),
        level: level,
        taxonomySystem: taxonomySystem,
        taxonomyVersion: taxonomyVersion,
        dataReleaseVersion: dataReleaseVersion,
        jobZone: (r['job_zone'] as num?)?.toInt(),
        sourceReleaseId: releaseId,
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
        isActive: r['is_active'] as bool? ?? true,
      );
    }

    // Pass 2: Resolve parent links
    final resolvedOccupations = <OccupationNode>[];
    for (final o in nodesByCode.values) {
      String? parentId;
      if (o.isOnetExtension) {
        // e.g. 15-1252.00 -> parent detailed occupation is 15-1252
        final baseCode = o.code.split('.').first;
        parentId = nodesByCode[baseCode]?.id;
      } else if (o.isDetailedOccupation) {
        // e.g. 15-1252 -> broad occupation 15-1250 or minor 15-1200 or major 15-0000
        final broadCode = '${o.code.substring(0, 6)}0';
        final minorCode = '${o.code.substring(0, 5)}00';
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[broadCode]?.id ??
            nodesByCode[minorCode]?.id ??
            nodesByCode[majorCode]?.id;
      } else if (o.isBroadOccupation) {
        final minorCode = '${o.code.substring(0, 5)}00';
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[minorCode]?.id ?? nodesByCode[majorCode]?.id;
      } else if (o.isMinorGroup) {
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[majorCode]?.id;
      }

      resolvedOccupations.add(OccupationNode(
        id: o.id,
        parentId: parentId,
        code: o.code,
        title: o.title,
        description: o.description,
        level: o.level,
        taxonomySystem: o.taxonomySystem,
        taxonomyVersion: o.taxonomyVersion,
        dataReleaseVersion: o.dataReleaseVersion,
        jobZone: o.jobZone,
        sourceReleaseId: o.sourceReleaseId,
        metadata: o.metadata,
        isActive: o.isActive,
      ));
    }

    return resolvedOccupations;
  }

  /// Validates and parses decennial taxonomy lineage transitions.
  static List<TaxonomyNodeLineage> parseLineageRecords(
      List<Map<String, dynamic>> rawRecords) {
    const validTransitions = {
      'unchanged',
      'renamed',
      'split_into',
      'merged_into',
      'moved_to',
      'deleted',
      'newly_introduced',
    };

    final list = <TaxonomyNodeLineage>[];

    for (final r in rawRecords) {
      final system = r['source_system']?.toString() ?? 'cip';
      final fromVer = r['from_version']?.toString() ?? '';
      final fromCode = r['from_code']?.toString();
      final toVer = r['to_version']?.toString() ?? '';
      final toCode = r['to_code']?.toString();
      final transition = r['transition_type']?.toString() ?? 'unchanged';

      if (!validTransitions.contains(transition)) {
        throw FormatException('Invalid transition_type "$transition". Must be one of $validTransitions');
      }

      // Check constraints validation
      if (transition == 'deleted') {
        if (fromCode == null || toCode != null) {
          throw FormatException('Deleted transition must have non-null from_code and null to_code');
        }
      } else if (transition == 'newly_introduced') {
        if (fromCode != null || toCode == null) {
          throw FormatException('Newly introduced transition must have null from_code and non-null to_code');
        }
      } else {
        if (fromCode == null || toCode == null) {
          throw FormatException('Transition "$transition" requires both from_code and to_code to be non-null');
        }
      }

      final id = _recordId(
        r['id'],
        'lineage|$system|$fromVer|${fromCode ?? ''}|$toVer|'
        '${toCode ?? ''}|$transition',
      );

      list.add(TaxonomyNodeLineage(
        id: id,
        sourceSystem: system,
        fromVersion: fromVer,
        fromCode: fromCode,
        toVersion: toVer,
        toCode: toCode,
        transitionType: transition,
        notes: r['notes']?.toString(),
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
      ));
    }

    return list;
  }
}
,
    );
    if (!uuidPattern.hasMatch(id)) {
      throw FormatException('Taxonomy record id must be a UUID: "$id"');
    }
    return id;
  }

  /// Validates and parses raw CIP records with two-pass parent resolution.
  static List<ExternalClassificationNode> parseCipNodes({
    required List<Map<String, dynamic>> rawRecords,
    required String sourceReleaseId,
    String version = '2020',
  }) {
    final nodesByCode = <String, ExternalClassificationNode>{};

    // Pass 1: Instantiate nodes with source parent codes
    for (final r in rawRecords) {
      final code = r['code']?.toString().trim() ?? '';
      final title = r['title']?.toString().trim() ?? '';
      if (code.isEmpty || title.isEmpty) continue;

      final levelCode = r['level_code']?.toString().trim() ??
          (code.length <= 2
              ? 'series'
              : code.contains('.') && code.split('.').last.length <= 2
                  ? 'group'
                  : 'program');

      final depth = levelCode == 'series'
          ? 1
          : levelCode == 'group'
              ? 2
              : 3;

      final sourceParentCode = r['source_parent_code']?.toString().trim() ??
          (levelCode == 'program'
              ? code.substring(0, code.indexOf('.') + 3)
              : levelCode == 'group'
                  ? code.split('.').first
                  : null);

      final id = r['id']?.toString() ?? 'ext-cip-$version-$code';

      final node = ExternalClassificationNode(
        id: id,
        sourceReleaseId: sourceReleaseId,
        system: 'cip',
        version: version,
        code: code,
        sourceParentCode: sourceParentCode,
        levelCode: levelCode,
        levelDepth: depth,
        title: title,
        definition: r['definition']?.toString(),
        crossReferences: (r['cross_references'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        illustrativeExamples: (r['illustrative_examples'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
        isActive: r['is_active'] as bool? ?? true,
      );

      nodesByCode[code] = node;
    }

    // Pass 2: Resolve parent_id from sourceParentCode
    final resolvedNodes = <ExternalClassificationNode>[];
    for (final node in nodesByCode.values) {
      String? resolvedParentId;
      if (node.sourceParentCode != null) {
        resolvedParentId = nodesByCode[node.sourceParentCode]?.id;
      }
      resolvedNodes.add(ExternalClassificationNode(
        id: node.id,
        sourceReleaseId: node.sourceReleaseId,
        parentId: resolvedParentId,
        system: node.system,
        version: node.version,
        code: node.code,
        sourceParentCode: node.sourceParentCode,
        levelCode: node.levelCode,
        levelDepth: node.levelDepth,
        title: node.title,
        definition: node.definition,
        crossReferences: node.crossReferences,
        illustrativeExamples: node.illustrativeExamples,
        metadata: node.metadata,
        isActive: node.isActive,
      ));
    }

    return resolvedNodes;
  }

  /// Parses 5-tier SOC and O*NET occupation nodes enforcing system segregation.
  static List<OccupationNode> parseOccupationNodes({
    required List<Map<String, dynamic>> rawRecords,
    String? baseSourceReleaseId,
    String? onetSourceReleaseId,
  }) {
    final nodesByCode = <String, OccupationNode>{};

    // Pass 1: Parse and validate check constraints
    for (final r in rawRecords) {
      final code = r['code']?.toString().trim() ?? '';
      final title = r['title']?.toString().trim() ?? '';
      final rawLevel = r['level']?.toString().trim() ?? 'detailed_occupation';

      if (code.isEmpty || title.isEmpty) continue;

      final isOnet = rawLevel == 'onet_extension' || code.contains('.');
      final level = isOnet ? 'onet_extension' : rawLevel;
      final taxonomySystem = isOnet ? 'onet_soc' : 'bls_soc';
      final taxonomyVersion = isOnet
          ? (r['taxonomy_version']?.toString() ?? '2019')
          : (r['taxonomy_version']?.toString() ?? 'soc_2018');
      final dataReleaseVersion = isOnet
          ? (r['data_release_version']?.toString() ?? 'onet_31_0')
          : null;
      final releaseId = isOnet ? onetSourceReleaseId : baseSourceReleaseId;

      final id = r['id']?.toString() ?? 'occ-$code';

      nodesByCode[code] = OccupationNode(
        id: id,
        code: code,
        title: title,
        description: r['description']?.toString(),
        level: level,
        taxonomySystem: taxonomySystem,
        taxonomyVersion: taxonomyVersion,
        dataReleaseVersion: dataReleaseVersion,
        jobZone: (r['job_zone'] as num?)?.toInt(),
        sourceReleaseId: releaseId,
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
        isActive: r['is_active'] as bool? ?? true,
      );
    }

    // Pass 2: Resolve parent links
    final resolvedOccupations = <OccupationNode>[];
    for (final o in nodesByCode.values) {
      String? parentId;
      if (o.isOnetExtension) {
        // e.g. 15-1252.00 -> parent detailed occupation is 15-1252
        final baseCode = o.code.split('.').first;
        parentId = nodesByCode[baseCode]?.id;
      } else if (o.isDetailedOccupation) {
        // e.g. 15-1252 -> broad occupation 15-1250 or minor 15-1200 or major 15-0000
        final broadCode = '${o.code.substring(0, 6)}0';
        final minorCode = '${o.code.substring(0, 5)}00';
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[broadCode]?.id ??
            nodesByCode[minorCode]?.id ??
            nodesByCode[majorCode]?.id;
      } else if (o.isBroadOccupation) {
        final minorCode = '${o.code.substring(0, 5)}00';
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[minorCode]?.id ?? nodesByCode[majorCode]?.id;
      } else if (o.isMinorGroup) {
        final majorCode = '${o.code.substring(0, 2)}-0000';
        parentId = nodesByCode[majorCode]?.id;
      }

      resolvedOccupations.add(OccupationNode(
        id: o.id,
        parentId: parentId,
        code: o.code,
        title: o.title,
        description: o.description,
        level: o.level,
        taxonomySystem: o.taxonomySystem,
        taxonomyVersion: o.taxonomyVersion,
        dataReleaseVersion: o.dataReleaseVersion,
        jobZone: o.jobZone,
        sourceReleaseId: o.sourceReleaseId,
        metadata: o.metadata,
        isActive: o.isActive,
      ));
    }

    return resolvedOccupations;
  }

  /// Validates and parses decennial taxonomy lineage transitions.
  static List<TaxonomyNodeLineage> parseLineageRecords(
      List<Map<String, dynamic>> rawRecords) {
    const validTransitions = {
      'unchanged',
      'renamed',
      'split_into',
      'merged_into',
      'moved_to',
      'deleted',
      'newly_introduced',
    };

    final list = <TaxonomyNodeLineage>[];

    for (final r in rawRecords) {
      final system = r['source_system']?.toString() ?? 'cip';
      final fromVer = r['from_version']?.toString() ?? '';
      final fromCode = r['from_code']?.toString();
      final toVer = r['to_version']?.toString() ?? '';
      final toCode = r['to_code']?.toString();
      final transition = r['transition_type']?.toString() ?? 'unchanged';

      if (!validTransitions.contains(transition)) {
        throw FormatException('Invalid transition_type "$transition". Must be one of $validTransitions');
      }

      // Check constraints validation
      if (transition == 'deleted') {
        if (fromCode == null || toCode != null) {
          throw FormatException('Deleted transition must have non-null from_code and null to_code');
        }
      } else if (transition == 'newly_introduced') {
        if (fromCode != null || toCode == null) {
          throw FormatException('Newly introduced transition must have null from_code and non-null to_code');
        }
      } else {
        if (fromCode == null || toCode == null) {
          throw FormatException('Transition "$transition" requires both from_code and to_code to be non-null');
        }
      }

      final id = r['id']?.toString() ?? 'lin-$system-$fromVer-$fromCode-$toVer-$toCode';

      list.add(TaxonomyNodeLineage(
        id: id,
        sourceSystem: system,
        fromVersion: fromVer,
        fromCode: fromCode,
        toVersion: toVer,
        toCode: toCode,
        transitionType: transition,
        notes: r['notes']?.toString(),
        metadata: r['metadata'] is Map<String, dynamic>
            ? r['metadata'] as Map<String, dynamic>
            : const {},
      ));
    }

    return list;
  }
}
