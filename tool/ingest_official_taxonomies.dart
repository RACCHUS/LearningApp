import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../lib/services/taxonomy/official_taxonomy_sources.dart';
import '../lib/services/taxonomy/taxonomy_importer.dart';

/// Downloads, validates, and optionally ingests the complete authoritative
/// Phase F taxonomy sources.
///
/// No federal source file is committed to the repository. Each run records the
/// exact source URL, SHA-256, file size, and retrieval timestamp in
/// taxonomy_source_artifacts.
///
/// Examples:
///   dart run tool/ingest_official_taxonomies.dart --download
///   dart run tool/ingest_official_taxonomies.dart --validate
///   dart run tool/ingest_official_taxonomies.dart --validate --offline
///   dart run tool/ingest_official_taxonomies.dart --ingest-all
Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.help) {
    _printHelp();
    return;
  }

  if (!options.download && !options.validate && !options.ingest) {
    _printHelp();
    exitCode = 64;
    return;
  }

  final sourceDir = Directory(options.sourceDir);
  await sourceDir.create(recursive: true);

  stdout.writeln('========================================================');
  stdout.writeln(' Official Taxonomy Ingestion — Phase F production data');
  stdout.writeln(' Cache: ${sourceDir.path}');
  stdout.writeln('========================================================');

  final downloader = _ArtifactDownloader(
    sourceDir: sourceDir,
    offline: options.offline,
    refresh: options.refresh,
  );
  final artifacts = await downloader.resolveAll();

  if (options.download && !options.validate && !options.ingest) {
    _printArtifactSummary(artifacts);
    return;
  }

  final bundle = _OfficialBundle.parse(artifacts);
  final report = OfficialTaxonomyParser.validateBundle(
    cipRecords: bundle.cipRecords,
    socRecords: bundle.socRecords,
    onetRecords: bundle.onetRecords,
    cipSocMappings: bundle.cipSocMappings,
    cipLineage: bundle.cipLineage,
    socLineage: bundle.socLineage,
  );

  _printArtifactSummary(artifacts);
  _printValidationReport(report);
  report.throwIfInvalid();

  if (!options.ingest) {
    stdout.writeln('\n✅ Official source bundle is structurally complete.');
    return;
  }

  final env = _loadDotenv();
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
      env['SUPABASE_URL'] ??
      '';
  final serviceRoleKey =
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
          env['SUPABASE_SERVICE_ROLE_KEY'] ??
          '';

  if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty) {
    throw StateError(
      '--ingest-all requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY. '
      'Validation/download modes never require database credentials.',
    );
  }

  final db = _PostgrestAdmin(
    baseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
  );

  try {
    final ingestor = _OfficialTaxonomyIngestor(db);
    await ingestor.ingest(bundle, artifacts);
    await ingestor.verify(bundle);
  } finally {
    db.close();
  }

  stdout.writeln('\n✅ Complete official taxonomy bundle ingested and verified.');
}

void _printHelp() {
  stdout.writeln('Official taxonomy ingestion tool');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln(
    '  dart run tool/ingest_official_taxonomies.dart --download',
  );
  stdout.writeln(
    '  dart run tool/ingest_official_taxonomies.dart --validate',
  );
  stdout.writeln(
    '  dart run tool/ingest_official_taxonomies.dart --ingest-all',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --download        Download/cache all official artifacts.');
  stdout.writeln(
    '  --validate        Parse and verify completeness without DB writes.',
  );
  stdout.writeln(
    '  --ingest-all      Validate first, then upsert all official datasets.',
  );
  stdout.writeln(
    '  --source-dir DIR  Artifact cache (default: build/taxonomy-cache).',
  );
  stdout.writeln(
    '  --refresh         Re-download files even when cached locally.',
  );
  stdout.writeln(
    '  --offline         Never access the network; require cached artifacts.',
  );
  stdout.writeln('  -h, --help        Show this help.');
}

Map<String, String> _loadDotenv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final equals = trimmed.indexOf('=');
    if (equals <= 0) continue;
    var value = trimmed.substring(equals + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[trimmed.substring(0, equals).trim()] = value;
  }
  return values;
}

