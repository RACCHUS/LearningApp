/// EXM-01: typed, fail-closed read models for exam-part configuration and
/// independently effective-dated reference manifests.
///
/// No regulator values are inferred by this model. Publication and database
/// security must be enforced independently by the manifest ingestion workflow.
enum ExamFactState { verified, unverified, unknown, notApplicable }

class ExamOfficialFact {
  final ExamFactState state;
  final Object? value;
  final List<String> evidenceIds;

  const ExamOfficialFact({
    required this.state,
    this.value,
    this.evidenceIds = const [],
  });

  factory ExamOfficialFact.fromJson(Map<String, dynamic> row) {
    final stateText = row['state']?.toString() ?? 'unknown';
    final states = ExamFactState.values.where(
      (s) => _snakeCase(s.name) == stateText,
    );
    if (states.isEmpty) {
      throw FormatException('Unsupported exam official fact state: ' + stateText);
    }
    final state = states.first;
    final ids = _stringList(row['evidence_ids'], 'evidence_ids');
    final value = row['value'];
    if (state == ExamFactState.verified &&
        (value == null || ids.isEmpty)) {
      throw const FormatException(
        'A verified official fact requires a value and source evidence',
      );
    }
    if ((state == ExamFactState.unknown ||
            state == ExamFactState.notApplicable) &&
        value != null) {
      throw const FormatException(
        'Unknown/not-applicable official facts may not invent values',
      );
    }
    return ExamOfficialFact(state: state, value: value, evidenceIds: ids);
  }
}

class ExamPartSpec {
  final String key;
  final String displayName;

  /// May be null in a draft profile, but not for an eligible part-scoped drill.
  final String? curriculumRootNodeId;
  final Map<String, ExamOfficialFact> officialRequirements;

  const ExamPartSpec({
    required this.key,
    required this.displayName,
    this.curriculumRootNodeId,
    this.officialRequirements = const {},
  });

  bool get hasScopeRootCandidate =>
      curriculumRootNodeId != null && curriculumRootNodeId!.isNotEmpty;

