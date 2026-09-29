import 'dart:convert';
import 'dart:io';

/// Canonical Taxonomy Status and Verification CLI
///
/// Standalone pure-Dart CLI that inspects and verifies the Canonical Taxonomy
/// (CIP 2020 fields, BLS SOC occupations, 5-tier parentage, and multi-destination learning targets).
///
/// Usage:
///   dart run tool/taxonomy_status.dart
///
/// Config resolution:
///   .env file -> process environment -> built-in public fallback

const _fallbackUrl = 'https://xzvkdwebtbxlrxagtzlv.supabase.co';
const _fallbackAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6dmtkd2VidGJ4bHJ4YWd0emx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM0NTY4NTMsImV4cCI6MjA2OTAzMjg1M30.PrrRi4aecxwUVSeKgor-la2Vk-Tg6heRPGdUOzfEPIY';

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

class TaxonomyStatusClient {
  final String url;
  final String key;
  final HttpClient _http = HttpClient();

  TaxonomyStatusClient(this.url, this.key);

  Future<int> getCount(String table) async {
    final uri = Uri.parse('$url/rest/v1/$table?select=id');
    final req = await _http.getUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Range-Unit', 'items');
    req.headers.set('Range', '0-0');
    req.headers.set('Prefer', 'count=exact');

    final resp = await req.close();
    final contentRange = resp.headers.value('content-range');
    await resp.drain();

    if (contentRange != null && contentRange.contains('/')) {
      final total = contentRange.split('/').last;
      return int.tryParse(total) ?? 0;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> fetchRows(String table, String select,
      {int limit = 10, String? filter}) async {
    var path = '$url/rest/v1/$table?select=$select&limit=$limit';
    if (filter != null && filter.isNotEmpty) {
      path += '&$filter';
    }
    final uri = Uri.parse(path);
    final req = await _http.getUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');

    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }
}

Future<void> main(List<String> args) async {
  print('====================================================');
  print('🏛️  Canonical Learning Taxonomy Status & Verification');
  print('====================================================');

  final dotenv = _loadDotenv();
  final url = dotenv['SUPABASE_URL'] ??
      Platform.environment['SUPABASE_URL'] ??
      _fallbackUrl;
  final key = dotenv['SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      dotenv['SUPABASE_ANON_KEY'] ??
      Platform.environment['SUPABASE_ANON_KEY'] ??
      _fallbackAnonKey;

  final client = TaxonomyStatusClient(url, key);

  print('📡 Supabase Endpoint: $url');
  print('🔑 Key: ${key.substring(0, 16)}...');
  print('');

  final clusterCount = await client.getCount('catalog_clusters');
  final fieldCount = await client.getCount('fields');
  final extNodeCount = await client.getCount('external_classification_nodes');
  final occCount = await client.getCount('occupation_nodes');
  final crosswalkCount =
      await client.getCount('external_classification_occupation_mappings');
  final targetCount = await client.getCount('learning_targets');

  bool hasErrors = false;

  print('📊 Taxonomy Entity Counts:');
  print('  • Catalog Clusters:                         $clusterCount / 12');
  print('  • Canonical Fields (CIP 48 series + core):  $fieldCount / 48');
  print('  • External Classification Nodes (CIP):      $extNodeCount / 48');
  print('  • Occupation Nodes (BLS SOC + O*NET):       $occCount / 24');
  print('  • CIP-SOC Qualitative Crosswalks:           $crosswalkCount');
  print('  • Multi-Destination Learning Targets:       $targetCount / 17');
  print('');

  if (clusterCount < 12) {
    print('  ❌ Error: Expected at least 12 catalog clusters, found $clusterCount');
    hasErrors = true;
  }
  if (fieldCount < 48) {
    print('  ❌ Error: Expected at least 48 canonical fields, found $fieldCount');
    hasErrors = true;
  }
  if (occCount < 24) {
    print('  ❌ Error: Expected at least 24 occupation nodes, found $occCount');
    hasErrors = true;
  }
  if (targetCount < 17) {
    print('  ❌ Error: Expected at least 17 learning targets, found $targetCount');
    hasErrors = true;
  }

  print('🔍 Verifying Required Target Slugs:');
  const requiredSlugs = [
    'exam-gre',
    'career-software-engineer',
    'career-cybersecurity-analyst',
    'career-data-scientist',
    'career-registered-nurse',
    'cert-comptia-security-plus',
    'cert-comptia-a-plus',
    'cert-aws-solutions-architect',
    'cert-nclex-rn',
    'exam-usmle-step-1',
    'exam-mcat',
    'exam-sat-math',
    'program-bs-computer-science',
    'program-bs-nursing',
    'program-bs-electrical-engineering',
    'program-mba',
  ];

  for (final slug in requiredSlugs) {
    final rows = await client.fetchRows('learning_targets', 'slug,title,target_type',
        limit: 1, filter: 'slug=eq.$slug');
    if (rows.isNotEmpty) {
      final t = rows.first;
      print('  ✓ [${t['target_type']}] ${t['title']} ($slug)');
    } else {
      print('  ❌ Error: Required target slug missing: $slug');
      hasErrors = true;
    }
  }

  print('');
  print('🌳 Verifying 5-Tier SOC Sample Hierarchy & Parentage:');
  const sampleSocCodes = [
    '15-0000', // Major
    '15-1200', // Minor (parent: 15-0000)
    '15-1250', // Broad (parent: 15-1200)
    '15-1252', // Detailed (parent: 15-1250)
    '15-1252.00', // O*NET Extension (parent: 15-1252)
  ];

  final socNodesByCode = <String, Map<String, dynamic>>{};
  for (final code in sampleSocCodes) {
    final rows = await client.fetchRows('occupation_nodes', 'id,code,title,level,parent_id',
        limit: 1, filter: 'code=eq.$code');
    if (rows.isNotEmpty) {
      final o = rows.first;
      socNodesByCode[code] = o;
      print('  ✓ ${o['level'].toString().padRight(19)} ${o['code']} - ${o['title']}');
    } else {
      print('  ❌ Error: Required SOC code missing: $code');
      hasErrors = true;
    }
  }

  // Verify parent_id linkage chain
  const parentPairs = [
    ('15-1200', '15-0000'),
    ('15-1250', '15-1200'),
    ('15-1252', '15-1250'),
    ('15-1252.00', '15-1252'),
  ];

  for (final pair in parentPairs) {
    final childCode = pair.$1;
    final expectedParentCode = pair.$2;
    final child = socNodesByCode[childCode];
    final parent = socNodesByCode[expectedParentCode];

    if (child != null && parent != null) {
      if (child['parent_id'] == parent['id']) {
        print('  🔗 Parent Link OK: $childCode -> $expectedParentCode');
      } else {
        print('  ❌ Error: Broken parent linkage for $childCode. Expected parent_id ${parent['id']} ($expectedParentCode), got ${child['parent_id']}');
        hasErrors = true;
      }
    }
  }

  print('');
  print('🎨 Sample Presentation Clusters:');
  final clusters = await client.fetchRows('catalog_clusters', 'title,emoji', limit: 6);
  for (final c in clusters) {
    print('  ${c['emoji']}  ${c['title']}');
  }

  print('====================================================');
  if (hasErrors) {
    print('❌ Canonical Taxonomy Architecture Verification FAILED with errors.');
    exit(1);
  } else {
    print('✅ Canonical Taxonomy Architecture Status Check Completed.');
    exit(0);
  }
}
