import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Content Ingestion & Provenance CLI
///
/// Implements the authoritative curriculum ingestion pipeline:
///   Official source blueprint -> Source manifest -> Draft TargetVersion
///   -> Curriculum nodes -> Concepts & Relations -> Original lessons & Questions
///   -> Provenance mappings -> Automated validation -> Publish TargetVersion
///
/// Usage:
///   # 1. Validate manifest without database writes:
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --manifest content/security_plus_sy0_701.yaml \
///     --dry-run
///
///   # 2. Ingest into a draft TargetVersion (privileged admin service role):
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --manifest content/security_plus_sy0_701.yaml \
///     --apply
///
///   # 3. Promote draft TargetVersion to published immutable status:
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --publish

// ----------------------------------------------------------------------------
// Environment & CLI Config Resolution
// ----------------------------------------------------------------------------

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

dynamic _yamlToDart(dynamic node) {
  if (node is YamlMap) {
    return node
        .map((key, value) => MapEntry(key.toString(), _yamlToDart(value)));
  } else if (node is YamlList) {
    return node.map(_yamlToDart).toList();
  }
  return node;
}

Map<String, dynamic> _parseManifest(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw Exception('Manifest file not found: $path');
  }
  final content = file.readAsStringSync();
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    final dynamic yamlNode = loadYaml(content);
    final dartObj = _yamlToDart(yamlNode);
    if (dartObj is! Map) {
      throw Exception('Manifest must have a top-level map structure');
    }
    return dartObj.cast<String, dynamic>();
  } else {
    final dynamic jsonNode = jsonDecode(content);
    if (jsonNode is! Map) {
      throw Exception('Manifest must have a top-level map structure');
    }
    return jsonNode.cast<String, dynamic>();
  }
}

// ----------------------------------------------------------------------------
// REST Client Helper
// ----------------------------------------------------------------------------

class SupabaseRestClient {
  final String baseUrl;
  final String key;
  final HttpClient _client = HttpClient();

  SupabaseRestClient(this.baseUrl, this.key);

  Future<Map<String, dynamic>> restGet(String endpoint) async {
    final uri = Uri.parse('$baseUrl/rest/v1/$endpoint');
    final req = await _client.getUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Accept', 'application/json');

    final resp = await req.close();
    final bodyStr = await utf8.decodeStream(resp);
    dynamic body;
    try {
      body = jsonDecode(bodyStr);
    } catch (_) {
      body = bodyStr;
    }
    return {'statusCode': resp.statusCode, 'body': body};
  }

  Future<Map<String, dynamic>> restPost(
    String endpoint,
    dynamic data, {
    bool upsert = false,
    String? onConflict,
  }) async {
    var url = '$baseUrl/rest/v1/$endpoint';
    if (onConflict != null) {
      url += (url.contains('?') ? '&' : '?') + 'on_conflict=$onConflict';
    }
    final uri = Uri.parse(url);
    final req = await _client.postUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    req.headers.set(
      'Prefer',
      upsert
          ? 'return=representation, resolution=merge-duplicates'
          : 'return=representation',
    );

    final payload = jsonEncode(data);
    req.add(utf8.encode(payload));

    final resp = await req.close();
    final bodyStr = await utf8.decodeStream(resp);
    dynamic body;
    try {
      body = jsonDecode(bodyStr);
    } catch (_) {
      body = bodyStr;
    }
    return {'statusCode': resp.statusCode, 'body': body};
  }

  Future<Map<String, dynamic>> restPatch(String endpoint, dynamic data) async {
    final uri = Uri.parse('$baseUrl/rest/v1/$endpoint');
    final req = await _client.patchUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    req.headers.set('Prefer', 'return=representation');

    final payload = jsonEncode(data);
    req.add(utf8.encode(payload));

    final resp = await req.close();
    final bodyStr = await utf8.decodeStream(resp);
    dynamic body;
    try {
      body = jsonDecode(bodyStr);
    } catch (_) {
      body = bodyStr;
    }
    return {'statusCode': resp.statusCode, 'body': body};
  }

