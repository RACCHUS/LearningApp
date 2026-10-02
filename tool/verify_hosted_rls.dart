import 'dart:convert';
import 'dart:io';

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

class HostedRlsVerifier {
  final String url;
  final String anonKey;
  final HttpClient _http = HttpClient();

  HostedRlsVerifier(this.url, this.anonKey);

  Future<Map<String, dynamic>> restGet(String path, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.getUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Accept', 'application/json');

    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    return {
      'statusCode': resp.statusCode,
      'body': body.isNotEmpty ? jsonDecode(body) : null,
      'headers': resp.headers,
    };
  }

  Future<Map<String, dynamic>> restPost(String path, Map<String, dynamic> data, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.postUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'return=representation');

    req.write(jsonEncode(data));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    dynamic decoded;
    try {
      decoded = body.isNotEmpty ? jsonDecode(body) : null;
    } catch (_) {
      decoded = body;
    }
    return {
      'statusCode': resp.statusCode,
      'body': decoded,
    };
  }

  Future<Map<String, dynamic>> restPatch(String path, Map<String, dynamic> data, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.patchUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'return=representation');

    req.write(jsonEncode(data));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    dynamic decoded;
    try {
      decoded = body.isNotEmpty ? jsonDecode(body) : null;
    } catch (_) {
      decoded = body;
    }
    return {
      'statusCode': resp.statusCode,
      'body': decoded,
    };
  }
}

Future<void> main() async {
  print('====================================================');
  print('🛡️  Hosted Supabase RLS & Visibility Verification');
  print('====================================================');

  final env = _loadDotenv();
  final url = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  final key = env['SUPABASE_ANON_KEY'] ?? Platform.environment['SUPABASE_ANON_KEY'];

  if (url == null || key == null) {
    print('❌ SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env');
    exit(1);
  }

  print('📡 Target: $url');
  final client = HostedRlsVerifier(url, key);

  int passed = 0;
  int failed = 0;

  void expect(bool condition, String message) {
    if (condition) {
      print('  ✓ $message');
      passed++;
    } else {
      print('  ❌ FAILED: $message');
      failed++;
    }
  }

  // 1. Verify lessons visibility column and public read access
  print('\n1. Verifying lessons table and visibility semantics:');
  final publicLessonsRes = await client.restGet('lessons?select=id,title,visibility&visibility=eq.public&limit=5');
  expect(publicLessonsRes['statusCode'] == 200, 'Public lessons query returns 200 OK');
  final publicLessons = publicLessonsRes['body'] as List? ?? [];
  expect(publicLessons.isNotEmpty, 'Public lessons exist in catalog (found ${publicLessons.length})');
  if (publicLessons.isNotEmpty) {
    expect(publicLessons.first['visibility'] == 'public', 'Lesson visibility is explicitly "public"');
  }

  // 2. Verify anonymous client cannot see private lessons
  print('\n2. Verifying private lesson isolation from unauthenticated users:');
  final privateLessonsRes = await client.restGet('lessons?select=id,title,visibility&visibility=eq.private&limit=5');
  expect(privateLessonsRes['statusCode'] == 200, 'Private lessons query returns 200 OK');
  final privateLessons = privateLessonsRes['body'] as List? ?? [];
  expect(privateLessons.isEmpty, 'Anonymous client receives 0 private lessons (found ${privateLessons.length})');

  // 3. Verify user_curriculum_resources table exists and blocks anon access
  print('\n3. Verifying user_curriculum_resources personal-overlay table:');
  final overlayGetRes = await client.restGet('user_curriculum_resources?select=id&limit=5');
  // Anon should be forbidden (403) or return empty list (200 with 0 items)
  final overlayOk = (overlayGetRes['statusCode'] == 200 && (overlayGetRes['body'] as List).isEmpty) ||
      overlayGetRes['statusCode'] == 403 ||
      overlayGetRes['statusCode'] == 401;
  expect(overlayOk, 'user_curriculum_resources exists and denies/isolates anon read (status ${overlayGetRes['statusCode']})');

  // 4. Verify anonymous insert into user_curriculum_resources is blocked
  print('\n4. Verifying anonymous write rejection on user_curriculum_resources:');
  final dummyInsertRes = await client.restPost('user_curriculum_resources', {
    'curriculum_node_id': '00000000-0000-0000-0000-000000000000',
    'lesson_id': '00000000-0000-0000-0000-000000000000',
    'relationship': 'personal_study',
  });
  expect(dummyInsertRes['statusCode'] >= 400, 'Anonymous insert into user_curriculum_resources rejected (status ${dummyInsertRes['statusCode']})');

  // 5. Verify published and retired target versions immutability
  print('\n5. Verifying published & retired TargetVersion immutability:');
  final versionsRes = await client.restGet('target_versions?select=id,version_code,status&status=eq.published&limit=1');
  if (versionsRes['statusCode'] != 200) {
    print('  DEBUG target_versions response: status ${versionsRes['statusCode']}, body: ${versionsRes['body']}');
  }
  expect(versionsRes['statusCode'] == 200, 'target_versions query returns 200 OK');
  final versions = versionsRes['body'] is List ? versionsRes['body'] as List : [];
  expect(versions.isNotEmpty, 'Published target versions exist (found ${versions.length})');

  if (versions.isNotEmpty) {
    final versionId = versions.first['id'];
    final patchRes = await client.restPatch('target_versions?id=eq.$versionId', {
      'title': 'HACKED_TITLE',
    });
    // Due to RLS status = 'draft', patch on published version modifies 0 rows or is rejected
    final patchBody = patchRes['body'];
    final patchBlocked = patchRes['statusCode'] >= 400 || (patchBody is List && patchBody.isEmpty);
    expect(patchBlocked, 'Mutation on published TargetVersion blocked by RLS status = draft invariant');
  }

  // Summary
  print('\n====================================================');
  print('Results: $passed Passed, $failed Failed');
  print('====================================================');

  if (failed > 0) {
    exit(1);
  }
}
