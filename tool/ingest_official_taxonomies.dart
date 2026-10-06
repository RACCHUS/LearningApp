import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../lib/models/taxonomy/external_classification_node.dart';
import '../lib/models/taxonomy/occupation_node.dart';
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
  final String retrievalUrl;
  final Uint8List bytes;
  final String sha256;
  final File file;
  final OfficialTaxonomyArtifactSpec spec;

  const _Artifact({
    required this.name,
    required this.sourceUrl,
    required this.retrievalUrl,
    required this.bytes,
    required this.sha256,
    required this.file,
    required this.spec,
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
    for (final spec in OfficialTaxonomySources.specs.values) {
      final file = File('${sourceDir.path}/${spec.name}');
      Uint8List bytes;

      if (file.existsSync() && !refresh) {
        bytes = await file.readAsBytes();
        stdout.writeln('• cache ${spec.name} (${bytes.length} bytes)');
      } else {
        if (offline) {
          throw StateError(
            'Missing cached artifact ${spec.name} while --offline is enabled.',
          );
        }
        stdout.writeln('↓ ${spec.name} (from ${spec.retrievalUrl})');
        bytes = await _download(spec.retrievalUrl);
        await file.writeAsBytes(bytes, flush: true);
      }

      if (bytes.isEmpty) {
        throw StateError('Official artifact ${spec.name} is empty.');
      }

      final sha256 = TaxonomyImporter.calculateBytesChecksum(bytes);
      if (sha256 != spec.expectedSha256) {
        throw StateError(
          'Cryptographic checksum verification failed for ${spec.name}:\n'
          '  expected SHA-256: ${spec.expectedSha256}\n'
          '  actual SHA-256:   $sha256\n'
          'Refusing to ingest mutated or unpinned official source.',
        );
      }
      if (bytes.length != spec.expectedSizeBytes) {
        throw StateError(
          'File size mismatch for ${spec.name}:\n'
          '  expected size: ${spec.expectedSizeBytes} bytes\n'
          '  actual size:   ${bytes.length} bytes\n',
        );
      }

      resolved[spec.name] = _Artifact(
        name: spec.name,
        sourceUrl: spec.publisherUrl,
        retrievalUrl: spec.retrievalUrl,
        bytes: bytes,
        sha256: sha256,
        file: file,
        spec: spec,
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

    List<List<String>> workbook(String name, {String? sheet}) {
      final artifact = artifacts[name];
      if (artifact == null) throw StateError('Missing artifact $name.');
      return _decodeWorkbookRows(artifact.bytes, targetSheet: sheet);
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
      workbook('CIP2020_SOC2018_Crosswalk.xlsx', sheet: 'CIP-SOC'),
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

List<List<String>> _decodeWorkbookRows(
  Uint8List bytes, {
  String? targetSheet,
}) {
  final excel = Excel.decodeBytes(bytes);
  final rows = <List<String>>[];

  for (final entry in excel.tables.entries) {
    if (targetSheet != null &&
        entry.key.trim().toLowerCase() != targetSheet.trim().toLowerCase()) {
      continue;
    }
    final sheetNameLower = entry.key.trim().toLowerCase();
    if (targetSheet == null &&
        (sheetNameLower.contains('guide') || sheetNameLower.contains('readme'))) {
      continue;
    }
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

String _generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _OfficialTaxonomyIngestor {
  final _PostgrestAdmin db;

  const _OfficialTaxonomyIngestor(this.db);

  Future<void> ingest(
    _OfficialBundle bundle,
    Map<String, _Artifact> artifacts,
  ) async {
    final runId = _generateUuidV4();
    stdout.writeln('\n[Atomic Staging] Starting import run $runId...');

    stdout.writeln('Staging ${artifacts.length} provenance artifacts...');
    await _stageArtifacts(runId, artifacts);

    stdout.writeln('Staging ${bundle.cipRecords.length} CIP nodes...');
    final cipNodes = TaxonomyImporter.parseCipNodes(
      rawRecords: bundle.cipRecords,
      sourceReleaseId: OfficialTaxonomySources.cipReleaseId,
      version: '2020',
    );
    await _stageCipNodes(runId, cipNodes);

    stdout.writeln('Staging ${bundle.socRecords.length} BLS SOC nodes...');
    final socNodes = TaxonomyImporter.parseOccupationNodes(
      rawRecords: bundle.socRecords,
      baseSourceReleaseId: OfficialTaxonomySources.socReleaseId,
    );
    await _stageSocNodes(runId, socNodes);

    stdout.writeln('Staging ${bundle.onetRecords.length} O*NET nodes...');
    final onetNodes = TaxonomyImporter.parseOccupationNodes(
      rawRecords: bundle.onetRecords,
      onetSourceReleaseId: OfficialTaxonomySources.onetReleaseId,
    );
    await _stageOnetNodes(runId, onetNodes);

    stdout.writeln(
      'Staging ${bundle.cipSocMappings.length} official CIP-SOC mappings...',
    );
    await _stageCipSocMappings(runId, bundle.cipSocMappings);

    stdout.writeln(
      'Staging ${bundle.cipLineage.length + bundle.socLineage.length} '
      'taxonomy lineage transitions...',
    );
    await _stageLineage(
      runId,
      [...bundle.cipLineage, ...bundle.socLineage],
    );

    stdout.writeln(
      '\n[Atomic Finalize] Executing transactional finalize RPC on Supabase...',
    );
    final finalizeResult = await db.rpc(
      'finalize_official_taxonomy_import',
      {'p_import_run_id': runId},
    );
    stdout.writeln('Finalize RPC completed: $finalizeResult');
  }

  Future<void> _stageArtifacts(
    String runId,
    Map<String, _Artifact> artifacts,
  ) async {
    final rows = artifacts.values.map((artifact) {
      final String sourceSystem;
      final String releaseVersion;
      if (artifact.name.startsWith('CIP') ||
          artifact.name.startsWith('Crosswalk')) {
        sourceSystem = 'nces_cip';
        releaseVersion = '2020';
      } else if (artifact.name.startsWith('soc_')) {
        sourceSystem = 'bls_soc';
        releaseVersion = '2018';
      } else {
        sourceSystem = 'onet';
        releaseVersion = 'onet_31_0';
      }

      return {
        'import_run_id': runId,
        'source_system': sourceSystem,
        'release_version': releaseVersion,
        'artifact_name': artifact.name,
        'source_url': artifact.sourceUrl,
        'retrieval_url': artifact.retrievalUrl,
        'sha256': artifact.sha256,
        'file_size_bytes': artifact.bytes.length,
        'metadata': {
          'ingestor': 'tool/ingest_official_taxonomies.dart',
          'cache_file': artifact.file.path,
        },
      };
    }).toList();

    await db.insert('stg_taxonomy_source_artifacts', rows);
  }

  Future<void> _stageCipNodes(
    String runId,
    List<ExternalClassificationNode> nodes,
  ) async {
    final rows = nodes.map((node) => {
      'import_run_id': runId,
      'system': node.system,
      'version': node.version,
      'code': node.code,
      'source_parent_code': node.sourceParentCode,
      'level_code': node.levelCode,
      'level_depth': node.levelDepth,
      'title': node.title,
      'definition': node.definition,
      'cross_references': node.crossReferences,
      'illustrative_examples': node.illustrativeExamples,
      'metadata': node.metadata,
    }).toList();

    await db.insert('stg_external_classification_nodes', rows);
  }

  Future<void> _stageSocNodes(
    String runId,
    List<OccupationNode> nodes,
  ) async {
    final rows = nodes.map((node) => {
      'import_run_id': runId,
      'code': node.code,
      'title': node.title,
      'description': node.description,
      'level': node.level,
      'taxonomy_system': node.taxonomySystem,
      'taxonomy_version': node.taxonomyVersion,
      'data_release_version': node.dataReleaseVersion,
      'job_zone': node.jobZone,
      'metadata': node.metadata,
    }).toList();

    await db.insert('stg_occupation_nodes', rows);
  }

  Future<void> _stageOnetNodes(
    String runId,
    List<OccupationNode> nodes,
  ) async {
    final rows = nodes.map((node) => {
      'import_run_id': runId,
      'code': node.code,
      'title': node.title,
      'description': node.description,
      'level': node.level,
      'taxonomy_system': node.taxonomySystem,
      'taxonomy_version': node.taxonomyVersion,
      'data_release_version': node.dataReleaseVersion,
      'job_zone': node.jobZone,
      'metadata': node.metadata,
    }).toList();

    await db.insert('stg_occupation_nodes', rows);
  }

  Future<void> _stageCipSocMappings(
    String runId,
    List<OfficialCipSocMapping> mappings,
  ) async {
    final rows = mappings.map((mapping) => {
      'import_run_id': runId,
      'classification_system': 'cip',
      'classification_version': '2020',
      'classification_code': mapping.cipCode,
      'occupation_system': 'bls_soc',
      'occupation_version': 'soc_2018',
      'occupation_code': mapping.socCode,
      'mapping_source': 'nces_bls_crosswalk_2020',
      'mapping_version': '2020',
      'mapping_kind': 'official_qualitative',
      'source_notes': [
        if (mapping.cipTitle != null) mapping.cipTitle,
        if (mapping.socTitle != null) mapping.socTitle,
      ].join(' → '),
    }).toList();

    await db.insert(
      'stg_external_classification_occupation_mappings',
      rows,
    );
  }

  Future<void> _stageLineage(
    String runId,
    List<Map<String, dynamic>> records,
  ) async {
    final rows = records.map((record) => {
      'import_run_id': runId,
      'source_system': record['source_system'],
      'from_version': record['from_version'],
      'from_code': record['from_code'],
      'to_version': record['to_version'],
      'to_code': record['to_code'],
      'transition_type': record['transition_type'],
      'notes': record['notes'],
      'metadata': record['metadata'] ?? {},
    }).toList();

    await db.insert('stg_taxonomy_node_lineage', rows);
  }

  Future<void> verify(_OfficialBundle bundle) async {
    stdout.writeln('\nVerifying database counts...');

    final cipCount = await db.countRows(
      'external_classification_nodes',
      filters: {
        'system': 'cip',
        'version': '2020',
        'is_active': 'true',
      },
    );
    final socCount = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'bls_soc',
        'taxonomy_version': 'soc_2018',
        'is_active': 'true',
      },
    );
    final onetCount = await db.countRows(
      'occupation_nodes',
      filters: {
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
        'is_active': 'true',
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
      'CIP 2020 nodes (active)': bundle.cipRecords.length,
      'SOC 2018 nodes (active)': bundle.socRecords.length,
      'O*NET-SOC 2019 nodes (active)': bundle.onetRecords.length,
      'CIP-SOC mappings': bundle.cipSocMappings.length,
    };
    final actual = {
      'CIP 2020 nodes (active)': cipCount,
      'SOC 2018 nodes (active)': socCount,
      'O*NET-SOC 2019 nodes (active)': onetCount,
      'CIP-SOC mappings': mappingCount,
    };

    for (final entry in expected.entries) {
      final got = actual[entry.key]!;
      stdout.writeln('  ${entry.key}: $got (source ${entry.value})');
      if (got != entry.value) {
        throw StateError(
          '${entry.key} database count $got does not match exact source count '
          '${entry.value}.',
        );
      }
    }

    final orphanCip = await db.countRows(
      'external_classification_nodes',
      filters: {
        'system': 'eq.cip',
        'version': 'eq.2020',
        'is_active': 'eq.true',
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
        'is_active': 'eq.true',
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
        'is_active': 'eq.true',
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

  Future<void> insert(
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
        'return=minimal',
      );
      request.add(utf8.encode(jsonEncode(chunk)));
      await _expectSuccess(request, 'insert $table');
    }
  }

  Future<Map<String, dynamic>> rpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/$functionName');
    final request = await _http.postUrl(uri);
    _auth(request);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.add(utf8.encode(jsonEncode(params)));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'RPC $functionName failed (${response.statusCode}): $body',
        uri: uri,
      );
    }
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'result': decoded};
  }

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
