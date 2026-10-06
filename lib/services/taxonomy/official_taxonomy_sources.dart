import 'dart:convert';

import 'taxonomy_importer.dart';

/// One authoritative CIP 2020 -> SOC 2018 relationship from the federal
/// NCES/BLS qualitative crosswalk.
class OfficialCipSocMapping {
  final String cipCode;
  final String socCode;
  final String? cipTitle;
  final String? socTitle;

  const OfficialCipSocMapping({
    required this.cipCode,
    required this.socCode,
    this.cipTitle,
    this.socTitle,
  });

  Map<String, dynamic> toJson() => {
        'cip_code': cipCode,
        'soc_code': socCode,
        if (cipTitle != null) 'cip_title': cipTitle,
        if (socTitle != null) 'soc_title': socTitle,
      };
}

/// Structural validation result for a downloaded official taxonomy bundle.
class OfficialTaxonomyValidationReport {
  final Map<String, int> counts;
  final List<String> warnings;
  final List<String> errors;

  const OfficialTaxonomyValidationReport({
    required this.counts,
    this.warnings = const [],
    this.errors = const [],
  });

  bool get isValid => errors.isEmpty;

  void throwIfInvalid() {
    if (isValid) return;
    throw StateError(
      'Official taxonomy validation failed:\n- ${errors.join('\n- ')}',
    );
  }
}

/// Parsers for the authoritative NCES, BLS, and O*NET source artifacts.
///
/// These parsers deliberately operate on plain strings/rows. XLSX decoding is
/// kept in the CLI layer so normal Flutter builds do not depend on file I/O.
class OfficialTaxonomyParser {
  static final RegExp _cipCodePattern =
      RegExp(r'^\d{2}(?:\.\d{2}(?:\d{2})?)?$');
  static final RegExp _socCodePattern = RegExp(r'^\d{2}-\d{4}$');
  static final RegExp _onetCodePattern = RegExp(r'^\d{2}-\d{4}\.\d{2}$');

