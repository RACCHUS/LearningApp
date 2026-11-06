/// A competency definition item for CASE 1.0 standards exchange (ECO-13, OPP-5).
class CaseCompetencyItem {
  final String identifier;
  final String humanCodingScheme;
  final String fullStatement;
  final String? conceptSlug;
  final String? parentIdentifier;

  const CaseCompetencyItem({
    required this.identifier,
    required this.humanCodingScheme,
    required this.fullStatement,
    this.conceptSlug,
    this.parentIdentifier,
  });

  factory CaseCompetencyItem.fromJson(Map<String, dynamic> json) {
    return CaseCompetencyItem(
      identifier: json['identifier'] as String? ?? '',
      humanCodingScheme: json['humanCodingScheme'] as String? ?? '',
      fullStatement: json['fullStatement'] as String? ?? '',
      conceptSlug: json['conceptSlug'] as String?,
      parentIdentifier: json['parentIdentifier'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'humanCodingScheme': humanCodingScheme,
        'fullStatement': fullStatement,
        if (conceptSlug != null) 'conceptSlug': conceptSlug,
        if (parentIdentifier != null) 'parentIdentifier': parentIdentifier,
      };
}

/// Summary of an imported CASE 1.0 standard document.
class CaseDocumentSummary {
  final String identifier;
  final String title;
  final String publisher;
  final String version;
  final List<CaseCompetencyItem> items;

  const CaseDocumentSummary({
    required this.identifier,
    required this.title,
    required this.publisher,
    required this.version,
    required this.items,
  });
}

/// Exporter and importer for 1EdTech CASE 1.0 (Competencies & Academic Standards Exchange).
class CaseStandardsConverter {
  const CaseStandardsConverter._();

  static const String caseContext =
      'https://purl.imsglobal.org/spec/case/v1p0/context/json/imscasestd_v1p0.jsonld';

  /// Generates a compliant 1EdTech CASE 1.0 JSON-LD document package.
  static Map<String, dynamic> exportPackage({
    required String documentId,
    required String title,
    required String description,
    required String publisher,
    String version = '1.0',
    required List<CaseCompetencyItem> items,
  }) {
    final cfItems = items.map((item) {
      return {
        'identifier': item.identifier,
        'uri': 'urn:case:item:${item.identifier}',
        'humanCodingScheme': item.humanCodingScheme,
        'fullStatement': item.fullStatement,
        if (item.conceptSlug != null) 'conceptKeyword': item.conceptSlug,
      };
    }).toList();

    final cfAssociations = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item.parentIdentifier != null) {
        cfAssociations.add({
          'identifier': 'assoc-${item.identifier}-${item.parentIdentifier}',
          'associationType': 'isChildOf',
          'originNodeURI': 'urn:case:item:${item.identifier}',
          'destinationNodeURI': 'urn:case:item:${item.parentIdentifier}',
        });
      }
    }

    return {
      '@context': caseContext,
      'CFDocument': {
        'identifier': documentId,
        'uri': 'urn:case:doc:$documentId',
        'title': title,
        'description': description,
        'publisher': publisher,
        'version': version,
        'adoptionStatus': 'Adopted',
      },
      'CFItems': cfItems,
      'CFAssociations': cfAssociations,
    };
  }

  /// Parses an imported 1EdTech CASE 1.0 JSON-LD package.
  static CaseDocumentSummary importPackage(Map<String, dynamic> json) {
    final doc = (json['CFDocument'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawItems = (json['CFItems'] as List?) ?? [];

    final items = rawItems.map((raw) {
      final m = (raw as Map).cast<String, dynamic>();
      return CaseCompetencyItem(
        identifier: m['identifier'] as String? ?? '',
        humanCodingScheme: m['humanCodingScheme'] as String? ?? '',
        fullStatement: m['fullStatement'] as String? ?? '',
        conceptSlug: m['conceptKeyword'] as String?,
      );
    }).toList();

    return CaseDocumentSummary(
      identifier: doc['identifier'] as String? ?? '',
      title: doc['title'] as String? ?? '',
      publisher: doc['publisher'] as String? ?? '',
      version: doc['version'] as String? ?? '1.0',
      items: items,
    );
  }
}