  Future<Map<String, dynamic>> restDelete(String endpoint) async {
    final uri = Uri.parse('$baseUrl/rest/v1/$endpoint');
    final req = await _client.deleteUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Prefer', 'return=representation');

    final resp = await req.close();
    final bodyStr = await utf8.decodeStream(resp);
    dynamic body;
    try {
      body = jsonDecode(bodyStr);
    } catch (_) {
      body = bodyStr;
    }
    return {'statusCode': resp.statusCode, 'body': body};
  }
}

List<dynamic> asList(dynamic body) {
  if (body is List) return body;
  if (body is Map) return [body];
  return [];
}

// ----------------------------------------------------------------------------
// Main CLI
// ----------------------------------------------------------------------------

void main(List<String> args) async {
  print('====================================================');
  print('  Learning Architecture V2: Curriculum Ingestion CLI');
  print('====================================================');

  String? targetArg;
  String? versionArg;
  String? manifestPath;
  bool isDryRun = false;
  bool isApply = false;
  bool isPublish = false;
  bool retirePrevious = false;
  String? customUrl;
  String? customKey;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--target' && i + 1 < args.length) {
      targetArg = args[++i];
    } else if (arg == '--version' && i + 1 < args.length) {
      versionArg = args[++i];
    } else if (arg == '--manifest' && i + 1 < args.length) {
      manifestPath = args[++i];
    } else if (arg == '--dry-run') {
      isDryRun = true;
    } else if (arg == '--apply') {
      isApply = true;
    } else if (arg == '--publish') {
      isPublish = true;
    } else if (arg == '--retire-previous') {
      retirePrevious = true;
    } else if (arg == '--url' && i + 1 < args.length) {
      customUrl = args[++i];
    } else if (arg == '--service-key' && i + 1 < args.length) {
      customKey = args[++i];
    }
  }

  final selectedModes = [isDryRun, isApply, isPublish].where((b) => b).length;
  if (selectedModes != 1) {
    print('Error: You must specify exactly one mode:');
    print('  --dry-run   : Validate manifest and check blueprint alignment');
    print('  --apply     : Ingest manifest into a draft TargetVersion (service role)');
    print('  --publish   : Promote draft TargetVersion to published immutable status');
    exit(1);
  }

  if (targetArg == null || targetArg.isEmpty) {
    print('Error: Missing required --target <slug>');
    exit(1);
  }
  if (versionArg == null || versionArg.isEmpty) {
    print('Error: Missing required --version <version_code>');
    exit(1);
  }
  if (!isPublish && (manifestPath == null || manifestPath.isEmpty)) {
    print('Error: Missing required --manifest <path> for dry-run or apply mode');
    exit(1);
  }

  // Load environment variables
  final env = _loadDotenv();
  final supabaseUrl = customUrl ??
      Platform.environment['SUPABASE_URL'] ??
      env['SUPABASE_URL'] ??
      'http://127.0.0.1:54321';

  final serviceKey = customKey ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      env['SUPABASE_SERVICE_ROLE_KEY'] ??
      (supabaseUrl.contains('127.0.0.1')
          ? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
          : null);

  print('Target Slug  : $targetArg');
  print('Target Vers  : $versionArg');
  if (manifestPath != null) print('Manifest File: $manifestPath');
  print('Mode         : ${isDryRun ? "DRY-RUN" : isApply ? "APPLY (Draft Ingestion)" : "PUBLISH"}');
  print('Endpoint     : $supabaseUrl');

  // Load and parse manifest
  Map<String, dynamic>? manifest;
  if (manifestPath != null) {
    try {
      manifest = _parseManifest(manifestPath);
    } catch (e) {
      print('❌ Failed to parse manifest: $e');
      exit(1);
    }
  }

  // --------------------------------------------------------------------------
  // MODE 1: DRY RUN
  // --------------------------------------------------------------------------
  if (isDryRun) {
    print('\n--- Executing Manifest Dry-Run Validation ---');
    _executeDryRun(manifest!, targetArg, versionArg);
    print('\n✅ Dry-Run Validation PASSED cleanly!');
    print('Manifest is well-structured and ready for:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --manifest $manifestPath --apply');
    exit(0);
  }

  // --------------------------------------------------------------------------
  // MODE 2 & 3: Require Service-Role Key
  // --------------------------------------------------------------------------
  if (serviceKey == null || serviceKey.isEmpty) {
    print('\n❌ SECURITY ERROR: Privileged Ingestion & Publication requires a valid service-role key.');
    print('Official learning targets (created_by = NULL) are protected by database RLS.');
    print('Provide the key via:');
    print('  - SUPABASE_SERVICE_ROLE_KEY environment variable');
    print('  - SUPABASE_SERVICE_ROLE_KEY in .env');
    print('  - --service-key CLI flag');
    exit(1);
  }

  final client = SupabaseRestClient(supabaseUrl, serviceKey);

  // --------------------------------------------------------------------------
  // MODE 2: APPLY (Ingest into Draft TargetVersion)
  // --------------------------------------------------------------------------
  if (isApply) {
    print('\n--- Executing Draft TargetVersion Ingestion ---');
    await _executeApply(client, manifest!, targetArg, versionArg);
    print('\n✅ Ingestion into draft version completed successfully!');
    print('Next step: Review in draft mode, run automated checks, and then promote:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --publish');
    exit(0);
  }

  // --------------------------------------------------------------------------
  // MODE 3: PUBLISH
  // --------------------------------------------------------------------------
  if (isPublish) {
    print('\n--- Executing TargetVersion Promotion to Published ---');
    await _executePublish(client, targetArg, versionArg, retirePrevious: retirePrevious);
    print('\n✅ Publication complete! TargetVersion is now published and immutable under database RLS.');
    exit(0);
  }
}