  /// RFC4180-style CSV reader supporting quoted commas, escaped quotes, CRLF,
  /// and embedded newlines. It is intentionally local to taxonomy ingestion so
  /// the app does not need a runtime CSV dependency.
  static List<List<String>> parseCsv(String input) {
    if (input.startsWith('\uFEFF')) {
      input = input.substring(1);
    }

    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (quoted) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(ch);
        }
        continue;
      }

      if (ch == '"' && field.isEmpty) {
        quoted = true;
      } else if (ch == ',') {
        row.add(field.toString());
        field.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
      } else {
        field.write(ch);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.isNotEmpty)) {
        rows.add(row);
      }
    }

    return rows;
  }

  /// Parses the official NCES CIPCode2020.csv file into the canonical raw
  /// records consumed by [TaxonomyImporter.parseCipNodes].
  static List<Map<String, dynamic>> parseCip2020Csv(String csvText) {
    final rows = parseCsv(csvText);
    if (rows.isEmpty) {
      throw const FormatException('CIP 2020 CSV is empty.');
    }

    final headerIndex = _findHeaderRow(
      rows,
      (headers) =>
          _findHeader(headers, const ['cipcode']) != null &&
          _findHeader(headers, const ['ciptitle']) != null,
    );
    final headers = _headerMap(rows[headerIndex]);

    final codeCol = _requireHeader(headers, const ['cipcode'], 'CIPCode');
    final titleCol = _requireHeader(headers, const ['ciptitle'], 'CIPTitle');
    final definitionCol =
        _findHeader(headers, const ['cipdefinition', 'definition']);
    final crossRefsCol =
        _findHeader(headers, const ['crossreferences', 'crossreference']);
    final examplesCol =
        _findHeader(headers, const ['examples', 'illustrativeexamples']);
    final actionCol = _findHeader(headers, const ['action']);
    final textChangeCol = _findHeader(headers, const ['textchange']);
    final familyCol = _findHeader(headers, const ['cipfamily']);

    final records = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final row in rows.skip(headerIndex + 1)) {
      final rawCode = _cell(row, codeCol);
      final code = _extractCipCode(rawCode);
      if (code == null || !seen.add(code)) continue;

      final title = _cell(row, titleCol).trim();
      if (title.isEmpty) continue;

      // NCES CIP 2020 includes reserved placeholder series (e.g. 21 and 55)
      // that are marked with title "RESERVED." and do not represent active programs.
      final normalizedTitle =
          title.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      if (normalizedTitle == 'RESERVED') continue;

      final level = _cipLevel(code);
      records.add({
        'code': code,
        'title': title,
        'level_code': level,
        'source_parent_code': _cipParentCode(code),
        if (definitionCol != null)
          'definition': _nullIfEmpty(_cell(row, definitionCol)),
        if (crossRefsCol != null)
          'cross_references': _splitList(_cell(row, crossRefsCol)),
        if (examplesCol != null)
          'illustrative_examples': _splitList(_cell(row, examplesCol)),
        'metadata': {
          if (familyCol != null && _cell(row, familyCol).trim().isNotEmpty)
            'cip_family': _cell(row, familyCol).trim(),
          if (actionCol != null && _cell(row, actionCol).trim().isNotEmpty)
            'source_action': _cell(row, actionCol).trim(),
          if (textChangeCol != null &&
              _cell(row, textChangeCol).trim().isNotEmpty)
            'text_change': _cell(row, textChangeCol).trim(),
        },
      });
    }

    if (records.isEmpty) {
      throw const FormatException('No active CIP 2020 codes were parsed.');
    }
    return records;
  }

  /// Parses the BLS 2018 SOC Structure workbook after the CLI has converted a
  /// sheet into string rows. The parser is resilient to title/code placement:
  /// it finds the SOC code in each row and then the nearest descriptive cell.
  static List<Map<String, dynamic>> parseSoc2018Rows(
    List<List<String>> rows, {
    Map<String, String> definitions = const {},
  }) {
    final recordsByCode = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      for (var index = 0; index < row.length; index++) {
        final value = row[index].trim();
        final match = RegExp(r'(^|\s)(\d{2}-\d{4})(?:\s+|$)')
            .firstMatch(value);
        if (match == null) continue;

        final code = match.group(2)!;
        if (!_socCodePattern.hasMatch(code)) continue;

        var title = value.replaceFirst(code, '').trim();
        if (title.isEmpty) {
          for (var i = row.length - 1; i >= 0; i--) {
            final candidate = row[i].trim();
            if (candidate.isEmpty || candidate == code) continue;
            if (_socCodePattern.hasMatch(candidate)) continue;
            if (_looksLikeSocHeader(candidate)) continue;
            title = candidate;
            break;
          }
        }

        if (title.isEmpty || _looksLikeSocHeader(title)) continue;

        recordsByCode[code] = {
          'code': code,
          'title': title,
          'description': definitions[code],
          'level': _socLevel(code),
          'taxonomy_version': 'soc_2018',
        };
        break;
      }
    }

    return recordsByCode.values.toList()
      ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));
  }

  /// Parses the official BLS 2018 SOC Definitions workbook into a code ->
  /// definition map that can enrich every hierarchy node supported by BLS.
  static Map<String, String> parseSoc2018DefinitionsRows(
    List<List<String>> rows,
  ) {
    if (rows.isEmpty) return const {};

    int? codeCol;
    int? definitionCol;
    try {
      final headerIndex = _findHeaderRow(rows, (headers) {
        codeCol = _findHeader(
          headers,
          const ['soccode', '2018soccode', 'code'],
        );
        definitionCol = _findHeader(
          headers,
          const ['definition', 'socdefinition'],
        );
        return codeCol != null && definitionCol != null;
      });
      final headers = _headerMap(rows[headerIndex]);
      codeCol = _findHeader(headers, const ['soccode', '2018soccode', 'code']);
      definitionCol =
          _findHeader(headers, const ['definition', 'socdefinition']);

      final definitions = <String, String>{};
      for (final row in rows.skip(headerIndex + 1)) {
        final code = _extractSocCode(_cell(row, codeCol!));
        final definition = _nullIfEmpty(_cell(row, definitionCol!));
        if (code != null && definition != null) {
          definitions[code] = definition;
        }
      }
      if (definitions.isNotEmpty) return definitions;
    } on FormatException {
      // Fall through to the structure-agnostic scan below.
    }

    final definitions = <String, String>{};
    for (final row in rows) {
      String? code;
      var codeIndex = -1;
      for (var i = 0; i < row.length; i++) {
        code = _extractSocCode(row[i]);
        if (code != null) {
          codeIndex = i;
          break;
        }
      }
      if (code == null) continue;

      final candidates = <String>[];
      for (var i = 0; i < row.length; i++) {
        if (i == codeIndex) continue;
        final value = row[i].trim();
        if (value.length >= 40 && !_socCodePattern.hasMatch(value)) {
          candidates.add(value);
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.length.compareTo(a.length));
        definitions[code] = candidates.first;
      }
    }
    return definitions;
  }

  /// Parses O*NET 31.0 Occupation Data.xlsx plus Job Zones.xlsx.
  ///
  /// Occupation Data contains all 1,016 O*NET-SOC 2019 taxonomy occupations.
  /// Job Zones contains the 923 data-level occupations with published zone data.
  static List<Map<String, dynamic>> parseOnet31Rows({
    required List<List<String>> occupationRows,
    required List<List<String>> jobZoneRows,
  }) {
    final zoneHeadersIndex = _findHeaderRow(
      jobZoneRows,
      (headers) =>
          _findHeader(headers, const ['onetsoccode']) != null &&
          _findHeader(headers, const ['jobzone']) != null,
    );
    final zoneHeaders = _headerMap(jobZoneRows[zoneHeadersIndex]);
    final zoneCodeCol =
        _requireHeader(zoneHeaders, const ['onetsoccode'], 'O*NET-SOC Code');
    final zoneCol = _requireHeader(zoneHeaders, const ['jobzone'], 'Job Zone');

    final jobZones = <String, int>{};
    for (final row in jobZoneRows.skip(zoneHeadersIndex + 1)) {
      final code = _extractOnetCode(_cell(row, zoneCodeCol));
      final zone = int.tryParse(_cell(row, zoneCol).trim());
      if (code != null && zone != null) {
        jobZones[code] = zone;
      }
    }

    final headerIndex = _findHeaderRow(
      occupationRows,
      (headers) =>
          _findHeader(headers, const ['onetsoccode']) != null &&
          _findHeader(headers, const ['title']) != null,
    );
    final headers = _headerMap(occupationRows[headerIndex]);
    final codeCol =
        _requireHeader(headers, const ['onetsoccode'], 'O*NET-SOC Code');
    final titleCol = _requireHeader(headers, const ['title'], 'Title');
    final descriptionCol =
        _findHeader(headers, const ['description', 'occupationdescription']);

    final records = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final row in occupationRows.skip(headerIndex + 1)) {
      final code = _extractOnetCode(_cell(row, codeCol));
      if (code == null || !seen.add(code)) continue;
      final title = _cell(row, titleCol).trim();
      if (title.isEmpty) continue;

      records.add({
        'code': code,
        'title': title,
        'description': descriptionCol == null
            ? null
            : _nullIfEmpty(_cell(row, descriptionCol)),
        'level': 'onet_extension',
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
        'data_release_version': 'onet_31_0',
        'job_zone': jobZones[code],
        'metadata': {
          'is_data_level': jobZones.containsKey(code),
        },
      });
    }
    return records;
  }

  /// Parses the official NCES CIP 2020 -> SOC 2018 XLSX sheet.
  static List<OfficialCipSocMapping> parseCipSocCrosswalkRows(
    List<List<String>> rows,
  ) {
    final headerIndex = _findHeaderRow(
      rows,
      (headers) {
        final cipCol = _findCodeHeader(headers, 'cip', '2020');
        final socCol = _findCodeHeader(headers, 'soc', '2018');
        return cipCol != null && socCol != null && cipCol != socCol;
      },
    );
    final headers = _headerMap(rows[headerIndex]);
    final cipCodeCol = _findCodeHeader(headers, 'cip', '2020')!;
    final socCodeCol = _findCodeHeader(headers, 'soc', '2018')!;
    final cipTitleCol = _findTitleHeader(headers, 'cip', '2020');
    final socTitleCol = _findTitleHeader(headers, 'soc', '2018');

    final mappings = <OfficialCipSocMapping>[];
    final seen = <String>{};

    for (final row in rows.skip(headerIndex + 1)) {
      final cipCode = _extractCipCode(_cell(row, cipCodeCol));
      final socCode = _extractSocCode(_cell(row, socCodeCol));
      if (cipCode == null || socCode == null) continue;
      // Exclude federal unmatched sentinels (e.g. 99.9999 / 99-9999 "NO MATCH")
      if (cipCode.startsWith('99.') || socCode.startsWith('99-')) continue;
      if (cipCode.length != 7 || !seen.add('$cipCode|$socCode')) continue;

      mappings.add(
        OfficialCipSocMapping(
          cipCode: cipCode,
          socCode: socCode,
          cipTitle: cipTitleCol == null
              ? null
              : _nullIfEmpty(_cell(row, cipTitleCol)),
          socTitle: socTitleCol == null
              ? null
              : _nullIfEmpty(_cell(row, socTitleCol)),
        ),
      );
    }

    return mappings;
  }

  /// Parses NCES Crosswalk2010to2020.csv and derives normalized lineage
  /// semantics, including one-to-many splits and many-to-one merges.
  static List<Map<String, dynamic>> parseCip2010To2020Lineage(
    String csvText,
  ) {
    final rows = parseCsv(csvText);
    return _parseLineageRows(
      rows,
      sourceSystem: 'cip',
      fromVersion: '2010',
      toVersion: '2020',
      fromSystemToken: 'cip',
      toSystemToken: 'cip',
    );
  }

  /// Parses BLS soc_2010_to_2018_crosswalk.xlsx rows and derives normalized
  /// lineage semantics.
  static List<Map<String, dynamic>> parseSoc2010To2018Lineage(
    List<List<String>> rows,
  ) {
    return _parseLineageRows(
      rows,
      sourceSystem: 'bls_soc',
      fromVersion: '2010',
      toVersion: '2018',
      fromSystemToken: 'soc',
      toSystemToken: 'soc',
    );
  }

  /// Validates that the bundle looks like the complete official releases rather
  /// than a sample or truncated download.
  static OfficialTaxonomyValidationReport validateBundle({
    required List<Map<String, dynamic>> cipRecords,
    required List<Map<String, dynamic>> socRecords,
    required List<Map<String, dynamic>> onetRecords,
    required List<OfficialCipSocMapping> cipSocMappings,
    List<Map<String, dynamic>> cipLineage = const [],
    List<Map<String, dynamic>> socLineage = const [],
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    final cipSeries =
        cipRecords.where((r) => r['level_code'] == 'series').length;
    final cipPrograms =
        cipRecords.where((r) => r['level_code'] == 'program').length;

    final socByLevel = <String, int>{};
    for (final row in socRecords) {
      final level = row['level']?.toString() ?? '';
      socByLevel[level] = (socByLevel[level] ?? 0) + 1;
    }

    final onetWithZone =
        onetRecords.where((r) => r['job_zone'] is int).length;

    final counts = <String, int>{
      'cip_nodes': cipRecords.length,
      'cip_series': cipSeries,
      'cip_programs': cipPrograms,
      'soc_nodes': socRecords.length,
      'soc_major_groups': socByLevel['major_group'] ?? 0,
      'soc_minor_groups': socByLevel['minor_group'] ?? 0,
      'soc_broad_occupations': socByLevel['broad_occupation'] ?? 0,
      'soc_detailed_occupations': socByLevel['detailed_occupation'] ?? 0,
      'onet_occupations': onetRecords.length,
      'onet_job_zones': onetWithZone,
      'cip_soc_mappings': cipSocMappings.length,
      'cip_lineage': cipLineage.length,
      'soc_lineage': socLineage.length,
    };

    if (cipSeries < 48 || cipSeries > 50) {
      errors.add('CIP 2020 should contain 48 active 2-digit series; found $cipSeries.');
    }
    if (cipRecords.length < 2000 || cipPrograms < 1000) {
      errors.add(
        'CIP 2020 appears truncated: ${cipRecords.length} total nodes / '
        '$cipPrograms six-digit programs.',
      );
    }

    const expectedSoc = {
      'major_group': 23,
      'minor_group': 98,
      'broad_occupation': 459,
      'detailed_occupation': 867,
    };
    for (final expected in expectedSoc.entries) {
      final actual = socByLevel[expected.key] ?? 0;
      if (actual != expected.value) {
        errors.add(
          'SOC 2018 ${expected.key} count should be ${expected.value}; found $actual.',
        );
      }
    }

    if (onetRecords.length != 1016) {
      errors.add(
        'O*NET-SOC 2019 taxonomy should contain 1,016 occupations; '
        'found ${onetRecords.length}.',
      );
    }
    if (onetWithZone != 923) {
      errors.add(
        'O*NET 31.0 Job Zones should cover 923 occupations; found $onetWithZone.',
      );
    }

    final mappedCipCodes = cipSocMappings.map((mapping) => mapping.cipCode).toSet();
    if (cipSocMappings.length < 2000 || mappedCipCodes.length < 1000) {
      errors.add(
        'CIP 2020 -> SOC 2018 crosswalk appears truncated: '
        '${cipSocMappings.length} mappings across '
        '${mappedCipCodes.length} CIP programs.',
      );
    }

    final cipProgramCodes = cipRecords
        .where((r) => r['level_code'] == 'program')
        .map((r) => r['code'] as String)
        .toSet();
    final socDetailedCodes = socRecords
        .where((r) => r['level'] == 'detailed_occupation')
        .map((r) => r['code'] as String)
        .toSet();

    final missingCip = <String>{};
    final missingSoc = <String>{};
    for (final mapping in cipSocMappings) {
      if (!cipProgramCodes.contains(mapping.cipCode)) {
        missingCip.add(mapping.cipCode);
      }
      if (!socDetailedCodes.contains(mapping.socCode)) {
        missingSoc.add(mapping.socCode);
      }
    }
    if (missingCip.isNotEmpty) {
      errors.add(
        'Crosswalk references ${missingCip.length} CIP codes absent from CIP 2020.',
      );
    }
    if (missingSoc.isNotEmpty) {
      errors.add(
        'Crosswalk references ${missingSoc.length} SOC codes absent from SOC 2018.',
      );
    }

    final baseSocCodes = socDetailedCodes;
    final orphanOnet = onetRecords
        .map((r) => r['code'] as String)
        .where((code) => !baseSocCodes.contains(code.split('.').first))
        .toSet();
    if (orphanOnet.isNotEmpty) {
      errors.add(
        'O*NET contains ${orphanOnet.length} occupation codes without a '
        'matching 2018 detailed SOC parent.',
      );
    }

    if (cipLineage.isNotEmpty && cipLineage.length < 1000) {
      warnings.add(
        'CIP 2010 -> 2020 lineage contains only ${cipLineage.length} rows; '
        'verify the NCES crosswalk was complete.',
      );
    }
    if (socLineage.isNotEmpty && socLineage.length < 500) {
      warnings.add(
        'SOC 2010 -> 2018 lineage contains only ${socLineage.length} rows; '
        'verify the BLS crosswalk was complete.',
      );
    }

    return OfficialTaxonomyValidationReport(
      counts: counts,
      warnings: warnings,
      errors: errors,
    );
  }

  static List<Map<String, dynamic>> _parseLineageRows(
    List<List<String>> rows, {
    required String sourceSystem,
    required String fromVersion,
    required String toVersion,
    required String fromSystemToken,
    required String toSystemToken,
  }) {
    if (rows.isEmpty) return const [];

    final headerIndex = _findHeaderRow(rows, (headers) {
      final normalized = headers.keys;
      return normalized.any(
            (h) => h.contains(fromSystemToken) && h.contains(fromVersion),
          ) &&
          normalized.any(
            (h) => h.contains(toSystemToken) && h.contains(toVersion),
          );
    });
    final headers = _headerMap(rows[headerIndex]);

    final fromCodeCol =
        _findVersionedCodeHeader(headers, fromSystemToken, fromVersion);
    final toCodeCol =
        _findVersionedCodeHeader(headers, toSystemToken, toVersion);
    if (fromCodeCol == null || toCodeCol == null) {
      throw FormatException(
        'Unable to identify $fromVersion/$toVersion code columns.',
      );
    }

    final fromTitleCol =
        _findVersionedTitleHeader(headers, fromSystemToken, fromVersion);
    final toTitleCol =
        _findVersionedTitleHeader(headers, toSystemToken, toVersion);
    final actionCol = _findHeader(headers, const ['action', 'typeofchange']);

    final edges = <_LineageEdge>[];
    final seen = <String>{};
    for (final row in rows.skip(headerIndex + 1)) {
      final rawFrom = _cell(row, fromCodeCol);
      final rawTo = _cell(row, toCodeCol);
      final fromCode = sourceSystem == 'cip'
          ? _extractCipCode(rawFrom)
          : _extractSocCode(rawFrom);
      final toCode = sourceSystem == 'cip'
          ? _extractCipCode(rawTo)
          : _extractSocCode(rawTo);

      if (fromCode == null && toCode == null) continue;
      final key = '${fromCode ?? ''}|${toCode ?? ''}';
      if (!seen.add(key)) continue;

      edges.add(
        _LineageEdge(
          fromCode: fromCode,
          toCode: toCode,
          fromTitle: fromTitleCol == null
              ? null
              : _nullIfEmpty(_cell(row, fromTitleCol)),
          toTitle:
              toTitleCol == null ? null : _nullIfEmpty(_cell(row, toTitleCol)),
          action:
              actionCol == null ? null : _nullIfEmpty(_cell(row, actionCol)),
        ),
      );
    }

    final toCountByFrom = <String, Set<String>>{};
    final fromCountByTo = <String, Set<String>>{};
    for (final edge in edges) {
      if (edge.fromCode != null && edge.toCode != null) {
        toCountByFrom
            .putIfAbsent(edge.fromCode!, () => <String>{})
            .add(edge.toCode!);
        fromCountByTo
            .putIfAbsent(edge.toCode!, () => <String>{})
            .add(edge.fromCode!);
      }
    }

    final raw = <Map<String, dynamic>>[];
    for (final edge in edges) {
      late final String transition;
      if (edge.fromCode == null) {
        transition = 'newly_introduced';
      } else if (edge.toCode == null) {
        transition = 'deleted';
      } else if ((toCountByFrom[edge.fromCode!]?.length ?? 0) > 1) {
        transition = 'split_into';
      } else if ((fromCountByTo[edge.toCode!]?.length ?? 0) > 1) {
        transition = 'merged_into';
      } else if (edge.fromCode != edge.toCode) {
        transition = 'moved_to';
      } else if (_normalizedTitle(edge.fromTitle) !=
          _normalizedTitle(edge.toTitle)) {
        transition = 'renamed';
      } else {
        transition = 'unchanged';
      }

      raw.add({
        'source_system': sourceSystem,
        'from_version': fromVersion,
        'from_code': edge.fromCode,
        'to_version': toVersion,
        'to_code': edge.toCode,
        'transition_type': transition,
        'notes': edge.action,
        'metadata': {
          if (edge.fromTitle != null) 'from_title': edge.fromTitle,
          if (edge.toTitle != null) 'to_title': edge.toTitle,
          if (edge.action != null) 'source_action': edge.action,
        },
      });
    }

    // Reuse the canonical validator so nullable endpoints and transition names
    // are guaranteed to satisfy the database contract.
    return TaxonomyImporter.parseLineageRecords(raw)
        .map((lineage) => lineage.toJson())
        .toList();
  }

  static int _findHeaderRow(
    List<List<String>> rows,
    bool Function(Map<String, int>) predicate,
  ) {
    final max = rows.length < 30 ? rows.length : 30;
    for (var i = 0; i < max; i++) {
      final headers = _headerMap(rows[i]);
      if (predicate(headers)) return i;
    }
    throw const FormatException('Unable to locate expected header row.');
  }

  static Map<String, int> _headerMap(List<String> row) {
    final map = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      final key = _normalizeHeader(row[i]);
      if (key.isNotEmpty) map.putIfAbsent(key, () => i);
    }
    return map;
  }

  static String _normalizeHeader(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static int _requireHeader(
    Map<String, int> headers,
    List<String> aliases,
    String displayName,
  ) {
    final found = _findHeader(headers, aliases);
    if (found == null) {
      throw FormatException('Required column "$displayName" not found.');
    }
    return found;
  }

  static int? _findHeader(
    Map<String, int> headers,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final normalized = _normalizeHeader(alias);
      if (headers.containsKey(normalized)) return headers[normalized];
    }
    for (final entry in headers.entries) {
      if (aliases.any(
        (alias) => entry.key.contains(_normalizeHeader(alias)),
      )) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _findCodeHeader(
    Map<String, int> headers,
    String system,
    String version,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.length <= 30 &&
          entry.key.contains(system) &&
          entry.key.contains(version) &&
          entry.key.contains('code')) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _findTitleHeader(
    Map<String, int> headers,
    String system,
    String version,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.length <= 30 &&
          entry.key.contains(system) &&
          entry.key.contains(version) &&
          entry.key.contains('title')) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _findVersionedCodeHeader(
    Map<String, int> headers,
    String system,
    String version,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.length <= 30 &&
          entry.key.contains(system) &&
          entry.key.contains(version) &&
          (entry.key.contains('code') || entry.key.endsWith(version))) {
        return entry.value;
      }
    }
    return null;
  }

  static int? _findVersionedTitleHeader(
    Map<String, int> headers,
    String system,
    String version,
  ) {
    for (final entry in headers.entries) {
      if (entry.key.length <= 30 &&
          entry.key.contains(system) &&
          entry.key.contains(version) &&
          entry.key.contains('title')) {
        return entry.value;
      }
    }
    return null;
  }

  static String _cell(List<String> row, int index) =>
      index >= 0 && index < row.length ? row[index] : '';

  static String? _extractCipCode(String value) {
    final cleaned = value
        .trim()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    final match = RegExp(r'\b(\d{2}(?:\.\d{2}(?:\d{2})?)?)\b')
        .firstMatch(cleaned);
    if (match == null) return null;
    final code = match.group(1)!;
    return _cipCodePattern.hasMatch(code) ? code : null;
  }

  static String? _extractSocCode(String value) {
    final match = RegExp(r'\b(\d{2}-\d{4})\b').firstMatch(value.trim());
    if (match == null) return null;
    final code = match.group(1)!;
    return _socCodePattern.hasMatch(code) ? code : null;
  }

  static String? _extractOnetCode(String value) {
    final match =
        RegExp(r'\b(\d{2}-\d{4}\.\d{2})\b').firstMatch(value.trim());
    if (match == null) return null;
    final code = match.group(1)!;
    return _onetCodePattern.hasMatch(code) ? code : null;
  }

  static String _cipLevel(String code) {
    if (RegExp(r'^\d{2}$').hasMatch(code)) return 'series';
    if (RegExp(r'^\d{2}\.\d{2}$').hasMatch(code)) return 'group';
    return 'program';
  }

  static String? _cipParentCode(String code) {
    switch (_cipLevel(code)) {
      case 'series':
        return null;
      case 'group':
        return code.substring(0, 2);
      default:
        return code.substring(0, 5);
    }
  }

  static String _socLevel(String code) {
    if (RegExp(r'^\d{2}-0000$').hasMatch(code)) return 'major_group';
    if (RegExp(r'^\d{2}-\d{2}00$').hasMatch(code)) return 'minor_group';
    if (RegExp(r'^\d{2}-\d{3}0$').hasMatch(code)) {
      return 'broad_occupation';
    }
    return 'detailed_occupation';
  }

  static bool _looksLikeSocHeader(String value) {
    final normalized = _normalizeHeader(value);
    return normalized == 'majorgroup' ||
        normalized == 'minorgroup' ||
        normalized == 'broadgroup' ||
        normalized == 'broadoccupation' ||
        normalized == 'detailedoccupation' ||
        normalized.contains('2018soc');
  }

  static List<String> _splitList(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const [];
    return trimmed
        .split(RegExp(r'[;|\n\r]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _normalizedTitle(String? title) =>
      (title ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _LineageEdge {
  final String? fromCode;
  final String? toCode;
  final String? fromTitle;
  final String? toTitle;
  final String? action;

  const _LineageEdge({
    this.fromCode,
    this.toCode,
    this.fromTitle,
    this.toTitle,
    this.action,
  });
}

/// Canonical metadata for the frozen official releases used by Phase F.
class OfficialTaxonomySources {
  static const cip2020Url =
      'https://nces.ed.gov/ipeds/cipcode/Files/CIPCode2020.csv';
  static const cip2010To2020Url =
      'https://nces.ed.gov/ipeds/cipcode/Files/Crosswalk2010to2020.csv';
  static const cip2020Soc2018Url =
      'https://nces.ed.gov/ipeds/cipcode/Files/CIP2020_SOC2018_Crosswalk.xlsx';
  // BLS is the authoritative publisher. GitHub-hosted runners are denied by
  // bls.gov's edge layer, so machine ingestion uses the official Census-hosted
  // copies for structure/definitions and a pinned Internet Archive capture of
  // the BLS-published historical crosswalk. Provenance retains the BLS origin.
  static const soc2018StructureUrl =
      'https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/soc_structure_2018.xlsx';
  static const soc2018DefinitionsUrl =
      'https://www2.census.gov/programs-surveys/demo/guidance/industry-occupation/soc_2018_definitions.xlsx';
  static const soc2010To2018Url =
      'https://web.archive.org/web/20250101032254if_/https://www.bls.gov/soc/2018/soc_2010_to_2018_crosswalk.xlsx';
  static const onet31OccupationDataUrl =
      'https://www.onetcenter.org/dl_files/database/db_31_0_excel/Occupation%20Data.xlsx';
  static const onet31JobZonesUrl =
      'https://www.onetcenter.org/dl_files/database/db_31_0_excel/Job%20Zones.xlsx';

  static const cipReleaseId = 'a1000000-0000-0000-0000-000000000001';
  static const socReleaseId = 'a1000000-0000-0000-0000-000000000002';
  static const onetReleaseId = 'a1000000-0000-0000-0000-000000000003';

  static const artifacts = <String, String>{
    'CIPCode2020.csv': cip2020Url,
    'Crosswalk2010to2020.csv': cip2010To2020Url,
    'CIP2020_SOC2018_Crosswalk.xlsx': cip2020Soc2018Url,
    'soc_structure_2018.xlsx': soc2018StructureUrl,
    'soc_2018_definitions.xlsx': soc2018DefinitionsUrl,
    'soc_2010_to_2018_crosswalk.xlsx': soc2010To2018Url,
    'Occupation Data.xlsx': onet31OccupationDataUrl,
    'Job Zones.xlsx': onet31JobZonesUrl,
  };

  static String manifestJson() => const JsonEncoder.withIndent('  ').convert({
        'nces_cip': {
          'release_version': '2020',
          'license': 'US_Public_Domain',
          'artifacts': {
            'CIPCode2020.csv': cip2020Url,
            'Crosswalk2010to2020.csv': cip2010To2020Url,
            'CIP2020_SOC2018_Crosswalk.xlsx': cip2020Soc2018Url,
          },
        },
        'bls_soc': {
          'release_version': '2018',
          'license': 'US_Public_Domain',
          'artifacts': {
            'soc_structure_2018.xlsx': soc2018StructureUrl,
            'soc_2018_definitions.xlsx': soc2018DefinitionsUrl,
            'soc_2010_to_2018_crosswalk.xlsx': soc2010To2018Url,
          },
        },
        'onet': {
          'release_version': 'onet_31_0',
          'taxonomy_version': '2019',
          'license': 'CC_BY_4_0',
          'artifacts': {
            'Occupation Data.xlsx': onet31OccupationDataUrl,
            'Job Zones.xlsx': onet31JobZonesUrl,
          },
        },
      });
}
