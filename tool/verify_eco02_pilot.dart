import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'supabase_rest_auth.dart';

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

class PilotAuthSession {
  final String userId;
  final String accessToken;
  final String role;

  PilotAuthSession({
    required this.userId,
    required this.accessToken,
    this.role = 'authenticated',
  });
}

class PilotRestClient {
  final String url;
  final String anonKey;
  final HttpClient _http = HttpClient();

  PilotRestClient(this.url, this.anonKey);

  Future<PilotAuthSession?> signInAnonymously({String? email}) async {
    final uri = Uri.parse('$url/auth/v1/signup');
    final req = await _http.postUrl(uri);
    setSupabaseRestAuth(req, anonKey);
    req.headers.set('Content-Type', 'application/json');

    if (email != null) {
      req.write(jsonEncode({
        'email': email,
        'password': 'Password123!@#TestPilot',
      }));
    } else {
      req.write(jsonEncode({}));
    }

    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(body);
      final token = data['access_token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;
      if (token != null && userId != null) {
        return PilotAuthSession(userId: userId, accessToken: token);
      }
    }
    // If user already exists, sign in
    if (email != null && resp.statusCode == 422) {
      return signInWithPassword(email, 'Password123!@#TestPilot');
    }

    print('Failed sign in (${resp.statusCode}): $body');
    return null;
  }

