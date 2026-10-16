import 'dart:convert';
import 'dart:io';

Map<String, String> loadDotenv() {
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

Future<void> main() async {
  final env = loadDotenv();
  final url = env['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    print('ERROR: Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    exit(1);
  }

  print('================================================================');
  print('Catalog License Pathway Versions Verification (Anonymous REST)');
  print('Target: $url');
  print('================================================================\n');

  final client = HttpClient();
  final uri = Uri.parse(
      '$url/rest/v1/catalog_license_pathway_versions?select=source_namespace,source_key,revision,title,route_kind,coverage,review_status,publication_status&order=source_namespace,source_key');

  final req = await client.getUrl(uri);
  req.headers.set('apikey', anonKey);
  req.headers.set('Authorization', 'Bearer $anonKey');
  req.headers.set('Accept', 'application/json');

  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();

  if (resp.statusCode != 200) {
    print('FAILED: HTTP ${resp.statusCode}: $body');
    exit(1);
  }

  final List<dynamic> rows = jsonDecode(body);
  print('Retrieved ${rows.length} published pathway(s) via anonymous RLS:\n');

  final expected = {
    'fl_bon:registered-nurse',
    'fl_bon:licensed-practical-nurse',
    'fl_dfs:general-lines-2-20',
    'fl_dfs:life-health-2-15',
    'dbpr_fl:certified-general-contractor',
    'dbpr_fl:certified-building-contractor',
  };

  final found = <String>{};

  for (final r in rows) {
    final ns = r['source_namespace'] as String;
    final key = r['source_key'] as String;
    final rev = r['revision'];
    final title = r['title'] as String;
    final status = r['publication_status'] as String;
    final review = r['review_status'] as String;
    final coverage = r['coverage'] as String;

    final id = '$ns:$key';
    found.add(id);

    print('• [$ns] $key (rev $rev)');
    print('  Title: "$title"');
    print('  Status: $status | Review: $review | Coverage: $coverage\n');
  }

  final missing = expected.difference(found);
  if (missing.isEmpty && rows.length == 6) {
    print('PASSED: All 6 target Florida pathways are published and publicly visible under RLS!');
  } else {
    print('STATUS: ${rows.length} of 6 target pathways published.');
    if (missing.isNotEmpty) {
      print('Awaiting promotion for: ${missing.toList()}');
    }
  }
}
