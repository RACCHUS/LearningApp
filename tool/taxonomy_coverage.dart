import 'dart:convert';
import 'dart:io';

import 'supabase_rest_auth.dart';

/// Read-only, release-scoped catalog coverage report.
///
/// This is NOT the seed smoke test in taxonomy_status.dart. It reports live
/// counts against official structural expectations, without modifying Supabase.
///
/// dart run tool/taxonomy_coverage.dart --registry-only
/// SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --json
/// SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/taxonomy_coverage.dart --strict
///
/// For a FULL database report use a service role only on a secure operator/CI
/// machine. An anon key yields RLS-scoped counts, NOT a complete catalog audit.

const registryPath = 'data/taxonomy/source_registry.json';

Map<String, String> readDotEnv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    var value = trimmed.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    values[trimmed.substring(0, separator).trim()] = value;
  }
  return values;
}

class CoverageClient {
  CoverageClient(this.url, this.key);

  final String url;
  final String key;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  Future<int> count(String table, Map<String, String> filters) async {
    // Tables and keys only come from our checked-in registry, never from user input.
    final uri = Uri.parse('${url.replaceFirst(RegExp(r"/+$"), "")}/rest/v1/$table')
        .replace(queryParameters: {'select': 'id', ...filters});
    final request = await _client.getUrl(uri);
    setSupabaseRestAuth(request, key);
    request.headers.set('Range-Unit', 'items');
    request.headers.set('Range', '0-0');
    request.headers.set('Prefer', 'count=exact');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed counting $table (HTTP ${response.statusCode}): '
        '${body.length > 180 ? body.substring(0, 180) : body}',
        uri: uri,
      );
    }
    final contentRange = response.headers.value('content-range') ?? '';
    final total = RegExp(r'/(\d+)$').firstMatch(contentRange)?.group(1);
    if (total == null) {
      throw FormatException('Missing exact count for $table: $contentRange');
    }
    return int.parse(total);
  }

  void close() => _client.close(force: true);
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'Usage: dart run tool/taxonomy_coverage.dart '
      '[--registry-only] [--json] [--strict]\n'
      'Reads $registryPath. Live queries require SUPABASE_URL and '
      'SUPABASE_SERVICE_ROLE_KEY (legacy service_role JWT or modern sb_secret_) '
      'or SUPABASE_ANON_KEY.\n'
      '--strict exits nonzero for missing pinned-release coverage.',
    );
    return;
  }
  const flags = {'--registry-only', '--json', '--strict'};
  final unknown = args.where((arg) => !flags.contains(arg)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknown.join(', ')}');
    exitCode = 2;
    return;
  }

  final jsonOutput = args.contains('--json');
  final registryOnly = args.contains('--registry-only');
  final strict = args.contains('--strict');
  final registry = Map<String, dynamic>.from(
    jsonDecode(await File(registryPath).readAsString()) as Map,
  );
  final sources = (registry['sources'] as List).cast<Map<String, dynamic>>();
  final checks = (registry['coverage_checks'] as List).cast<Map<String, dynamic>>();
  final targetTypes = (registry['target_types'] as List).cast<String>();

  final sourceIds = <String>{};
  for (final source in sources) {
    final id = source['id'] as String;
    if (!sourceIds.add(id)) throw FormatException('Duplicate source ID: $id');
    if (source['url'] == null || source['cadence'] == null ||
        source['rights'] == null || source['status'] == null) {
      throw FormatException('Incomplete registry entry: $id');
    }
  }
  final checkIds = <String>{};
  for (final check in checks) {
    final id = check['id'] as String;
    if (!checkIds.add(id) || !sourceIds.contains(check['source_id'])) {
      throw FormatException('Duplicate or orphaned coverage check: $id');
    }
  }

  if (registryOnly) {
    final summary = {
      'registry_version': registry['schema_version'],
      'sources': sources.length,
      'release_checks': checks.length,
      'categories': sources.map((e) => e['category']).toSet().toList(),
      'network_access': false,
    };
    if (jsonOutput) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
    } else {
      stdout.writeln('Source registry verified: ${sources.length} sources; '
          '${checks.length} release coverage checks (offline).');
    }
    return;
  }

  final config = readDotEnv();
  String? setting(String key) => Platform.environment[key] ?? config[key];
  final url = setting('SUPABASE_URL');
  final serviceKey = setting('SUPABASE_SERVICE_ROLE_KEY');
  final anonKey = setting('SUPABASE_ANON_KEY');
  final key = serviceKey?.isNotEmpty == true ? serviceKey : anonKey;
  if (serviceKey?.isNotEmpty == true) assertSupabaseAdminKey(serviceKey!);
  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL and an authorized Supabase API key. '
        'Use --registry-only for offline validation.');
    exitCode = 2;
    return;
  }

  final scope = serviceKey != null && serviceKey.isNotEmpty
      ? 'service-role (database-wide when RLS bypass applies)'
      : 'anon (RLS-scoped; NOT full database coverage)';
  final client = CoverageClient(url, key);
  final observations = <Map<String, dynamic>>[];
  final targetCounts = <String, int>{};
  final catalogCounts = <String, int>{};
  var mismatches = 0;

  try {
    for (final check in checks) {
      final expected = check['expected'] as int?;
      final observed = await client.count(
        check['table'] as String,
        Map<String, String>.from(check['filters'] as Map),
      );
      final result = expected == null
          ? 'baseline_only'
          : observed == expected
              ? 'matches_release'
              : 'mismatch';
      if (result == 'mismatch') mismatches++;
      observations.add({
        'check': check['id'],
        'source': check['source_id'],
        'observed': observed,
        'expected': expected,
        'result': result,
      });
    }
    for (final type in targetTypes) {
      targetCounts[type] = await client.count(
        'learning_targets',
        {'target_type': 'eq.$type'},
      );
    }
    for (final entry in <String, (String, Map<String, String>)>{
      'learning_targets_total': ('learning_targets', {}),
      'published_target_versions': ('target_versions', {'status': 'eq.published'}),
      'curriculum_nodes_total': ('curriculum_nodes', {}),
      'courses_total': ('courses', {}),
      'lessons_total': ('lessons', {}),
      'official_published_targets': (
        'learning_targets',
        {'is_official': 'eq.true', 'status': 'eq.published', 'is_public': 'eq.true'},
      ),
      'reviewed_published_targets': (
        'learning_targets',
        {'review_status': 'eq.approved', 'status': 'eq.published', 'is_public': 'eq.true'},
      ),
    }.entries) {
      catalogCounts[entry.key] = await client.count(entry.value.$1, entry.value.$2);
    }
  } catch (error) {
    // An inaccessible table is UNKNOWN, not a count of zero.
    stderr.writeln('Coverage report incomplete: $error');
    exitCode = 2;
    return;
  } finally {
    client.close();
  }

  final report = {
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'scope': scope,
    'registry_version': registry['schema_version'],
    'checks': observations,
    'target_types': targetCounts,
    'catalog': catalogCounts,
    'mismatches': mismatches,
    'limitations': [
      'Counts are database observations, not proof of source rights or current requirements.',
      'CIP/SOC taxonomies do not imply validated licenses, exams or training pathways.',
      'Target and course counts are not completion or verified-relationship measures.',
      if (serviceKey == null) 'Anon counts are restricted by RLS and may undercount.',
    ],
  };
  if (jsonOutput) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } else {
    stdout.writeln('LearningApp Catalog Coverage — $scope');
    for (final row in observations) {
      stdout.writeln('  ${row['check']}: ${row['observed']} '
          '(reference: ${row['expected'] ?? 'baseline TBD'}) — ${row['result']}');
    }
    stdout.writeln('Targets by type: $targetCounts');
    stdout.writeln('Catalog: $catalogCounts');
    stdout.writeln('Release mismatches: $mismatches');
    stdout.writeln('Note: counts do not verify career-to-license relationships.');
  }
  if (strict && mismatches > 0) exitCode = 1;
}