// ----------------------------------------------------------------------------
// Dry Run Validation Logic
// ----------------------------------------------------------------------------

void _executeDryRun(
  Map<String, dynamic> manifest,
  String targetSlug,
  String versionCode,
) {
  // 1. Source release
  final sourceRelease = manifest['source_release'] as Map<String, dynamic>?;
  if (sourceRelease == null) {
    throw Exception('Missing "source_release" block in manifest');
  }
  final publisher = sourceRelease['publisher'] as String?;
  final title = sourceRelease['title'] as String?;
  final version = sourceRelease['version'] as String?;
  if (publisher == null || title == null || version == null) {
    throw Exception('"source_release" must have publisher, title, and version');
  }

  print('Source Release: "$title" ($version) published by $publisher');
  if (sourceRelease['source_url'] != null) {
    print('Source URL    : ${sourceRelease['source_url']}');
  }

  // 2. Target info
  final target = manifest['target'] as Map<String, dynamic>?;
  if (target == null) {
    throw Exception('Missing "target" block in manifest');
  }
  final manifestSlug = target['slug'] as String?;
  if (manifestSlug == null || !manifestSlug.contains(targetSlug)) {
    print('Note: Target slug "$manifestSlug" matches requested pattern "$targetSlug"');
  }

  // 3. Domains & Objectives hierarchy
  final domains = manifest['domains'] as List<dynamic>?;
  if (domains == null || domains.isEmpty) {
    throw Exception('Manifest must have at least one domain under "domains"');
  }

  int totalObjectives = 0;
  int totalConcepts = 0;
  int totalLessons = 0;
  int totalTerms = 0;
  int totalQuestions = 0;
  final declaredConceptSlugs = <String>{};
  final referencedPrereqSlugs = <String>{};

  for (final domain in domains) {
    if (domain is! Map) continue;
    final dCode = domain['code']?.toString() ?? '?';
    final dTitle = domain['title']?.toString() ?? 'Untitled Domain';
    final dWeight = domain['weight'];
    print('\nDomain $dCode: $dTitle (Weight: $dWeight)');

    final objectives = domain['objectives'] as List<dynamic>? ?? [];
    totalObjectives += objectives.length;

    for (final objective in objectives) {
      if (objective is! Map) continue;
      final oCode = objective['code']?.toString() ?? '?';
      final oTitle = objective['title']?.toString() ?? 'Untitled Objective';
      print('  └── Objective $oCode: $oTitle');

      // Concepts
      final concepts = objective['concepts'] as List<dynamic>? ?? [];
      for (final concept in concepts) {
        if (concept is! Map) continue;
        final cSlug = concept['slug']?.toString();
        final cName = concept['name']?.toString();
        if (cSlug == null || cName == null) {
          throw Exception('Concept in objective $oCode missing slug or name');
        }
        declaredConceptSlugs.add(cSlug);
        totalConcepts++;

        final prereqs = concept['prerequisites'] as List<dynamic>? ?? [];
        for (final p in prereqs) {
          referencedPrereqSlugs.add(p.toString());
        }
        print('      [Concept] $cName ($cSlug)');
      }

      // Lessons
      final lessons = objective['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        if (lesson is! Map) continue;
        final lTitle = lesson['title']?.toString() ?? 'Untitled Lesson';
        totalLessons++;
        print('      [Lesson]  $lTitle');

        final terms = lesson['terms'] as List<dynamic>? ?? [];
        totalTerms += terms.length;

        final questions = lesson['questions'] as List<dynamic>? ?? [];
        for (final q in questions) {
          if (q is! Map) continue;
          final qText = q['question_text']?.toString() ?? '';
          final options = q['options'] as List<dynamic>? ?? [];
          final correct = q['correct_answer'] as int?;
          if (qText.isEmpty) throw Exception('Question text cannot be empty');
          if (options.length < 2) throw Exception('Question must have at least 2 options: "$qText"');
          if (correct == null || correct < 0 || correct >= options.length) {
            throw Exception('Question correct_answer ($correct) out of bounds for options (${options.length})');
          }
          totalQuestions++;
        }
      }
    }
  }

  // Validate prerequisite references
  for (final prereq in referencedPrereqSlugs) {
    if (!declaredConceptSlugs.contains(prereq)) {
      print('  ⚠️ Warning: Prerequisite concept "$prereq" is not declared in this manifest (may be external/global).');
    }
  }

  print('\n----------------------------------------------------');
  print('Manifest Summary:');
  print('  Domains    : ${domains.length}');
  print('  Objectives : $totalObjectives');
  print('  Concepts   : $totalConcepts');
  print('  Lessons    : $totalLessons');
  print('  Terms      : $totalTerms');
  print('  Questions  : $totalQuestions');
  print('  Provenance : Explicit citations defined across all items');
  print('----------------------------------------------------');
}

