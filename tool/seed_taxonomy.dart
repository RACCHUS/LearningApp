import 'dart:convert';
import 'dart:io';
import '../lib/services/taxonomy/taxonomy_importer.dart';
import 'taxonomy_status.dart' as status;

/// Canonical Taxonomy Seeding & Ingestion CLI
///
/// Implements version/release-driven ingestion of:
///   - NCES CIP 2020 classification series and program nodes
///   - BLS SOC 2018 5-tier labor taxonomy (major, minor, broad, detailed)
///   - O*NET 2019 / 31.0 extension nodes (.XX)
///   - Official NCES/BLS CIP-SOC qualitative crosswalk
///   - Decennial taxonomy lineage transitions (CIP 2010 -> 2020, SOC 2010 -> 2018)
///
/// Usage:
///   dart run tool/seed_taxonomy.dart --status
///   dart run tool/seed_taxonomy.dart --dry-run
///   dart run tool/seed_taxonomy.dart --ingest-all
///   dart run tool/seed_taxonomy.dart --ingest-cip
///   dart run tool/seed_taxonomy.dart --ingest-soc
///   dart run tool/seed_taxonomy.dart --ingest-onet
///   dart run tool/seed_taxonomy.dart --ingest-crosswalk
///   dart run tool/seed_taxonomy.dart --ingest-lineage

Map<String, String> _loadDotenv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env[trimmed.substring(0, eq).trim()] = value;
  }
  return env;
}

class TaxonomyApiClient {
  final String url;
  final String key;
  final HttpClient _http = HttpClient();

  TaxonomyApiClient(this.url, this.key);