class _Options {
  final bool help;
  final bool download;
  final bool validate;
  final bool ingest;
  final bool refresh;
  final bool offline;
  final String sourceDir;

  const _Options({
    required this.help,
    required this.download,
    required this.validate,
    required this.ingest,
    required this.refresh,
    required this.offline,
    required this.sourceDir,
  });

  factory _Options.parse(List<String> args) {
    var sourceDir = 'build/taxonomy-cache';
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--source-dir') {
        if (i + 1 >= args.length) {
          throw const FormatException('--source-dir requires a path.');
        }
        sourceDir = args[++i];
      }
    }

    final ingest = args.contains('--ingest-all');
    return _Options(
      help: args.contains('--help') || args.contains('-h'),
      download: args.contains('--download') || ingest,
      validate: args.contains('--validate') || ingest,
      ingest: ingest,
      refresh: args.contains('--refresh'),
      offline: args.contains('--offline'),
      sourceDir: sourceDir,
    );
  }
}

class _Artifact {
  final String name;
  final String sourceUrl;
  final Uint8List bytes;
  final String sha256;
  final File file;

  const _Artifact({
    required this.name,
    required this.sourceUrl,
    required this.bytes,
    required this.sha256,
    required this.file,
  });
}

class _ArtifactDownloader {
  final Directory sourceDir;
  final bool offline;
  final bool refresh;
  final HttpClient _http = HttpClient()
    ..userAgent = 'LearningApp-Taxonomy-Ingestor/1.0';

  _ArtifactDownloader({
    required this.sourceDir,
    required this.offline,
    required this.refresh,
  });

  Future<Map<String, _Artifact>> resolveAll() async {
    final resolved = <String, _Artifact>{};
    for (final entry in OfficialTaxonomySources.artifacts.entries) {
      final file = File('${sourceDir.path}/${entry.key}');
      Uint8List bytes;

      if (file.existsSync() && !refresh) {
        bytes = await file.readAsBytes();
        stdout.writeln('• cache ${entry.key} (${bytes.length} bytes)');
      } else {
        if (offline) {
          throw StateError(
            'Missing cached artifact ${entry.key} while --offline is enabled.',
          );
        }
        stdout.writeln('↓ ${entry.key}');
        bytes = await _download(entry.value);
        await file.writeAsBytes(bytes, flush: true);
      }

      if (bytes.isEmpty) {
        throw StateError('Official artifact ${entry.key} is empty.');
      }

      resolved[entry.key] = _Artifact(
        name: entry.key,
        sourceUrl: entry.value,
        bytes: bytes,
        sha256: TaxonomyImporter.calculateBytesChecksum(bytes),
        file: file,
      );
    }
    _http.close(force: true);
    return resolved;
  }