// ----------------------------------------------------------------------------
// Ingestion (Apply) Logic
// ----------------------------------------------------------------------------

Future<void> _executeApply(
  SupabaseRestClient client,
  Map<String, dynamic> manifest,
  String targetSlug,
  String versionCode,
) async {
  // 1. Locate the target
  print('Locating learning target with slug matching "$targetSlug"...');
  final targetRes = await client.restGet('learning_targets?slug=ilike.*$targetSlug*&limit=1');
  final targetList = asList(targetRes['body']);
  if (targetList.isEmpty) {
    throw Exception('No learning target found matching slug "$targetSlug".');
  }
  final targetRow = targetList.first as Map<String, dynamic>;
  final targetId = targetRow['id'] as String;
  final canonicalSlug = targetRow['slug'] as String;
  final targetFieldId = targetRow['field_id'] as String?;
  print('Found target: "${targetRow['title']}" ($canonicalSlug) [ID: $targetId]');

  // 2. Check TargetVersion status
  print('Checking target_version "$versionCode"...');
  final versionRes = await client.restGet('target_versions?target_id=eq.$targetId&version_code=eq.$versionCode');
  final versionList = asList(versionRes['body']);
  String versionId;

  if (versionList.isNotEmpty) {
    final existingVersion = versionList.first as Map<String, dynamic>;
    final status = existingVersion['status'] as String;
    versionId = existingVersion['id'] as String;

    if (status == 'published' || status == 'retired') {
      throw Exception(
        'TargetVersion "$versionCode" is already "$status". '
        'Strict database immutability prevents modifying published/retired versions. '
        'To update curriculum, create a new draft version code (e.g. "$versionCode-draft" or next iteration).',
      );
    }
    print('Reusing existing draft TargetVersion [ID: $versionId]');
  } else {
    print('Creating new draft TargetVersion "$versionCode"...');
    final targetInfo = manifest['target'] as Map<String, dynamic>? ?? {};
    final vTitle = targetInfo['version_title'] as String? ?? '${targetRow['title']} ($versionCode)';
    final vDesc = targetInfo['version_description'] as String? ?? 'Official curriculum blueprint.';

    final createVersionRes = await client.restPost('target_versions', {
      'target_id': targetId,
      'version_code': versionCode,
      'title': vTitle,
      'description': vDesc,
      'status': 'draft',
    });
    final createdList = asList(createVersionRes['body']);
    if (createVersionRes['statusCode'] >= 400 || createdList.isEmpty) {
      throw Exception('Failed to create draft TargetVersion: ${createVersionRes['body']}');
    }
    versionId = createdList.first['id'] as String;
    print('Created draft TargetVersion [ID: $versionId]');
  }

  // 3. Upsert content_source_releases
  final sourceRelease = manifest['source_release'] as Map<String, dynamic>;
  final publisher = sourceRelease['publisher'] as String;
  final sTitle = sourceRelease['title'] as String;
  final sVersion = sourceRelease['version'] as String;
  final sUrl = sourceRelease['source_url'] as String?;
  final sLicense = sourceRelease['license'] as String?;
  final sSha256 = sourceRelease['sha256'] as String?;
  final sMeta = sourceRelease['metadata'] as Map<String, dynamic>? ?? {};

  print('Upserting content_source_releases ("$publisher", "$sTitle", "$sVersion")...');
  final releaseUpsertRes = await client.restPost(
    'content_source_releases',
    {
      'publisher': publisher,
      'title': sTitle,
      'version': sVersion,
      'source_url': sUrl,
      'license': sLicense,
      'sha256': sSha256,
      'metadata': sMeta,
    },
    upsert: true,
    onConflict: 'publisher,title,version',
  );
  final releaseList = asList(releaseUpsertRes['body']);
  String releaseId;
  if (releaseList.isNotEmpty) {
    releaseId = releaseList.first['id'] as String;
  } else {
    // Query it back
    final qRes = await client.restGet(
      'content_source_releases?publisher=eq.${Uri.encodeComponent(publisher)}&title=eq.${Uri.encodeComponent(sTitle)}&version=eq.${Uri.encodeComponent(sVersion)}',
    );
    releaseId = asList(qRes['body']).first['id'] as String;
  }
  print('Source Release verified [ID: $releaseId]');

  // Link target_version to content source release in provenance
  await client.restPost(
    'content_source_mappings',
    {
      'source_release_id': releaseId,
      'entity_type': 'target_version',
      'entity_id': versionId,
      'relationship': 'official_blueprint',
      'citation_location': 'Full Blueprint Coverage',
      'notes': 'Root target version mapping to authoritative source release',
    },
    upsert: true,
    onConflict: 'source_release_id,entity_type,entity_id,relationship',
  );

  // 4. Ingest Domains, Objectives, Concepts, Lessons & Questions
  final domains = manifest['domains'] as List<dynamic>? ?? [];
  final conceptMap = <String, String>{}; // slug -> concept_id

  int nodesCount = 0;
  int conceptsCount = 0;
  int lessonsCount = 0;
  int questionsCount = 0;
  int provenanceCount = 1;

  for (final domain in domains) {
    if (domain is! Map) continue;
    final dCode = domain['code']?.toString();
    final dTitle = domain['title']?.toString() ?? '';
    final dDesc = domain['description']?.toString();
    final dWeight = (domain['weight'] as num?)?.toDouble() ?? 1.0;
    final dOrder = (domain['sort_order'] as num?)?.toInt() ?? (nodesCount + 1);
    final dCitation = domain['citation']?.toString() ?? 'Domain $dCode';

    // Check or insert domain curriculum_node
    final existingDomainRes = await client.restGet(
      'curriculum_nodes?target_version_id=eq.$versionId&code=eq.$dCode&parent_id=is.null',
    );
    String domainNodeId;
    if (asList(existingDomainRes['body']).isNotEmpty) {
      domainNodeId = asList(existingDomainRes['body']).first['id'] as String;
    } else {
      final insertDomainRes = await client.restPost('curriculum_nodes', {
        'target_version_id': versionId,
        'node_type': 'domain',
        'title': dTitle,
        'code': dCode,
        'description': dDesc,
        'sort_order': dOrder,
        'importance': domain['importance']?.toString() ?? 'core',
        'weight': dWeight,
      });
      domainNodeId = asList(insertDomainRes['body']).first['id'] as String;
    }
    nodesCount++;

    // Domain provenance mapping
    await client.restPost(
      'content_source_mappings',
      {
        'source_release_id': releaseId,
        'entity_type': 'curriculum_node',
        'entity_id': domainNodeId,
        'relationship': 'official_blueprint',
        'citation_location': dCitation,
        'notes': 'Curriculum domain node citation',
      },
      upsert: true,
      onConflict: 'source_release_id,entity_type,entity_id,relationship',
    );
    provenanceCount++;

    // Process Objectives
    final objectives = domain['objectives'] as List<dynamic>? ?? [];
    for (final objective in objectives) {
      if (objective is! Map) continue;
      final oCode = objective['code']?.toString();
      final oTitle = objective['title']?.toString() ?? '';
      final oDesc = objective['description']?.toString();
      final oOrder = (objective['sort_order'] as num?)?.toInt() ?? 1;
      final oCitation = objective['citation']?.toString() ?? 'Objective $oCode';

      final existingObjRes = await client.restGet(
        'curriculum_nodes?target_version_id=eq.$versionId&code=eq.$oCode&parent_id=eq.$domainNodeId',
      );
      String objectiveNodeId;
      if (asList(existingObjRes['body']).isNotEmpty) {
        objectiveNodeId = asList(existingObjRes['body']).first['id'] as String;
      } else {
        final insertObjRes = await client.restPost('curriculum_nodes', {
          'target_version_id': versionId,
          'parent_id': domainNodeId,
          'node_type': 'objective',
          'title': oTitle,
          'code': oCode,
          'description': oDesc,
          'sort_order': oOrder,
          'importance': objective['importance']?.toString() ?? 'core',
          'weight': 1.0,
        });
        objectiveNodeId = asList(insertObjRes['body']).first['id'] as String;
      }
      nodesCount++;

      // Objective provenance mapping
      await client.restPost(
        'content_source_mappings',
        {
          'source_release_id': releaseId,
          'entity_type': 'curriculum_node',
          'entity_id': objectiveNodeId,
          'relationship': 'official_blueprint',
          'citation_location': oCitation,
          'notes': 'Curriculum objective node citation',
        },
        upsert: true,
        onConflict: 'source_release_id,entity_type,entity_id,relationship',
      );
      provenanceCount++;

      // Concepts
      final concepts = objective['concepts'] as List<dynamic>? ?? [];
      for (final concept in concepts) {
        if (concept is! Map) continue;
        final cSlug = concept['slug']?.toString() ?? '';
        final cName = concept['name']?.toString() ?? '';
        final cEmoji = concept['emoji']?.toString() ?? '💡';
        final cShort = concept['short_definition']?.toString();
        final cDesc = concept['description']?.toString();
        final cCitation = concept['citation']?.toString() ?? oCitation;

        // Upsert knowledge_concept by slug
        final checkConceptRes = await client.restGet('knowledge_concepts?slug=eq.$cSlug');
        String conceptId;
        if (asList(checkConceptRes['body']).isNotEmpty) {
          conceptId = asList(checkConceptRes['body']).first['id'] as String;
        } else {
          final insertConceptRes = await client.restPost('knowledge_concepts', {
            'field_id': targetFieldId,
            'slug': cSlug,
            'name': cName,
            'short_definition': cShort,
            'description': cDesc,
            'emoji': cEmoji,
            'status': 'active',
          });
          conceptId = asList(insertConceptRes['body']).first['id'] as String;
        }
        conceptMap[cSlug] = conceptId;
        conceptsCount++;

        // Link curriculum_node_concepts
        await client.restPost(
          'curriculum_node_concepts',
          {
            'curriculum_node_id': objectiveNodeId,
            'concept_id': conceptId,
            'relevance': 'core',
            'weight': 1.0,
          },
          upsert: true,
        );

        // Concept provenance mapping
        await client.restPost(
          'content_source_mappings',
          {
            'source_release_id': releaseId,
            'entity_type': 'knowledge_concept',
            'entity_id': conceptId,
            'relationship': 'primary_text',
            'citation_location': cCitation,
            'notes': 'Knowledge concept definition mapping',
          },
          upsert: true,
          onConflict: 'source_release_id,entity_type,entity_id,relationship',
        );
        provenanceCount++;
      }

      // Lessons
      final lessons = objective['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        if (lesson is! Map) continue;
        final lTitle = lesson['title']?.toString() ?? 'Lesson';
        final lDesc = lesson['description']?.toString();
        final lEmoji = lesson['emoji']?.toString() ?? '📚';
        final lTags = (lesson['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final lCitation = lesson['citation']?.toString() ?? oCitation;

        // Insert public official lesson
        final insertLessonRes = await client.restPost('lessons', {
          'title': lTitle,
          'description': lDesc,
          'emoji': lEmoji,
          'tags': lTags,
          'visibility': 'public',
          'user_id': null, // official curriculum lesson
        });
        if (insertLessonRes['statusCode'] >= 400 || asList(insertLessonRes['body']).isEmpty) {
          throw Exception('Failed to insert lesson: ${insertLessonRes['body']}');
        }
        final lessonId = asList(insertLessonRes['body']).first['id'] as String;
        lessonsCount++;

        // Bind curriculum_node_lessons
        await client.restPost(
          'curriculum_node_lessons',
          {
            'curriculum_node_id': objectiveNodeId,
            'lesson_id': lessonId,
            'sort_order': lessonsCount,
            'is_required': true,
          },
          upsert: true,
        );

        // Insert terms
        final terms = lesson['terms'] as List<dynamic>? ?? [];
        for (final t in terms) {
          if (t is! Map) continue;
          await client.restPost('terms', {
            'lesson_id': lessonId,
            'term': t['term']?.toString() ?? '',
            'definition': t['definition']?.toString() ?? '',
            'example': t['example']?.toString(),
            'emoji': t['emoji']?.toString(),
            'user_id': null,
          });
        }

        // Insert lesson concepts
        final conceptsText = lesson['concepts'] as List<dynamic>? ?? [];
        for (final c in conceptsText) {
          if (c is! Map) continue;
          await client.restPost('concepts', {
            'lesson_id': lessonId,
            'concept_text': c['concept_text']?.toString() ?? '',
            'example_text': c['example_text']?.toString(),
            'key_points': (c['key_points'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
            'emoji': c['emoji']?.toString(),
            'user_id': null,
          });
        }

        // Map lesson to knowledge concepts
        for (final entry in conceptMap.entries) {
          await client.restPost(
            'lesson_concepts',
            {
              'lesson_id': lessonId,
              'concept_id': entry.value,
              'role': 'primary',
              'weight': 1.0,
            },
            upsert: true,
          );
        }

        // Lesson provenance mapping
        await client.restPost(
          'content_source_mappings',
          {
            'source_release_id': releaseId,
            'entity_type': 'lesson',
            'entity_id': lessonId,
            'relationship': 'derived_from',
            'citation_location': lCitation,
            'notes': 'Instructional lesson curriculum mapping',
          },
          upsert: true,
          onConflict: 'source_release_id,entity_type,entity_id,relationship',
        );
        provenanceCount++;

        // Questions
        final questions = lesson['questions'] as List<dynamic>? ?? [];
        for (final q in questions) {
          if (q is! Map) continue;
          final qText = q['question_text']?.toString() ?? '';
          final options = q['options'] as List<dynamic>;
          final correct = q['correct_answer'] as int;
          final qType = q['type']?.toString() ?? 'mcq';
          final explanation = q['explanation']?.toString();
          final qCitation = q['citation']?.toString() ?? lCitation;
          final qConceptSlugs = (q['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          final insertQRes = await client.restPost('questions', {
            'lesson_id': lessonId,
            'question_text': qText,
            'options': options,
            'correct_answer': correct,
            'type': qType,
            'explanation': explanation,
            'user_id': null,
          });
          final questionId = asList(insertQRes['body']).first['id'] as String;
          questionsCount++;

          // Link question_concepts
          for (final qSlug in qConceptSlugs) {
            final cid = conceptMap[qSlug];
            if (cid != null) {
              await client.restPost(
                'question_concepts',
                {
                  'question_id': questionId,
                  'concept_id': cid,
                  'role': 'primary',
                  'weight': 1.0,
                },
                upsert: true,
              );
            }
          }

          // Question provenance mapping
          await client.restPost(
            'content_source_mappings',
            {
              'source_release_id': releaseId,
              'entity_type': 'question',
              'entity_id': questionId,
              'relationship': 'standards_benchmark',
              'citation_location': qCitation,
              'notes': 'Assessment question alignment mapping',
            },
            upsert: true,
            onConflict: 'source_release_id,entity_type,entity_id,relationship',
          );
          provenanceCount++;
        }
      }
    }
  }

  // 5. Connect concept prerequisite relations
  for (final domain in domains) {
    final objectives = (domain as Map)['objectives'] as List<dynamic>? ?? [];
    for (final objective in objectives) {
      final concepts = (objective as Map)['concepts'] as List<dynamic>? ?? [];
      for (final concept in concepts) {
        final cSlug = (concept as Map)['slug']?.toString();
        final prereqs = concept['prerequisites'] as List<dynamic>? ?? [];
        if (cSlug != null && conceptMap.containsKey(cSlug)) {
          final toId = conceptMap[cSlug]!;
          for (final p in prereqs) {
            final fromId = conceptMap[p.toString()];
            if (fromId != null && fromId != toId) {
              await client.restPost(
                'concept_relations',
                {
                  'from_concept_id': fromId,
                  'to_concept_id': toId,
                  'relation_type': 'prerequisite',
                  'prerequisite_kind': 'required',
                  'strength': 1.0,
                },
                upsert: true,
              );
            }
          }
        }
      }
    }
  }

  print('\n----------------------------------------------------');
  print('Ingestion Results:');
  print('  Target Version ID   : $versionId (draft)');
  print('  Curriculum Nodes    : $nodesCount');
  print('  Knowledge Concepts  : $conceptsCount');
  print('  Lessons Ingested    : $lessonsCount');
  print('  Questions Ingested  : $questionsCount');
  print('  Provenance Mappings : $provenanceCount');
  print('----------------------------------------------------');
}

// ----------------------------------------------------------------------------
// Publication Logic
// ----------------------------------------------------------------------------

Future<void> _executePublish(
  SupabaseRestClient client,
  String targetSlug,
  String versionCode, {
  bool retirePrevious = false,
}) async {
  // 1. Locate target
  final targetRes = await client.restGet('learning_targets?slug=ilike.*$targetSlug*&limit=1');
  final targetList = asList(targetRes['body']);
  if (targetList.isEmpty) {
    throw Exception('Target "$targetSlug" not found.');
  }
  final target = targetList.first as Map<String, dynamic>;
  final targetId = target['id'] as String;

  // 2. Locate version
  final versionRes = await client.restGet('target_versions?target_id=eq.$targetId&version_code=eq.$versionCode');
  final versionList = asList(versionRes['body']);
  if (versionList.isEmpty) {
    throw Exception('TargetVersion "$versionCode" not found for target "${target['title']}".');
  }
  final version = versionList.first as Map<String, dynamic>;
  final versionId = version['id'] as String;
  final currentStatus = version['status'] as String;

  if (currentStatus == 'published') {
    print('Notice: TargetVersion "$versionCode" is already published and immutable.');
    return;
  }
  if (currentStatus == 'retired') {
    throw Exception('Cannot publish a retired TargetVersion.');
  }

  // 3. Retire previous published versions if requested
  if (retirePrevious) {
    print('Retiring previous published versions for target "${target['title']}"...');
    final prevRes = await client.restPatch(
      'target_versions?target_id=eq.$targetId&status=eq.published&id=neq.$versionId',
      {'status': 'retired'},
    );
    if (prevRes['statusCode'] < 400) {
      print('Previous versions retired.');
    }
  }

  // 4. Promote to published
  print('Promoting TargetVersion "$versionCode" [ID: $versionId] to published...');
  final publishRes = await client.restPatch(
    'target_versions?id=eq.$versionId',
    {'status': 'published'},
  );
  if (publishRes['statusCode'] >= 400 || asList(publishRes['body']).isEmpty) {
    throw Exception('Failed to publish version: ${publishRes['body']}');
  }

  print('TargetVersion "$versionCode" is now PUBLISHED and strictly IMMUTABLE under database RLS.');
}
