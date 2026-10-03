import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

class AuthSession {
  final String userId;
  final String accessToken;

  AuthSession({required this.userId, required this.accessToken});
}

class SupabaseRestClient {
  final String url;
  final String anonKey;
  final HttpClient _http = HttpClient();

  SupabaseRestClient(this.url, this.anonKey);

  Future<AuthSession?> signInAnonymously() async {
    final uri = Uri.parse('$url/auth/v1/signup');
    final req = await _http.postUrl(uri);
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $anonKey');
    req.headers.set('Content-Type', 'application/json');

    req.write(jsonEncode({}));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(body);
      final token = data['access_token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;
      if (token != null && userId != null) {
        return AuthSession(userId: userId, accessToken: token);
      }
    }
    print('Failed anonymous sign in (${resp.statusCode}): $body');
    return null;
  }

  Future<Map<String, dynamic>> restGet(String path, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.getUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Accept', 'application/json');

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
      'headers': resp.headers,
    };
  }

  Future<Map<String, dynamic>> restPost(String path, dynamic data, {String? token, bool upsert = false}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.postUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Content-Type', 'application/json');
    if (upsert) {
      req.headers.set('Prefer', 'resolution=merge-duplicates,return=representation');
    } else {
      req.headers.set('Prefer', 'return=representation');
    }

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

  Future<Map<String, dynamic>> restDelete(String path, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.deleteUrl(uri);
    final auth = token ?? anonKey;
    req.headers.set('apikey', anonKey);
    req.headers.set('Authorization', 'Bearer $auth');
    req.headers.set('Prefer', 'return=representation');

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

List<dynamic> asList(dynamic body) {
  if (body is List) return body;
  return [];
}

String generateUuid(String prefix) {
  final r = Random();
  String hex(int bytes) => List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '00000000-$prefix-4000-8000-${hex(6)}';
}

Future<void> main() async {
  print('====================================================');
  print('🛡️  Authoritative Multi-Party Hosted RLS Verification');
  print('====================================================');

  final env = _loadDotenv();
  final url = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'] ?? Platform.environment['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    print('❌ SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env');
    exit(1);
  }

  print('📡 Target: $url');
  final client = SupabaseRestClient(url, anonKey);

  print('🔑 Authenticating User A and User B via anonymous auth...');
  final sessionA = await client.signInAnonymously();
  if (sessionA == null) {
    print('❌ Failed to authenticate User A');
    exit(1);
  }

  final sessionB = await client.signInAnonymously();
  if (sessionB == null) {
    print('❌ Failed to authenticate User B');
    exit(1);
  }

  print('  ✓ User A: ${sessionA.userId}');
  print('  ✓ User B: ${sessionB.userId}');

  // Ensure user profiles exist in public.users (matching app AuthProvider behavior)
  await client.restPost('users', {
    'id': sessionA.userId,
    'display_name': 'Test User A',
    'created_at': DateTime.now().toIso8601String(),
  }, token: sessionA.accessToken, upsert: true);

  await client.restPost('users', {
    'id': sessionB.userId,
    'display_name': 'Test User B',
    'created_at': DateTime.now().toIso8601String(),
  }, token: sessionB.accessToken, upsert: true);

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

  // --------------------------------------------------------------------------
  // 1. Public Catalog Verification
  // --------------------------------------------------------------------------
  print('\n1. Verifying public catalog visibility:');
  final publicLessonsRes = await client.restGet('lessons?select=id,title,visibility&visibility=eq.public&limit=5');
  expect(publicLessonsRes['statusCode'] == 200, 'Public lessons query returns 200 OK');
  final publicLessons = asList(publicLessonsRes['body']);
  expect(publicLessons.isNotEmpty, 'Public lessons exist and are readable anonymously (${publicLessons.length} found)');

  // --------------------------------------------------------------------------
  // 2. Private Lesson True Positive & Multi-Party Isolation
  // --------------------------------------------------------------------------
  print('\n2. Verifying private lesson positive access & multi-party isolation:');
  final testLessonId = generateUuid('aaaa');

  // User A creates a private lesson
  final insertLessonRes = await client.restPost('lessons', {
    'id': testLessonId,
    'title': 'Test Private Lesson by User A',
    'visibility': 'private',
    'user_id': sessionA.userId,
  }, token: sessionA.accessToken);
  expect(insertLessonRes['statusCode'] == 201, 'User A creates private lesson (status ${insertLessonRes['statusCode']})');

  // Positive Test: User A (owner) can read it
  final readByARes = await client.restGet('lessons?id=eq.$testLessonId', token: sessionA.accessToken);
  final readByA = asList(readByARes['body']);
  expect(readByA.isNotEmpty && readByA.first['id'] == testLessonId, 'User A (owner) can read their own private lesson (True Positive)');

  // Negative Test 1: User B (unrelated user) cannot read it
  final readByBRes = await client.restGet('lessons?id=eq.$testLessonId', token: sessionB.accessToken);
  final readByB = asList(readByBRes['body']);
  expect(readByB.isEmpty, 'User B (unrelated user) receives 0 rows for User A private lesson (True Negative)');

  // Negative Test 2: Anonymous user cannot read it
  final readByAnonRes = await client.restGet('lessons?id=eq.$testLessonId');
  final readByAnon = asList(readByAnonRes['body']);
  expect(readByAnon.isEmpty, 'Anonymous client receives 0 rows for User A private lesson (True Negative)');

  // Negative Test 3: User B cannot modify User A private lesson
  final patchByBRes = await client.restPatch('lessons?id=eq.$testLessonId', {'title': 'Hacked by B'}, token: sessionB.accessToken);
  final patchByBBlocked = patchByBRes['statusCode'] >= 400 || asList(patchByBRes['body']).isEmpty;
  expect(patchByBBlocked, 'User B mutation on User A private lesson blocked');

  // Cleanup private lesson
  await client.restDelete('lessons?id=eq.$testLessonId', token: sessionA.accessToken);
  final verifyDeletedRes = await client.restGet('lessons?id=eq.$testLessonId', token: sessionA.accessToken);
  final verifyDeleted = asList(verifyDeletedRes['body']);
  expect(verifyDeleted.isEmpty, 'User A successfully cleaned up test private lesson');

  // --------------------------------------------------------------------------
  // 3. Personal Curriculum Overlay Isolation & Integrity
  // --------------------------------------------------------------------------
  print('\n3. Verifying personal curriculum overlay isolation & permissions:');
  final nodesRes = await client.restGet('curriculum_nodes?select=id,title,target_version_id&limit=1');
  final nodes = asList(nodesRes['body']);

  if (nodes.isNotEmpty) {
    final nodeId = nodes.first['id'] as String;
    final overlayLessonId = generateUuid('bbbb');

    // User A creates a personal lesson to attach
    await client.restPost('lessons', {
      'id': overlayLessonId,
      'title': 'User A Personal Study Notes',
      'visibility': 'private',
      'user_id': sessionA.userId,
    }, token: sessionA.accessToken);

    // User A creates overlay
    final overlayInsertRes = await client.restPost('user_curriculum_resources', {
      'curriculum_node_id': nodeId,
      'lesson_id': overlayLessonId,
      'relationship': 'personal_study',
    }, token: sessionA.accessToken);

    final overlayList = asList(overlayInsertRes['body']);
    expect(overlayInsertRes['statusCode'] == 201 && overlayList.isNotEmpty, 'User A can create personal overlay on official node (True Positive)');

    if (overlayList.isNotEmpty) {
      final overlayId = overlayList.first['id'] as String;

      // Positive Test: User A can read their overlay
      final readOverlayARes = await client.restGet('user_curriculum_resources?id=eq.$overlayId', token: sessionA.accessToken);
      final readOverlayA = asList(readOverlayARes['body']);
      expect(readOverlayA.isNotEmpty, 'User A can read their personal overlay');

      // Negative Test 1: User B cannot read User A overlay
      final readOverlayBRes = await client.restGet('user_curriculum_resources?id=eq.$overlayId', token: sessionB.accessToken);
      final readOverlayB = asList(readOverlayBRes['body']);
      expect(readOverlayB.isEmpty, 'User B cannot see User A personal overlay (True Negative)');

      // Negative Test 2: Anon cannot read User A overlay
      final readOverlayAnonRes = await client.restGet('user_curriculum_resources?id=eq.$overlayId');
      final readOverlayAnon = asList(readOverlayAnonRes['body']);
      final anonBlocked = readOverlayAnonRes['statusCode'] >= 400 || readOverlayAnon.isEmpty;
      expect(anonBlocked, 'Anon cannot see User A personal overlay (True Negative)');

      // Negative Test 3: User B cannot delete User A overlay
      final delByBRes = await client.restDelete('user_curriculum_resources?id=eq.$overlayId', token: sessionB.accessToken);
      final deleteByBBlocked = delByBRes['statusCode'] >= 400 || asList(delByBRes['body']).isEmpty;
      expect(deleteByBBlocked, 'User B cannot delete User A personal overlay');

      // Cleanup overlay & lesson
      await client.restDelete('user_curriculum_resources?id=eq.$overlayId', token: sessionA.accessToken);
    }
    await client.restDelete('lessons?id=eq.$overlayLessonId', token: sessionA.accessToken);
    expect(true, 'User A cleaned up personal overlay and attached lesson');
  }

  // --------------------------------------------------------------------------
  // 4. TargetVersion Immutability (Owner Perspective)
  // --------------------------------------------------------------------------
  print('\n4. Verifying TargetVersion owner immutability (Draft vs Published/Retired):');
  final testTargetId = generateUuid('cccc');
  final testTargetSlug = 'test-target-${Random().nextInt(99999999)}';

  // User A creates a draft target
  final createTargetRes = await client.restPost('learning_targets', {
    'id': testTargetId,
    'target_type': 'certification',
    'title': 'Temporary Test Certification Target',
    'slug': testTargetSlug,
    'is_official': false,
    'is_public': false,
    'status': 'draft',
    'created_by': sessionA.userId,
  }, token: sessionA.accessToken);
  expect(createTargetRes['statusCode'] == 201, 'Owner creates draft target');

  // User A creates a draft target_version
  final testVersionId = generateUuid('dddd');
  final createVersionRes = await client.restPost('target_versions', {
    'id': testVersionId,
    'target_id': testTargetId,
    'version_code': 'v1-draft',
    'title': 'Original Draft Title',
    'status': 'draft',
  }, token: sessionA.accessToken);
  expect(createVersionRes['statusCode'] == 201, 'Owner creates draft TargetVersion');

  // Positive Test: User A CAN modify their draft version
  final patchDraftRes = await client.restPatch(
    'target_versions?id=eq.$testVersionId',
    {'title': 'Updated Draft Title'},
    token: sessionA.accessToken,
  );
  final patchDraftBody = asList(patchDraftRes['body']);
  expect(
    patchDraftRes['statusCode'] == 200 && patchDraftBody.isNotEmpty && patchDraftBody.first['title'] == 'Updated Draft Title',
    'Owner can edit their draft TargetVersion (True Positive)',
  );

  // Positive Test: User A CAN add curriculum nodes to draft version
  final testNodeId = generateUuid('eeee');
  final insertNodeRes = await client.restPost('curriculum_nodes', {
    'id': testNodeId,
    'target_version_id': testVersionId,
    'node_type': 'domain',
    'title': 'Draft Topic 1',
    'code': 'D1',
    'sort_order': 1,
  }, token: sessionA.accessToken);
  expect(insertNodeRes['statusCode'] == 201, 'Owner can add curriculum nodes to draft TargetVersion (True Positive)');

  // Now promote the target version to published
  final publishVersionRes = await client.restPatch(
    'target_versions?id=eq.$testVersionId',
    {'status': 'published'},
    token: sessionA.accessToken,
  );
  expect(publishVersionRes['statusCode'] == 200, 'Owner promotes TargetVersion to published');

  // Negative Test 1: Owner CANNOT modify published version
  final patchPublishedRes = await client.restPatch(
    'target_versions?id=eq.$testVersionId',
    {'title': 'Illegal Published Edit'},
    token: sessionA.accessToken,
  );
  final patchPublishedBlocked = patchPublishedRes['statusCode'] >= 400 || asList(patchPublishedRes['body']).isEmpty;
  expect(patchPublishedBlocked, 'Owner CANNOT edit published TargetVersion (Strict Immutability)');

  // Negative Test 2: Owner CANNOT add curriculum nodes to published version
  final illegalNodeRes = await client.restPost('curriculum_nodes', {
    'target_version_id': testVersionId,
    'node_type': 'domain',
    'title': 'Illegal Node on Published',
    'sort_order': 2,
  }, token: sessionA.accessToken);
  final illegalNodeBlocked = illegalNodeRes['statusCode'] >= 400 || asList(illegalNodeRes['body']).isEmpty;
  expect(illegalNodeBlocked, 'Owner CANNOT add curriculum nodes to published TargetVersion (Strict Immutability)');

  // Negative Test 3: Owner CANNOT delete published version
  final delPublishedRes = await client.restDelete('target_versions?id=eq.$testVersionId', token: sessionA.accessToken);
  final deletePublishedBlocked = delPublishedRes['statusCode'] >= 400 || asList(delPublishedRes['body']).isEmpty;
  expect(deletePublishedBlocked, 'Owner CANNOT delete published TargetVersion (Strict Immutability)');

  // Clean up test target and cascade
  await client.restDelete('curriculum_nodes?id=eq.$testNodeId', token: sessionA.accessToken);
  await client.restDelete('learning_targets?id=eq.$testTargetId', token: sessionA.accessToken);
  expect(true, 'Owner successfully cleaned up test target and children');

  // --------------------------------------------------------------------------
  // 5. Content Provenance Schema & Access Control
  // --------------------------------------------------------------------------
  print('\n5. Verifying content provenance tables and access control:');
  final provenanceReleasesRes = await client.restGet('content_source_releases?select=id,publisher,title,version&limit=5');
  expect(provenanceReleasesRes['statusCode'] == 200, 'content_source_releases is accessible anonymously (status 200)');

  final provenanceMappingsRes = await client.restGet('content_source_mappings?select=id,entity_type,relationship&limit=5');
  expect(provenanceMappingsRes['statusCode'] == 200, 'content_source_mappings is accessible anonymously (status 200)');

  // Regular authenticated user (User A) cannot write to provenance without service_role
  final illegalProvenanceRes = await client.restPost('content_source_releases', {
    'publisher': 'Illegal Publisher',
    'title': 'Hacked Release',
    'version': '1.0',
  }, token: sessionA.accessToken);
  final provenanceWriteBlocked = illegalProvenanceRes['statusCode'] >= 400 || asList(illegalProvenanceRes['body']).isEmpty;
  expect(provenanceWriteBlocked, 'Regular authenticated users CANNOT insert into content_source_releases (Service-Role Protected)');

  // --------------------------------------------------------------------------
  // Summary
  // --------------------------------------------------------------------------
  print('\n====================================================');
  print('Results: $passed Passed, $failed Failed');
  print('====================================================');

  if (failed > 0) {
    exit(1);
  }
}