  factory ExamPartSpec.fromJson(Map<String, dynamic> json) {
    final key = _requiredText(json['key'], 'exam_parts.key');
    _requirePartKey(key);
    final requirements = <String, ExamOfficialFact>{};
    final source = json['requirements'];
    if (source != null) {
      if (source is! Map) {
        throw const FormatException('Exam part requirements must be an object');
      }
      for (final entry in source.entries) {
        if (entry.value is! Map) {
          throw FormatException('Invalid official requirement: ' + entry.key.toString());
        }
        requirements[entry.key.toString()] = ExamOfficialFact.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    final root = json['curriculum_root_node_id']?.toString();
    return ExamPartSpec(
      key: key,
      displayName: _requiredText(json['display_name'], 'exam_parts.display_name'),
      curriculumRootNodeId: root == null || root.isEmpty ? null : root,
      officialRequirements: Map.unmodifiable(requirements),
    );
  }
}

class ExamPreparationProfile {
  final String targetVersionId;
  final int schemaVersion;
  final List<ExamPartSpec> examParts;

  const ExamPreparationProfile({
    required this.targetVersionId,
    required this.schemaVersion,
    required this.examParts,
  });

  /// Returns null for targets without an EXM-01 profile, not a fabricated part.
  /// Throws for malformed config so an incorrect part never becomes all-parts.
  static ExamPreparationProfile? fromTargetVersionMetadata({
    required String targetVersionId,
    required Map<String, dynamic> metadata,
  }) {
    final raw = metadata['exam_preparation'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('exam_preparation must be an object');
    }
    final json = Map<String, dynamic>.from(raw);
    if (json['schema_version'] != 1 || json['exam_parts'] is! List) {
      throw const FormatException('Unsupported exam profile schema');
    }
    final parts = <ExamPartSpec>[];
    final keys = <String>{};
    for (final rawPart in json['exam_parts'] as List) {
      if (rawPart is! Map) {
        throw const FormatException('exam_parts entries must be objects');
      }
      final part = ExamPartSpec.fromJson(Map<String, dynamic>.from(rawPart));
      if (!keys.add(part.key)) {
        throw FormatException('Duplicate exam part key: ' + part.key);
      }
      parts.add(part);
    }
    if (parts.isEmpty) {
      throw const FormatException('Exam preparation profile has no parts');
    }
    return ExamPreparationProfile(
      targetVersionId: targetVersionId,
      schemaVersion: 1,
      examParts: List.unmodifiable(parts),
    );
  }

  ExamPartSpec? findPart(String key) {
    for (final part in examParts) {
      if (part.key == key) return part;
    }
    return null;
  }
}

enum ExamManifestStatus { draft, reviewReady, published, retired }

/// Immutable metadata snapshot for the applicable official reference list.
/// Source pages and reference permission details stay in a separately reviewed
/// JSON record, never inside immutable target_versions metadata.
class ExamReferenceManifestRevision {
  final String id;
  final String targetVersionId;
  final String examPartKey;
  final int revision;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final ExamManifestStatus status;
  final bool reviewed;
  final String? officialSourceUrl;
  final String? officialSourceReleaseId;
  final DateTime? sourceCheckedAt;
  final DateTime? reviewedAt;
  final List<Map<String, dynamic>> references;
  final List<Map<String, dynamic>> roomRules;

  const ExamReferenceManifestRevision({
    required this.id,
    required this.targetVersionId,
    required this.examPartKey,
    required this.revision,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.status,
    required this.reviewed,
    this.officialSourceUrl,
    this.officialSourceReleaseId,
    this.sourceCheckedAt,
    this.reviewedAt,
    this.references = const [],
    this.roomRules = const [],
  });

  factory ExamReferenceManifestRevision.fromRow(Map<String, dynamic> row) {
    final part = _requiredText(row['exam_part_key'], 'exam_part_key');
    _requirePartKey(part);
    final rawRevision = row['revision'];
    if (rawRevision is! int || rawRevision <= 0) {
      throw const FormatException('Manifest revision must be a positive integer');
    }
    final from = _dateOnly(row['effective_from'], 'effective_from');
    final until = row['effective_until'] == null
        ? null
        : _dateOnly(row['effective_until'], 'effective_until');
    if (until != null && until.isBefore(from)) {
      throw const FormatException('Manifest end date precedes start date');
    }
    final name = row['publication_status']?.toString() ?? '';
    final matching = ExamManifestStatus.values.where(
      (s) => _snakeCase(s.name) == name,
    );
    if (matching.isEmpty) {
      throw FormatException('Unknown publication status: ' + name);
    }
    final sources = _objectList(row['reference_entries'], 'reference_entries');
    final rules = _objectList(row['room_rules'], 'room_rules');
    final status = matching.first;
    final reviewed = row['review_status'] == 'approved' &&
        row['reviewed_at'] != null &&
        row['reviewer_ref']?.toString().isNotEmpty == true;
    final sourceUrl = row['official_source_url']?.toString();
    final sourceReleaseId = row['source_release_id']?.toString();
    final sourceCheckedAt = DateTime.tryParse(
        row['source_checked_at']?.toString() ?? '');
    final reviewedAt = DateTime.tryParse(
        row['reviewed_at']?.toString() ?? '');
    // Published records require actual source evidence, a subsequent human
    // review and anchored editions. Missing/invalid citations are not
    // implicitly verified even if a status string says 'published'.
    if (status == ExamManifestStatus.published) {
      if (!reviewed ||
          sourceUrl == null ||
          !sourceUrl.startsWith('https://') ||
          sourceReleaseId == null ||
          sourceReleaseId.isEmpty ||
          sourceCheckedAt == null ||
          reviewedAt == null ||
          reviewedAt.isBefore(sourceCheckedAt) ||
          sources.isEmpty) {
        throw const FormatException(
          'Published manifest lacks source evidence or human approval',
        );
      }
      for (final entry in sources) {
        _requiredText(entry['key'], 'reference key');
        _requiredText(entry['edition'], 'reference edition');
        _requiredText(entry['source_page'], 'reference primary source page');
      }
      for (final rule in rules) {
        final state = rule['state']?.toString();
        if (!const {'verified', 'unverified', 'unknown', 'not_applicable'}
            .contains(state)) {
          throw const FormatException('Invalid reference-room rule state');
        }
        if (state == 'verified') {
          _requiredText(rule['source_page'], 'verified room-rule source page');
          if (rule['value'] == null) {
            throw const FormatException('Verified room rule lacks value');
          }
        }
        if (state == 'unknown' && rule['value'] != null) {
          throw const FormatException('Unknown room rules cannot assert values');
        }
      }
    }
    return ExamReferenceManifestRevision(
      id: _requiredText(row['id'], 'id'),
      targetVersionId: _requiredText(row['target_version_id'], 'target_version_id'),
      examPartKey: part,
      revision: rawRevision,
      effectiveFrom: from,
      effectiveUntil: until,
      status: status,
      reviewed: reviewed,
      officialSourceUrl: sourceUrl,
      officialSourceReleaseId: sourceReleaseId,
      sourceCheckedAt: sourceCheckedAt,
      reviewedAt: reviewedAt,
      references: List.unmodifiable(sources),
      roomRules: List.unmodifiable(rules),
    );
  }

  bool covers(DateTime administrationDate) {
    final date = DateTime.utc(
      administrationDate.year, administrationDate.month, administrationDate.day,
    );
    return !date.isBefore(effectiveFrom) &&
        (effectiveUntil == null || !date.isAfter(effectiveUntil!));
  }
}

enum ExamManifestSelectionStatus {
  selected,
  unknownExamPart,
  missingPartScope,
  unknownExamDate,
  noApplicableRevision,
  conflictingRevisions,
}

class ExamManifestSelection {
  final ExamManifestSelectionStatus status;
  final ExamReferenceManifestRevision? revision;

  const ExamManifestSelection(this.status, {this.revision});

  bool get isSelected =>
      status == ExamManifestSelectionStatus.selected && revision != null;
}

/// Actual exam administration date is mandatory. Ambiguous or absent source
/// records fail closed rather than silently choosing the newest year.
class ExamReferenceManifestResolver {
  const ExamReferenceManifestResolver();

  ExamManifestSelection select({
    required ExamPreparationProfile profile,
    required String examPartKey,
    required DateTime? administrationDate,
    required Iterable<ExamReferenceManifestRevision> revisions,
  }) {
    final part = profile.findPart(examPartKey);
    if (part == null) {
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.unknownExamPart,
      );
    }
    if (!part.hasScopeRootCandidate) {
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.missingPartScope,
      );
    }
    if (administrationDate == null) {
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.unknownExamDate,
      );
    }
    final matches = revisions.where((revision) =>
        revision.targetVersionId == profile.targetVersionId &&
        revision.examPartKey == examPartKey &&
        revision.status == ExamManifestStatus.published &&
        revision.reviewed &&
        revision.covers(administrationDate)).toList();
    if (matches.isEmpty) {
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.noApplicableRevision,
      );
    }
    if (matches.length > 1) {
      return const ExamManifestSelection(
        ExamManifestSelectionStatus.conflictingRevisions,
      );
    }
    return ExamManifestSelection(
      ExamManifestSelectionStatus.selected,
      revision: matches.single,
    );
  }
}

String _snakeCase(String value) => value.replaceAllMapped(
  RegExp(r'[A-Z]'), (match) => '_' + match.group(0)!.toLowerCase(),
);

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing ' + field);
  }
  return value.trim();
}

void _requirePartKey(String key) {
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(key)) {
    throw FormatException('Invalid stable exam part key: ' + key);
  }
}

List<String> _stringList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! String || e.isEmpty)) {
    throw FormatException(field + ' must be a list of source IDs');
  }
  return List.unmodifiable(value.cast<String>());
}

List<Map<String, dynamic>> _objectList(Object? value, String field) {
  if (value == null) return const [];
  if (value is! List || value.any((e) => e is! Map)) {
    throw FormatException(field + ' must be a list of objects');
  }
  return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

DateTime _dateOnly(Object? value, String field) {
  if (value is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException(field + ' must be YYYY-MM-DD');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] || date.month != parts[1] || date.day != parts[2]) {
    throw FormatException('Invalid date ' + field);
  }
  return date;
}