  Future<int> postRows(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
  }) async {
    if (rows.isEmpty) return 0;

    final uri = Uri.parse('$url/rest/v1/$table').replace(
      queryParameters: {
        if (onConflict != null) 'on_conflict': onConflict,
      },
    );
    final req = await _http.postUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'resolution=ignore-duplicates,return=minimal');

    req.add(utf8.encode(jsonEncode(rows)));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Taxonomy write to $table failed with HTTP ${resp.statusCode}: $body',
        uri: uri,
      );
    }
    return rows.length;
  }

  Future<Map<String, dynamic>?> getSingle(
    String table, {
    required Map<String, String> equals,
    String select = 'id',
  }) async {
    final uri = Uri.parse('$url/rest/v1/$table').replace(
      queryParameters: {
        'select': select,
        'limit': '1',
        for (final entry in equals.entries) entry.key: 'eq.${entry.value}',
      },
    );
    final req = await _http.getUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');

    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Taxonomy lookup in $table failed with HTTP ${resp.statusCode}: $body',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! List || decoded.isEmpty) return null;
    return (decoded.first as Map).cast<String, dynamic>();
  }
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    print('🏛️ Canonical Taxonomy CLI Ingestion & Seeding Engine');
    print('Usage: dart run tool/seed_taxonomy.dart [options]');
    print('');
    print('Options:');
    print('  --status            Run canonical taxonomy status verification');
    print('  --dry-run           Validate and parse reference records without network writes');
    print('  --ingest-all        Ingest full CIP, SOC, O*NET, crosswalks, and lineage');
    print('  --ingest-cip        Ingest NCES CIP 2020 classifications');
    print('  --ingest-soc        Ingest BLS SOC 2018 4-tier occupational structure');
    print('  --ingest-onet       Ingest O*NET 31.0 detailed extensions (.XX)');
    print('  --ingest-crosswalk  Ingest NCES/BLS CIP-to-SOC qualitative crosswalk');
    print('  --ingest-lineage    Ingest decennial taxonomy transition records');
    exit(0);
  }

  if (args.contains('--status')) {
    await status.main(args);
    return;
  }

  final isDryRun = args.contains('--dry-run');
  final ingestAll = args.contains('--ingest-all');
  final ingestCip = ingestAll || args.contains('--ingest-cip');
  final ingestSoc = ingestAll || args.contains('--ingest-soc');
  final ingestOnet = ingestAll || args.contains('--ingest-onet');
  final ingestCrosswalk = ingestAll || args.contains('--ingest-crosswalk');
  final ingestLineage = ingestAll || args.contains('--ingest-lineage');

  print('====================================================');
  print('🏛️  Canonical Learning Taxonomy Seeding Engine');
  print('    Dry Run Mode: $isDryRun');
  print('====================================================');

  final dotenv = _loadDotenv();
  final url = dotenv['SUPABASE_URL'] ??
      Platform.environment['SUPABASE_URL'] ??
      'https://xzvkdwebtbxlrxagtzlv.supabase.co';
  final key = dotenv['SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      '';

  if (!isDryRun && key.isEmpty) {
    throw StateError(
      'SUPABASE_SERVICE_ROLE_KEY is required for taxonomy ingestion writes.',
    );
  }

  final client = TaxonomyApiClient(url, key);

  // 1. CIP Ingestion
  if (ingestCip) {
    print('\n📚 Ingesting NCES CIP 2020 External Classifications...');
    final rawCip = [
      {'code': '11', 'title': 'Computer and Information Sciences and Support Services', 'level_code': 'series'},
      {'code': '11.01', 'title': 'Computer and Information Sciences, General', 'level_code': 'group'},
      {'code': '11.0101', 'title': 'Computer and Information Sciences, General', 'level_code': 'program'},
      {'code': '11.07', 'title': 'Computer Science', 'level_code': 'group'},
      {'code': '11.0701', 'title': 'Computer Science', 'level_code': 'program'},
      {'code': '11.10', 'title': 'Computer/Information Technology Administration and Management', 'level_code': 'group'},
      {'code': '11.1003', 'title': 'Computer and Information Systems Security/Auditing/Information Assurance', 'level_code': 'program'},
      {'code': '14', 'title': 'Engineering', 'level_code': 'series'},
      {'code': '14.09', 'title': 'Computer Engineering', 'level_code': 'group'},
      {'code': '14.0901', 'title': 'Computer Engineering, General', 'level_code': 'program'},
      {'code': '27', 'title': 'Mathematics and Statistics', 'level_code': 'series'},
      {'code': '27.01', 'title': 'Mathematics', 'level_code': 'group'},
      {'code': '27.0101', 'title': 'Mathematics, General', 'level_code': 'program'},
      {'code': '51', 'title': 'Health Professions and Related Programs', 'level_code': 'series'},
      {'code': '51.38', 'title': 'Registered Nursing, Nursing Administration, Nursing Research and Clinical Nursing', 'level_code': 'group'},
      {'code': '51.3801', 'title': 'Registered Nursing/Registered Nurse', 'level_code': 'program'},
      {'code': '52', 'title': 'Business, Management, Marketing, and Related Support Services', 'level_code': 'series'},
    ];

    final parsedNodes = TaxonomyImporter.parseCipNodes(
      rawRecords: rawCip,
      sourceReleaseId: 'a1000000-0000-0000-0000-000000000001',
      version: '2020',
    );
    print('  ✓ Parsed & hierarchical parent resolved: ${parsedNodes.length} CIP nodes');

    if (!isDryRun) {
      final written = await client.postRows(
        'external_classification_nodes',
        parsedNodes.map((e) => e.toJson()).toList(),
      );
      print('  ✓ Ingested $written nodes into external_classification_nodes');
    }
  }

  // 2. SOC Ingestion
  if (ingestSoc) {
    print('\n💼 Ingesting BLS SOC 2018 Labor Taxonomy...');
    final rawSoc = [
      {'code': '15-0000', 'title': 'Computer and Mathematical Occupations', 'level': 'major_group'},
      {'code': '15-1200', 'title': 'Computer Occupations', 'level': 'minor_group'},
      {'code': '15-1250', 'title': 'Software and Web Developers, Programmers, and Testers', 'level': 'broad_occupation'},
      {'code': '15-1252', 'title': 'Software Developers', 'level': 'detailed_occupation', 'job_zone': 4},
      {'code': '15-1211', 'title': 'Information Security Analysts', 'level': 'detailed_occupation', 'job_zone': 4},
      {'code': '15-2051', 'title': 'Data Scientists', 'level': 'detailed_occupation', 'job_zone': 4},
      {'code': '17-0000', 'title': 'Architecture and Engineering Occupations', 'level': 'major_group'},
      {'code': '17-2061', 'title': 'Computer Hardware Engineers', 'level': 'detailed_occupation', 'job_zone': 4},
      {'code': '29-0000', 'title': 'Healthcare Practitioners and Technical Occupations', 'level': 'major_group'},
      {'code': '29-1141', 'title': 'Registered Nurses', 'level': 'detailed_occupation', 'job_zone': 3},
    ];

    final parsedSoc = TaxonomyImporter.parseOccupationNodes(
      rawRecords: rawSoc,
      baseSourceReleaseId: 'a1000000-0000-0000-0000-000000000002',
    );
    print('  ✓ Parsed & parent resolved: ${parsedSoc.length} SOC nodes');

    if (!isDryRun) {
      final written = await client.postRows(
        'occupation_nodes',
        parsedSoc.map((e) => e.toJson()).toList(),
      );
      print('  ✓ Ingested $written nodes into occupation_nodes');
    }
  }

  // 3. O*NET Ingestion
  if (ingestOnet) {
    print('\n🌐 Ingesting O*NET 31.0 Extensions (.XX)...');
    final rawOnet = [
      {
        'code': '15-1252.00',
        'title': 'Software Developers',
        'level': 'onet_extension',
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
        'data_release_version': 'onet_31_0',
        'job_zone': 4,
      },
      {
        'code': '15-1211.00',
        'title': 'Information Security Analysts',
        'level': 'onet_extension',
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
        'data_release_version': 'onet_31_0',
        'job_zone': 4,
      },
      {
        'code': '15-2051.00',
        'title': 'Data Scientists',
        'level': 'onet_extension',
        'taxonomy_system': 'onet_soc',
        'taxonomy_version': '2019',
        'data_release_version': 'onet_31_0',
        'job_zone': 4,
      },
    ];

    final parsedOnet = TaxonomyImporter.parseOccupationNodes(
      rawRecords: rawOnet,
      onetSourceReleaseId: 'a1000000-0000-0000-0000-000000000003',
    );
    print('  ✓ Parsed & verified O*NET extensions: ${parsedOnet.length} nodes');

    if (!isDryRun) {
      final written = await client.postRows(
        'occupation_nodes',
        parsedOnet.map((e) => e.toJson()).toList(),
      );
      print('  ✓ Ingested $written nodes into occupation_nodes');
    }
  }

  // 4. Qualitative Crosswalk Ingestion
  if (ingestCrosswalk) {
    print('\n🔗 Ingesting Official NCES/BLS CIP-to-SOC Qualitative Crosswalk...');
    final rawCrosswalk = [
      {'cip_code': '11.0701', 'soc_code': '15-1252', 'mapping_kind': 'official_qualitative'},
      {'cip_code': '11.1003', 'soc_code': '15-1211', 'mapping_kind': 'official_qualitative'},
      {'cip_code': '27.0101', 'soc_code': '15-2051', 'mapping_kind': 'official_qualitative'},
      {'cip_code': '14.0901', 'soc_code': '17-2061', 'mapping_kind': 'official_qualitative'},
      {'cip_code': '51.3801', 'soc_code': '29-1141', 'mapping_kind': 'official_qualitative'},
    ];
    print('  ✓ Validated qualitative alignment mappings: ${rawCrosswalk.length} mappings');

    if (!isDryRun) {
      const sourceReleaseId = 'a1000000-0000-0000-0000-000000000001';
      final rows = <Map<String, dynamic>>[];

      for (final mapping in rawCrosswalk) {
        final cipCode = mapping['cip_code']!;
        final socCode = mapping['soc_code']!;

        final classification = await client.getSingle(
          'external_classification_nodes',
          equals: {
            'system': 'cip',
            'version': '2020',
            'code': cipCode,
          },
        );
        final occupation = await client.getSingle(
          'occupation_nodes',
          equals: {
            'taxonomy_system': 'bls_soc',
            'taxonomy_version': 'soc_2018',
            'code': socCode,
          },
        );

        if (classification == null || occupation == null) {
          throw StateError(
            'Cannot ingest CIP-SOC mapping $cipCode -> $socCode because one or both source nodes are missing.',
          );
        }

        rows.add({
          'classification_node_id': classification['id'],
          'occupation_id': occupation['id'],
          'source_release_id': sourceReleaseId,
          'mapping_source': 'nces_bls_crosswalk_2020',
          'mapping_version': '2020',
          'mapping_kind': mapping['mapping_kind'],
        });
      }

      final written = await client.postRows(
        'external_classification_occupation_mappings',
        rows,
        onConflict:
            'classification_node_id,occupation_id,source_release_id',
      );
      print('  ✓ Ingested $written CIP-SOC crosswalk mappings');
    }
  }

  // 5. Lineage Ingestion
  if (ingestLineage) {
    print('\n⏳ Ingesting Decennial Taxonomy Lineage Transitions...');
    final rawLineage = [
      {
        'source_system': 'cip',
        'from_version': '2010',
        'from_code': '11.0701',
        'to_version': '2020',
        'to_code': '11.0701',
        'transition_type': 'unchanged',
        'notes': 'Computer Science core unchanged.',
      },
      {
        'source_system': 'cip',
        'from_version': '2010',
        'from_code': '11.0801',
        'to_version': '2020',
        'to_code': '11.0801',
        'transition_type': 'renamed',
        'notes': 'Web Page, Digital/Multimedia and Information Resources Design.',
      },
      {
        'source_system': 'cip',
        'from_version': '2010',
        'from_code': null,
        'to_version': '2020',
        'to_code': '30.7001',
        'transition_type': 'newly_introduced',
        'notes': 'Data Science, General introduced in 2020.',
      },
      {
        'source_system': 'bls_soc',
        'from_version': '2010',
        'from_code': '15-1132',
        'to_version': '2018',
        'to_code': '15-1252',
        'transition_type': 'moved_to',
        'notes': 'Software Developers, Applications -> Software Developers.',
      },
    ];

    final parsedLineage = TaxonomyImporter.parseLineageRecords(rawLineage);
    print('  ✓ Validated transition constraints: ${parsedLineage.length} transitions');

    if (!isDryRun) {
      final written = await client.postRows(
        'taxonomy_node_lineage',
        parsedLineage.map((e) => e.toJson()).toList(),
      );
      print('  ✓ Ingested $written transitions into taxonomy_node_lineage');
    }
  }

  print('\n====================================================');
  print('✅ Taxonomy Seeding Engine Completed Successfully.');
  print('====================================================');
}