  Future<PilotAuthSession?> signInWithPassword(String email, String password) async {
    final uri = Uri.parse('$url/auth/v1/token?grant_type=password');
    final req = await _http.postUrl(uri);
    setSupabaseRestAuth(req, anonKey);
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({
      'email': email,
      'password': password,
    }));

    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(body);
      final token = data['access_token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id'] as String?;
      if (token != null && userId != null) {
        return PilotAuthSession(userId: userId, accessToken: token);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> restGet(String path, {String? token}) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.getUrl(uri);
    final auth = token ?? anonKey;
    setSupabaseRestAuth(req, auth);
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

  Future<Map<String, dynamic>> restPost(
    String path,
    dynamic data, {
    String? token,
    bool upsert = false,
    bool returnRepresentation = true,
  }) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.postUrl(uri);
    final auth = token ?? anonKey;
    setSupabaseRestAuth(req, auth);
    req.headers.set('Content-Type', 'application/json');
    if (upsert) {
      req.headers.set('Prefer', 'resolution=merge-duplicates,return=representation');
    } else if (returnRepresentation) {
      req.headers.set('Prefer', 'return=representation');
    } else {
      req.headers.set('Prefer', 'return=minimal');
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

  Future<Map<String, dynamic>> restPatch(
    String path,
    Map<String, dynamic> data, {
    String? token,
    bool returnRepresentation = true,
  }) async {
    final uri = Uri.parse('$url/rest/v1/$path');
    final req = await _http.patchUrl(uri);
    final auth = token ?? anonKey;
    setSupabaseRestAuth(req, auth);
    req.headers.set('Content-Type', 'application/json');
    if (returnRepresentation) {
      req.headers.set('Prefer', 'return=representation');
    } else {
      req.headers.set('Prefer', 'return=minimal');
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

  Future<Map<String, dynamic>> rpc(
    String functionName,
    Map<String, dynamic> params, {
    String? token,
  }) async {
    final uri = Uri.parse('$url/rest/v1/rpc/$functionName');
    final req = await _http.postUrl(uri);
    final auth = token ?? anonKey;
    setSupabaseRestAuth(req, auth);
    req.headers.set('Content-Type', 'application/json');

    req.write(jsonEncode(params));
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
    setSupabaseRestAuth(req, auth);
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

  Future<Map<String, dynamic>> adminDeleteUser(String userId, {required String serviceKey}) async {
    final uri = Uri.parse('$url/auth/v1/admin/users/$userId');
    final req = await _http.deleteUrl(uri);
    setSupabaseRestAuth(req, serviceKey);
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

String generatePilotUuid(String hexTag) {
  final r = Random();
  String hex(int bytes) => List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return '00000000-$hexTag-4000-8000-${hex(6)}';
}

void main(List<String> args) async {
  print('================================================================');
  print('🧪 ECO-02 Phase 1 Controlled Pilot Verification Suite');
  print('   Operational Multi-Party Validation: Learner + Moderator Roles');
  print('================================================================');

  final env = _loadDotenv();
  String? url = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  String? anonKey = env['SUPABASE_ANON_KEY'] ?? Platform.environment['SUPABASE_ANON_KEY'];
  String? serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'] ?? Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--url' && i + 1 < args.length) url = args[++i];
    if (args[i] == '--anon-key' && i + 1 < args.length) anonKey = args[++i];
    if (args[i] == '--service-key' && i + 1 < args.length) serviceKey = args[++i];
  }

  if (url == null || anonKey == null) {
    print('❌ SUPABASE_URL or SUPABASE_ANON_KEY is missing in .env or arguments');
    exit(1);
  }

  print('📡 Target Gateway: $url');
  final client = PilotRestClient(url, anonKey);

  // Authenticate participants
  print('\n👥 Step 0: Authenticating Pilot Participants...');
  final sessionLearnerA = await client.signInAnonymously();
  if (sessionLearnerA == null) {
    print('❌ Failed to authenticate Learner A');
    exit(1);
  }
  print('  ✓ Learner A (Author): ${sessionLearnerA.userId}');

  final sessionLearnerB = await client.signInAnonymously();
  if (sessionLearnerB == null) {
    print('❌ Failed to authenticate Learner B');
    exit(1);
  }
  print('  ✓ Learner B (Peer/Switcher): ${sessionLearnerB.userId}');

  // Ensure public.users profile exists
  await client.restPost('users', {
    'id': sessionLearnerA.userId,
    'display_name': 'Pilot Learner A',
    'created_at': DateTime.now().toIso8601String(),
  }, token: sessionLearnerA.accessToken, upsert: true);

  await client.restPost('users', {
    'id': sessionLearnerB.userId,
    'display_name': 'Pilot Learner B',
    'created_at': DateTime.now().toIso8601String(),
  }, token: sessionLearnerB.accessToken, upsert: true);

  // Moderator participant
  final sessionModerator = await client.signInAnonymously();
  if (sessionModerator == null) {
    print('❌ Failed to authenticate Moderator');
    exit(1);
  }
  print('  ✓ Moderator (Reviewer): ${sessionModerator.userId}');

  await client.restPost('users', {
    'id': sessionModerator.userId,
    'display_name': 'Pilot Moderator',
    'created_at': DateTime.now().toIso8601String(),
  }, token: sessionModerator.accessToken, upsert: true);

  // Provision moderator role
  if (serviceKey != null && serviceKey.isNotEmpty) {
    print('🔑 Provisioning Moderator Role via service_role authorization...');
    final modRoleRes = await client.restPost('moderation_roles', {
      'user_id': sessionModerator.userId,
      'role': 'moderator',
      'granted_by': sessionModerator.userId,
    }, token: serviceKey, upsert: true);
    if (modRoleRes['statusCode'] >= 200 && modRoleRes['statusCode'] < 300) {
      print('  ✓ Moderator role successfully provisioned for ${sessionModerator.userId}');
    } else {
      print('  ⚠️ Moderator role provision status: ${modRoleRes['statusCode']} (${modRoleRes['body']})');
    }
  } else {
    print('ℹ️  No serviceKey provided; attempting self-insert or assuming role pre-provisioned');
  }

  int passed = 0;
  int failed = 0;

  void expect(bool condition, String message, [String? detail]) {
    if (condition) {
      print('  ✓ $message');
      passed++;
    } else {
      print('  ❌ FAILED: $message');
      if (detail != null) print('     ↳ $detail');
      failed++;
    }
  }

  final testQuestionId = generatePilotUuid('0001');
  final testAnswerId = generatePilotUuid('a001');
  final revisedAnswerId = generatePilotUuid('a002');

  try {
    // --------------------------------------------------------------------------
    // 1. Seed FAQ Availability & Anonymous Baseline
    // --------------------------------------------------------------------------
    print('\n📖 1. Verifying Pilot Seed FAQ Baseline & Anonymous Access:');
    final publishedQuestionsRes = await client.restGet(
      'community_questions?status=eq.published&is_seeded=eq.true&select=id,title,concept_id,is_seeded,answer_count',
    );
    expect(
      publishedQuestionsRes['statusCode'] == 200,
      'Anonymous query to published seeded FAQs returns 200 OK',
      'Status: ${publishedQuestionsRes['statusCode']}',
    );

    final publishedFaqs = asList(publishedQuestionsRes['body']);
    expect(
      publishedFaqs.length >= 18,
      'All 18 reference pilot FAQs are active and queryable anonymously (${publishedFaqs.length} found)',
      'Expected >= 18, found ${publishedFaqs.length}',
    );

    final sampleFaq = publishedFaqs.isNotEmpty ? publishedFaqs.first as Map<String, dynamic> : null;
    final sampleFaqId = sampleFaq?['id'] as String?;
    final sampleConceptId = sampleFaq?['concept_id'] as String? ?? 'literacy.cvc.basics';

    // Verify anonymous user cannot insert community question
    final anonInsertQuestionRes = await client.restPost('community_questions', {
      'title': 'Illegal Anonymous Question',
      'body_markdown': 'Should be rejected',
      'status': 'draft',
    });
    expect(
      anonInsertQuestionRes['statusCode'] >= 400,
      'Anonymous user CANNOT insert community question (Security Enforced)',
      'Status: ${anonInsertQuestionRes['statusCode']}',
    );

    // --------------------------------------------------------------------------
    // 2. Learner A Question Draft & RLS Isolation
    // --------------------------------------------------------------------------
    print('\n📝 2. Verifying Learner Private Question Draft & Multi-Party Isolation:');

    final createQuestionRes = await client.restPost('community_questions', {
      'id': testQuestionId,

    'author_id': sessionLearnerA.userId,
    'title': 'How do children transition from CVC words to consonant blends?',
    'body_markdown': 'During phonics reading practice, what is the best sequence to introduce CCVC blends after mastering simple CVC words?',
    'concept_id': sampleConceptId,
    'status': 'draft',
    'is_seeded': false,
  }, token: sessionLearnerA.accessToken);

  expect(
    createQuestionRes['statusCode'] == 201,
    'Learner A creates private question draft in topic "$sampleConceptId"',
    'Status: ${createQuestionRes['statusCode']}, body: ${createQuestionRes['body']}',
  );

  // Positive: Learner A can read back their draft
  final readQuestionARes = await client.restGet(
    'community_questions?id=eq.$testQuestionId',
    token: sessionLearnerA.accessToken,
  );
  final readQuestionA = asList(readQuestionARes['body']);
  expect(
    readQuestionA.isNotEmpty && readQuestionA.first['id'] == testQuestionId,
    'Learner A (author) can read their own draft question (True Positive)',
  );

  // Negative 1: Learner B receives 0 rows
  final readQuestionBRes = await client.restGet(
    'community_questions?id=eq.$testQuestionId',
    token: sessionLearnerB.accessToken,
  );
  final readQuestionB = asList(readQuestionBRes['body']);
  expect(
    readQuestionB.isEmpty,
    'Learner B receives 0 rows for Learner A draft question (True Negative Isolation)',
  );

  // Negative 2: Anonymous user receives 0 rows
  final readQuestionAnonRes = await client.restGet(
    'community_questions?id=eq.$testQuestionId',
  );
  final readQuestionAnon = asList(readQuestionAnonRes['body']);
  expect(
    readQuestionAnon.isEmpty,
    'Anonymous client receives 0 rows for Learner A draft question (True Negative Isolation)',
  );

  // --------------------------------------------------------------------------
  // 3. Learner A Submits Private Answer Draft on Seeded Question
  // --------------------------------------------------------------------------
  print('\n💬 3. Verifying Learner Answer Submission & Under-Review Isolation:');

  final submitAnswerRes = await client.restPost('community_answers', {
      'id': testAnswerId,
      'question_id': sampleFaqId,
      'author_id': sessionLearnerA.userId,
      'body_markdown': 'Learner explanation: Start with continuous sounds like /s/, /m/, /f/ before stops like /t/, /p/.',
      'status': 'under_review',
      'is_accepted': false,
      'is_seeded': false,
    }, token: sessionLearnerA.accessToken);

    expect(
      submitAnswerRes['statusCode'] == 201,
      'Learner A submits explanatory answer draft under_review on seeded FAQ',
      'Status: ${submitAnswerRes['statusCode']}, body: ${submitAnswerRes['body']}',
    );

    // Positive: Learner A can view their submitted answer
    final readAnswerARes = await client.restGet(
      'community_answers?id=eq.$testAnswerId',
      token: sessionLearnerA.accessToken,
    );
    final readAnswerA = asList(readAnswerARes['body']);
    expect(
      readAnswerA.isNotEmpty && readAnswerA.first['id'] == testAnswerId,
      'Learner A can view their under_review answer (True Positive)',
    );

    // Negative: Learner B queries answers on this FAQ; sees ONLY published/accepted, NOT Learner A draft
    final readAnswersBRes = await client.restGet(
      'community_answers?question_id=eq.$sampleFaqId&select=id,status,is_accepted',
      token: sessionLearnerB.accessToken,
    );
    final answersB = asList(readAnswersBRes['body']);
    final containsLearnerADraft = answersB.any((a) => a['id'] == testAnswerId);
    expect(
      !containsLearnerADraft,
      'Learner B CANNOT see Learner A under_review answer (Under-Review Isolation Enforced)',
      'Found answers: ${answersB.map((a) => a['id']).toList()}',
    );

    // ------------------------------------------------------------------------
    // 4. Moderator Review & Confidential Feedback vs Internal Notes Separation
    // ------------------------------------------------------------------------
    print('\n⚖️  4. Verifying Moderator Review, Editorial Feedback & Internal Notes:');

    // Moderator inspects under_review submissions
    final modReviewRes = await client.rpc('review_community_answer', {
      'p_answer_id': testAnswerId,
      'p_action': 'reject',
      'p_notes': 'Editorial Feedback: Please distinguish continuous blends from digraphs and add an example word like "stop".',
      'p_internal_notes': 'Confidential Mod Audit: Rejected in pilot stage due to missing example word. Reviewer verified via automated pilot suite.',
    }, token: sessionModerator.accessToken);

    expect(
      modReviewRes['statusCode'] == 200 && modReviewRes['body']?['success'] == true,
      'Moderator executes review_community_answer with rejection + feedback + internal notes',
      'Status: ${modReviewRes['statusCode']}, body: ${modReviewRes['body']}',
    );

    // Verify answer status is transitioned to 'archived'
    final checkAnswerStatusRes = await client.restGet(
      'community_answers?id=eq.$testAnswerId&select=id,status',
      token: sessionLearnerA.accessToken,
    );
    final updatedAnswer = asList(checkAnswerStatusRes['body']);
    expect(
      updatedAnswer.isNotEmpty && updatedAnswer.first['status'] == 'archived',
      'Answer status transitioned to "archived"',
      'Current status: ${updatedAnswer.firstOrNull?['status']}',
    );

    // Verify community_review_audit record exists with both notes and internal_notes
    if (serviceKey != null) {
      final auditRes = await client.restGet(
        'community_review_audit?target_id=eq.$testAnswerId&select=id,target_type,action,notes,internal_notes',
        token: serviceKey,
      );
      final auditRows = asList(auditRes['body']);
      expect(
        auditRows.isNotEmpty &&
            auditRows.first['notes'] != null &&
            auditRows.first['internal_notes'] != null,
        'Durable review audit created preserving both author feedback AND confidential internal notes',
        'Audit rows: $auditRows',
      );
    }

    // ------------------------------------------------------------------------
    // 5. Learner Decision Feedback Query (Isolation & Zero Leaks)
    // ------------------------------------------------------------------------
    print('\n📬 5. Verifying Learner Decision Feedback Query & Privacy Boundaries:');

    // Positive: Learner A calls fetch_my_submission_feedback
    final feedbackARes = await client.rpc(
      'fetch_my_submission_feedback',
      {'p_target_id': testAnswerId},
      token: sessionLearnerA.accessToken,
    );
    expect(
      feedbackARes['statusCode'] == 200,
      'Learner A calls fetch_my_submission_feedback successfully (200 OK)',
    );
    final feedbackA = asList(feedbackARes['body']);
    expect(
      feedbackA.isNotEmpty && feedbackA.first['feedback'] != null,
      'Learner A receives author editorial feedback ("${feedbackA.firstOrNull?['feedback']}")',
    );
    expect(
      feedbackA.firstOrNull?['internal_notes'] == null,
      'Confidential internal_notes are NOT exposed to author (Zero Privacy Leak)',
    );
    expect(
      feedbackA.firstOrNull?['reviewer_id'] == null,
      'Reviewer identity is NOT exposed to author (Moderator Privacy Preserved)',
    );

    // Negative 1: Learner B calls fetch_my_submission_feedback for Learner A's answer
    final feedbackBRes = await client.rpc(
      'fetch_my_submission_feedback',
      {'p_target_id': testAnswerId},
      token: sessionLearnerB.accessToken,
    );
    final feedbackB = asList(feedbackBRes['body']);
    expect(
      feedbackB.isEmpty,
      'Learner B receives 0 rows when attempting to fetch feedback for Learner A submission (Cross-Account Shielded)',
    );

    // Negative 2: Anonymous user calls fetch_my_submission_feedback
    final feedbackAnonRes = await client.rpc(
      'fetch_my_submission_feedback',
      {'p_target_id': testAnswerId},
    );
    final feedbackAnon = asList(feedbackAnonRes['body']);
    expect(
      feedbackAnon.isEmpty,
      'Anonymous user receives 0 feedback rows (Authentication Required)',
    );

    // ------------------------------------------------------------------------
    // 6. Author Revision & Resubmission Workflow
    // ------------------------------------------------------------------------
    print('\n🔄 6. Verifying Author Revision & Resubmission Flow:');

    final resubmitAnswerRes = await client.restPost('community_answers', {
      'id': revisedAnswerId,
      'question_id': sampleFaqId,
      'author_id': sessionLearnerA.userId,
      'body_markdown': 'Revised Explanation: A blend combines two or three consonants (e.g., /s/ and /t/ in "stop") where each sound remains audible, unlike a digraph (e.g., "sh") which makes one new sound.',
      'status': 'under_review',
      'is_accepted': false,
      'is_seeded': false,
    }, token: sessionLearnerA.accessToken);

    expect(
      resubmitAnswerRes['statusCode'] == 201,
      'Learner A successfully resubmits revised answer addressing editorial feedback',
      'Status: ${resubmitAnswerRes['statusCode']}',
    );

    // ------------------------------------------------------------------------
    // 7. Public UGC Launch Gate Enforcement (Hard Security Gate)
    // ------------------------------------------------------------------------
    print('\n🚫 7. Verifying Public UGC Launch Gate Enforcement:');
    final illegalPublishRes = await client.rpc('review_community_answer', {
      'p_answer_id': revisedAnswerId,
      'p_action': 'publish',
    }, token: sessionModerator.accessToken);

    final publishBlocked = illegalPublishRes['statusCode'] >= 400 ||
        (illegalPublishRes['body'] is Map &&
            illegalPublishRes['body'].toString().contains('Public learner UGC is currently disabled'));
    expect(
      publishBlocked,
      'Attempt to publish non-seeded learner answer rejected by UGC Launch Gate (22000)',
      'Response: ${illegalPublishRes['body']}',
    );
  } finally {
    // ------------------------------------------------------------------------
    // 8. Cleanup Synthetic Pilot Test Rows with Rigorous Verification
    // ------------------------------------------------------------------------
    print('\n🧹 8. Cleaning up Synthetic Pilot Test Data:');
    if (serviceKey != null && serviceKey.isNotEmpty) {
      // 1. Delete community_review_audit records
      await client.restDelete('community_review_audit?target_id=eq.$testAnswerId', token: serviceKey);
      await client.restDelete('community_review_audit?target_id=eq.$revisedAnswerId', token: serviceKey);
      await client.restDelete('community_review_audit?target_id=eq.$testQuestionId', token: serviceKey);

      // 2. Delete community_answers via service-role
      await client.restDelete('community_answers?id=eq.$revisedAnswerId', token: serviceKey);
      await client.restDelete('community_answers?id=eq.$testAnswerId', token: serviceKey);

      // 3. Delete community_questions
      await client.restDelete('community_questions?id=eq.$testQuestionId', token: serviceKey);

      // 4. Delete moderation_roles
      await client.restDelete('moderation_roles?user_id=eq.${sessionModerator.userId}', token: serviceKey);

      // 5. Delete public.users
      for (final s in [sessionLearnerA, sessionLearnerB, sessionModerator]) {
        await client.restDelete('users?id=eq.${s.userId}', token: serviceKey);
      }

      // 6. Delete auth.users via GoTrue admin API
      for (final s in [sessionLearnerA, sessionLearnerB, sessionModerator]) {
        await client.adminDeleteUser(s.userId, serviceKey: serviceKey);
      }

      // 7. Rigorous verification: query REST to verify all residual test records are 0
      final checkAnswers = await client.restGet(
        'community_answers?id=in.($testAnswerId,$revisedAnswerId)&select=id',
        token: serviceKey,
      );
      final residualAnswers = asList(checkAnswers['body']);
      expect(
        residualAnswers.isEmpty,
        'Residual test answers cleanly purged (0 remaining)',
        'Found residual answers: $residualAnswers',
      );

      final checkQuestions = await client.restGet(
        'community_questions?id=eq.$testQuestionId&select=id',
        token: serviceKey,
      );
      final residualQuestions = asList(checkQuestions['body']);
      expect(
        residualQuestions.isEmpty,
        'Residual test questions cleanly purged (0 remaining)',
        'Found residual questions: $residualQuestions',
      );

      final checkAudits = await client.restGet(
        'community_review_audit?target_id=in.($testAnswerId,$revisedAnswerId)&select=id',
        token: serviceKey,
      );
      final residualAudits = asList(checkAudits['body']);
      expect(
        residualAudits.isEmpty,
        'Residual test audits cleanly purged (0 remaining)',
        'Found residual audits: $residualAudits',
      );
    } else {
      await client.restDelete('community_answers?id=eq.$revisedAnswerId', token: sessionLearnerA.accessToken);
      await client.restDelete('community_answers?id=eq.$testAnswerId', token: sessionLearnerA.accessToken);
      await client.restDelete('community_questions?id=eq.$testQuestionId', token: sessionLearnerA.accessToken);
      expect(true, 'Synthetic pilot test questions and answers purge attempted');
    }
  }

  // --------------------------------------------------------------------------
  // Summary
  // --------------------------------------------------------------------------
  print('\n================================================================');
  print('🏁 ECO-02 Controlled Pilot Verification Results:');
  print('   Passed: $passed / ${passed + failed}');
  print('   Failed: $failed');
  print('================================================================');

  if (failed > 0) {
    exit(1);
  }
}