  Future<Uint8List> _download(String url) async {
    final request = await _http.getUrl(Uri.parse(url));
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/octet-stream,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv,*/*',
    );
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException(
        'Download failed (${response.statusCode}) for $url: '
        '${body.length > 300 ? body.substring(0, 300) : body}',
        uri: Uri.parse(url),
      );
    }

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

class _OfficialBundle {
  final List<Map<String, dynamic>> cipRecords;
  final List<Map<String, dynamic>> socRecords;
  final List<Map<String, dynamic>> onetRecords;
  final List<OfficialCipSocMapping> cipSocMappings;
  final List<Map<String, dynamic>> cipLineage;
  final List<Map<String, dynamic>> socLineage;

  const _OfficialBundle({
    required this.cipRecords,
    required this.socRecords,
    required this.onetRecords,
    required this.cipSocMappings,
    required this.cipLineage,
    required this.socLineage,
  });

  factory _OfficialBundle.parse(Map<String, _Artifact> artifacts) {
    String csv(String name) {
      final artifact = artifacts[name];
      if (artifact == null) throw StateError('Missing artifact $name.');
      return utf8.decode(artifact.bytes, allowMalformed: false);
    }

    List<List<String>> workbook(String name) {
      final artifact = artifacts[name];
      if (artifact == null) throw StateError('Missing artifact $name.');
      return _decodeWorkbookRows(artifact.bytes);
    }

    final cipRecords =
        OfficialTaxonomyParser.parseCip2020Csv(csv('CIPCode2020.csv'));

    final definitions = OfficialTaxonomyParser.parseSoc2018DefinitionsRows(
      workbook('soc_2018_definitions.xlsx'),
    );
    final socRecords = OfficialTaxonomyParser.parseSoc2018Rows(
      workbook('soc_structure_2018.xlsx'),
      definitions: definitions,
    );

    final onetRecords = OfficialTaxonomyParser.parseOnet31Rows(
      occupationRows: workbook('Occupation Data.xlsx'),
      jobZoneRows: workbook('Job Zones.xlsx'),
    );

    final crosswalk = OfficialTaxonomyParser.parseCipSocCrosswalkRows(
      workbook('CIP2020_SOC2018_Crosswalk.xlsx'),
    );

    final cipLineage = OfficialTaxonomyParser.parseCip2010To2020Lineage(
      csv('Crosswalk2010to2020.csv'),
    );
    final socLineage = OfficialTaxonomyParser.parseSoc2010To2018Lineage(
      workbook('soc_2010_to_2018_crosswalk.xlsx'),
    );

    return _OfficialBundle(
      cipRecords: cipRecords,
      socRecords: socRecords,
      onetRecords: onetRecords,
      cipSocMappings: crosswalk,
      cipLineage: cipLineage,
      socLineage: socLineage,
    );
  }
}

List<List<String>> _decodeWorkbookRows(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final rows = <List<String>>[];

  for (final entry in excel.tables.entries) {
    final sheet = entry.value;
    if (sheet.rows.isEmpty) continue;
    for (final row in sheet.rows) {
      final values = row
          .map((cell) => cell?.value?.toString().trim() ?? '')
          .toList(growable: false);
      if (values.any((value) => value.isNotEmpty)) {
        rows.add(values);
      }
    }
    rows.add(const <String>[]);
  }

  return rows;
}

void _printArtifactSummary(Map<String, _Artifact> artifacts) {
  stdout.writeln('\nArtifacts:');
  for (final artifact in artifacts.values) {
    stdout.writeln(
      '  ${artifact.name}: ${artifact.bytes.length} bytes '
      'sha256=${artifact.sha256}',
    );
  }
}

void _printValidationReport(OfficialTaxonomyValidationReport report) {
  stdout.writeln('\nParsed official records:');
  for (final entry in report.counts.entries) {
    stdout.writeln('  ${entry.key}: ${entry.value}');
  }
  for (final warning in report.warnings) {
    stdout.writeln('  ⚠ $warning');
  }
  for (final error in report.errors) {
    stdout.writeln('  ✗ $error');
  }
}

class _OfficialTaxonomyIngestor {
  final _PostgrestAdmin db;

  const _OfficialTaxonomyIngestor(this.db);

  Future<void> ingest(
    _OfficialBundle bundle,
    Map<String, _Artifact> artifacts,
  ) async {
    stdout.writeln('\nWriting source provenance...');
    await _upsertSourceReleases();
    await _upsertArtifacts(artifacts);

    stdout.writeln('Writing ${bundle.cipRecords.length} CIP nodes...');
    final cipNodes = TaxonomyImporter.parseCipNodes(
      rawRecords: bundle.cipRecords,
      sourceReleaseId: OfficialTaxonomySources.cipReleaseId,
      version: '2020',
    );
    await _upsertCipNodes(cipNodes.map((node) => node.toJson()).toList());

    stdout.writeln('Writing ${bundle.socRecords.length} BLS SOC nodes...');
    final socNodes = TaxonomyImporter.parseOccupationNodes(
      rawRecords: bundle.socRecords,
      baseSourceReleaseId: OfficialTaxonomySources.socReleaseId,
    );
    await _upsertSocNodes(socNodes.map((node) => node.toJson()).toList());

    stdout.writeln('Writing ${bundle.onetRecords.length} O*NET nodes...');
    final onetNodes = TaxonomyImporter.parseOccupationNodes(
      rawRecords: bundle.onetRecords,
      onetSourceReleaseId: OfficialTaxonomySources.onetReleaseId,
    );
    await _upsertOnetNodes(onetNodes.map((node) => node.toJson()).toList());

    stdout.writeln(
      'Writing ${bundle.cipSocMappings.length} official CIP-SOC mappings...',
    );
    await _upsertCipSocMappings(bundle.cipSocMappings);

    stdout.writeln(
      'Writing ${bundle.cipLineage.length + bundle.socLineage.length} '
      'taxonomy lineage transitions...',
    );
    await db.insertIgnoringDuplicates(
      'taxonomy_node_lineage',
      [...bundle.cipLineage, ...bundle.socLineage],
    );
  }

  Future<void> _upsertSourceReleases() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.upsert(
      'taxonomy_source_releases',
      [
        {
          'id': OfficialTaxonomySources.cipReleaseId,
          'source_system': 'nces_cip',
          'release_version': '2020',
          'release_date': '2020-01-01',
          'retrieved_at': now,
          'source_url':
              'https://nces.ed.gov/ipeds/cipcode/resources.aspx?y=56',
          'license_name': 'US_Public_Domain',
          'license_url': 'https://www2.ed.gov/notices/copyright/index.html',
          'attribution_text':
              'National Center for Education Statistics, U.S. Department of Education',
          'metadata': {'taxonomy': 'CIP 2020'},
        },
        {
          'id': OfficialTaxonomySources.socReleaseId,
          'source_system': 'bls_soc',
          'release_version': '2018',
          'release_date': '2018-01-01',
          'retrieved_at': now,
          'source_url': 'https://www.bls.gov/soc/2018/home.htm',
          'license_name': 'US_Public_Domain',
          'license_url': 'https://www.bls.gov/bls/linksite.htm',
          'attribution_text':
              'Bureau of Labor Statistics, U.S. Department of Labor',
          'metadata': {'taxonomy': '2018 Standard Occupational Classification'},
        },
        {
          'id': OfficialTaxonomySources.onetReleaseId,
          'source_system': 'onet',
          'release_version': 'onet_31_0',
          'release_date': '2026-08-01',
          'retrieved_at': now,
          'source_url': 'https://www.onetcenter.org/db_releases.html',
          'license_name': 'CC_BY_4_0',
          'license_url': 'https://www.onetcenter.org/license_db.html',
          'attribution_text':
              'This product includes information from the O*NET 31.0 Database by the U.S. Department of Labor, Employment and Training Administration (USDOL/ETA), used under CC BY 4.0. O*NET® is a trademark of USDOL/ETA.',
          'metadata': {
            'taxonomy': 'O*NET-SOC 2019',
            'database_release': '31.0',
          },
        },
      ],
      onConflict: 'id',
    );
  }

  Future<void> _upsertArtifacts(Map<String, _Artifact> artifacts) async {
    final rows = <Map<String, dynamic>>[];
    final retrievedAt = DateTime.now().toUtc().toIso8601String();

    for (final artifact in artifacts.values) {
      rows.add({
        'source_release_id': _releaseIdForArtifact(artifact.name),
        'artifact_name': artifact.name,
        'source_url': artifact.sourceUrl,
        'sha256': artifact.sha256,
        'file_size_bytes': artifact.bytes.length,
        'retrieved_at': retrievedAt,
        'metadata': {
          'ingestor': 'tool/ingest_official_taxonomies.dart',
          'cache_file': artifact.file.path,
        },
      });
    }

    await db.upsert(
      'taxonomy_source_artifacts',
      rows,
      onConflict: 'source_release_id,artifact_name',
    );
  }

  String _releaseIdForArtifact(String name) {
    if (name.startsWith('CIP') || name.startsWith('Crosswalk')) {
      return OfficialTaxonomySources.cipReleaseId;
    }
    if (name.startsWith('soc_')) {
      return OfficialTaxonomySources.socReleaseId;
    }
    return OfficialTaxonomySources.onetReleaseId;
  }

  Future<void> _upsertCipNodes(List<Map<String, dynamic>> nodes) async {
    final firstPass = nodes
        .map((row) => Map<String, dynamic>.from(row)
          ..remove('id')
          ..remove('parent_id'))
        .toList();

    await db.upsert(
      'external_classification_nodes',
      firstPass,
      onConflict: 'system,version,code',
    );

    final ids = await db.codeIdMap(
      'external_classification_nodes',
      filters: {'system': 'cip', 'version': '2020'},
    );

    final secondPass = firstPass.map((row) {
      final sourceParentCode = row['source_parent_code'] as String?;
      return {
        ...row,
        'parent_id':
            sourceParentCode == null ? null : ids[sourceParentCode],
      };
    }).toList();

    final unresolved = secondPass
        .where(
          (row) =>
              row['source_parent_code'] != null && row['parent_id'] == null,
        )
        .map((row) => row['code'])
        .toList();
    if (unresolved.isNotEmpty) {
      throw StateError(
        'CIP parent resolution failed for ${unresolved.length} nodes: '
        '${unresolved.take(10).join(', ')}',
      );
    }

    await db.upsert(
      'external_classification_nodes',
      secondPass,
      onConflict: 'system,version,code',
    );
  }

  Future<void> _upsertSocNodes(List<Map<String, dynamic>> nodes) async {
    final firstPass = nodes
        .map((row) => Map<String, dynamic>.from(row)
          ..remove('id')
          ..remove('parent_id'))
        .toList();

    await db.upsert(
      'occupation_nodes',
      firstPass,
      onConflict: 'taxonomy_system,taxonomy_version,code',
    );

    final ids = await db.codeIdMap(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'bls_soc',
        'taxonomy_version': 'soc_2018',
      },
    );

    final secondPass = firstPass.map((row) {
      final code = row['code'] as String;
      final parentCode = _socParentCode(code, ids);
      return {...row, 'parent_id': parentCode == null ? null : ids[parentCode]};
    }).toList();

    final unresolved = secondPass
        .where(
          (row) =>
              row['level'] != 'major_group' && row['parent_id'] == null,
        )
        .map((row) => row['code'])
        .toList();
    if (unresolved.isNotEmpty) {
      throw StateError(
        'SOC parent resolution failed for ${unresolved.length} nodes: '
        '${unresolved.take(10).join(', ')}',
      );
    }

    await db.upsert(
      'occupation_nodes',
      secondPass,
      onConflict: 'taxonomy_system,taxonomy_version,code',
    );
  }

  String? _socParentCode(String code, Map<String, String> ids) {
    if (RegExp(r'^\d{2}-0000$').hasMatch(code)) return null;
    final major = '${code.substring(0, 2)}-0000';
    if (RegExp(r'^\d{2}-\d{2}00$').hasMatch(code)) return major;

    final minor = '${code.substring(0, 5)}00';
    if (RegExp(r'^\d{2}-\d{3}0$').hasMatch(code)) {
      return ids.containsKey(minor) ? minor : major;
    }

    final broad = '${code.substring(0, 6)}0';
    if (ids.containsKey(broad)) return broad;
    if (ids.containsKey(minor)) return minor;
    return major;
  }

  Future<void> _upsertOnetNodes(List<Map<String, dynamic>> nodes) async {
    final blsIds = await db.codeIdMap(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'bls_soc',
        'taxonomy_version': 'soc_2018',
      },
    );

    final rows = nodes.map((raw) {
      final row = Map<String, dynamic>.from(raw)..remove('id');
      final baseSoc = (row['code'] as String).split('.').first;
      final parentId = blsIds[baseSoc];
      if (parentId == null) {
        throw StateError(
          'O*NET occupation ${row['code']} has no 2018 SOC parent $baseSoc.',
        );
      }
      row['parent_id'] = parentId;
      return row;
    }).toList();

    await db.upsert(
      'occupation_nodes',
      rows,
      onConflict: 'taxonomy_system,taxonomy_version,code',
    );
  }

  Future<void> _upsertCipSocMappings(
    List<OfficialCipSocMapping> mappings,
  ) async {
    final cipIds = await db.codeIdMap(
      'external_classification_nodes',
      filters: {'system': 'cip', 'version': '2020'},
    );
    final socIds = await db.codeIdMap(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'bls_soc',
        'taxonomy_version': 'soc_2018',
      },
    );

    final rows = <Map<String, dynamic>>[];
    for (final mapping in mappings) {
      final classificationId = cipIds[mapping.cipCode];
      final occupationId = socIds[mapping.socCode];
      if (classificationId == null || occupationId == null) {
        throw StateError(
          'Cannot resolve official crosswalk '
          '${mapping.cipCode} -> ${mapping.socCode}.',
        );
      }

      rows.add({
        'classification_node_id': classificationId,
        'occupation_id': occupationId,
        'source_release_id': OfficialTaxonomySources.cipReleaseId,
        'mapping_source': 'nces_bls_crosswalk_2020',
        'mapping_version': '2020',
        'mapping_kind': 'official_qualitative',
        'source_notes': [
          if (mapping.cipTitle != null) mapping.cipTitle,
          if (mapping.socTitle != null) mapping.socTitle,
        ].join(' → '),
      });
    }

    await db.upsert(
      'external_classification_occupation_mappings',
      rows,
      onConflict:
          'classification_node_id,occupation_id,source_release_id',
    );
  }

  Future<void> verify(_OfficialBundle bundle) async {
    stdout.writeln('\nVerifying database counts...');

    final cipCount = await db.countRows(
      'external_classification_nodes',
      filters: {'system': 'cip', 'version': '2020'},
    );
    final socCount = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'bls_soc',
        'taxonomy_version': 'soc_2018',
      },
    );
    final onetCount = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
      },
    );
    final mappingCount = await db.countRows(
      'external_classification_occupation_mappings',
      filters: {
        'mapping_source': 'nces_bls_crosswalk_2020',
        'mapping_version': '2020',
      },
    );

    final expected = {
      'CIP 2020 nodes': bundle.cipRecords.length,
      'SOC 2018 nodes': bundle.socRecords.length,
      'O*NET-SOC 2019 nodes': bundle.onetRecords.length,
      'CIP-SOC mappings': bundle.cipSocMappings.length,
    };
    final actual = {
      'CIP 2020 nodes': cipCount,
      'SOC 2018 nodes': socCount,
      'O*NET-SOC 2019 nodes': onetCount,
      'CIP-SOC mappings': mappingCount,
    };

    for (final entry in expected.entries) {
      final got = actual[entry.key]!;
      stdout.writeln('  ${entry.key}: $got (source ${entry.value})');
      if (got < entry.value) {
        throw StateError(
          '${entry.key} database count $got is below source count '
          '${entry.value}.',
        );
      }
    }

    final orphanCip = await db.countRows(
      'external_classification_nodes',
      filters: {
        'system': 'eq.cip',
        'version': 'eq.2020',
        'parent_id': 'is.null',
        'level_code': 'neq.series',
      },
      rawFilters: true,
    );
    final orphanSoc = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'eq.bls_soc',
        'taxonomy_version': 'eq.soc_2018',
        'parent_id': 'is.null',
        'level': 'neq.major_group',
      },
      rawFilters: true,
    );
    final orphanOnet = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'eq.onet_soc',
        'taxonomy_version': 'eq.2019',
        'parent_id': 'is.null',
      },
      rawFilters: true,
    );

    if (orphanCip + orphanSoc + orphanOnet != 0) {
      throw StateError(
        'Hierarchy verification failed: orphan CIP=$orphanCip, '
        'SOC=$orphanSoc, O*NET=$orphanOnet.',
      );
    }
  }
}

class _PostgrestAdmin {
  final String baseUrl;
  final String serviceRoleKey;
  final HttpClient _http = HttpClient();

  _PostgrestAdmin({
    required this.baseUrl,
    required this.serviceRoleKey,
  });

  void close() => _http.close(force: true);

  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required String onConflict,
  }) async {
    for (final chunk in _chunks(rows, 250)) {
      final uri = Uri.parse('$baseUrl/rest/v1/$table').replace(
        queryParameters: {'on_conflict': onConflict},
      );
      final request = await _http.postUrl(uri);
      _auth(request);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        'Prefer',
        'resolution=merge-duplicates,return=minimal',
      );
      request.add(utf8.encode(jsonEncode(chunk)));
      await _expectSuccess(request, 'upsert $table');
    }
  }

  Future<void> insertIgnoringDuplicates(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    for (final chunk in _chunks(rows, 250)) {
      final request = await _http.postUrl(
        Uri.parse('$baseUrl/rest/v1/$table'),
      );
      _auth(request);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        'Prefer',
        'resolution=ignore-duplicates,return=minimal',
      );
      request.add(utf8.encode(jsonEncode(chunk)));
      await _expectSuccess(request, 'insert $table');
    }
  }

  Future<Map<String, String>> codeIdMap(
    String table, {
    required Map<String, String> filters,
  }) async {
    final rows = await getAll(
      table,
      select: 'id,code',
      filters: filters,
    );
    return {
      for (final row in rows)
        if (row['id'] != null && row['code'] != null)
          row['code'].toString(): row['id'].toString(),
    };
  }

  Future<int> countRows(
    String table, {
    Map<String, String> filters = const {},
    bool rawFilters = false,
  }) async {
    final rows = await getAll(
      table,
      select: 'id',
      filters: filters,
      rawFilters: rawFilters,
    );
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> getAll(
    String table, {
    String select = '*',
    Map<String, String> filters = const {},
    bool rawFilters = false,
  }) async {
    const pageSize = 1000;
    var offset = 0;
    final all = <Map<String, dynamic>>[];

    while (true) {
      final query = <String, String>{
        'select': select,
        'limit': '$pageSize',
        'offset': '$offset',
        for (final entry in filters.entries)
          entry.key: rawFilters ? entry.value : 'eq.${entry.value}',
      };
      final uri = Uri.parse('$baseUrl/rest/v1/$table').replace(
        queryParameters: query,
      );
      final request = await _http.getUrl(uri);
      _auth(request);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'GET $table failed (${response.statusCode}): $body',
          uri: uri,
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw StateError('Unexpected GET $table response.');
      }
      final page = decoded
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList();
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return all;
  }

  void _auth(HttpClientRequest request) {
    request.headers.set('apikey', serviceRoleKey);
    request.headers.set('Authorization', 'Bearer $serviceRoleKey');
  }

  Future<void> _expectSuccess(
    HttpClientRequest request,
    String operation,
  ) async {
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        '$operation failed (${response.statusCode}): $body',
        uri: request.uri,
      );
    }
  }
}

Iterable<List<Map<String, dynamic>>> _chunks(
  List<Map<String, dynamic>> rows,
  int size,
) sync* {
  for (var i = 0; i < rows.length; i += size) {
    final end = (i + size < rows.length) ? i + size : rows.length;
    yield rows.sublist(i, end);
  }
}
