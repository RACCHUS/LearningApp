import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Content Ingestion & Provenance CLI
///
/// Implements the authoritative curriculum ingestion pipeline:
///   Official source blueprint -> Source manifest -> Draft TargetVersion
///   -> Curriculum nodes -> Canonical concepts & Aliases resolution -> Lesson blocks & Assessments
///   -> Provenance mappings -> Automated validation -> Review Ready -> Publish TargetVersion
///
/// Usage:
///   # 1. Validate manifest without database writes:
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --manifest content/security_plus_sy0_701.yaml \
///     --dry-run
///
///   # 2. Batch validate an entire directory of manifests:
///   dart run tool/ingest_curriculum.dart \
///     --dir content/ \
///     --dry-run
///
///   # 3. Ingest manifest into a draft TargetVersion (service role):
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --manifest content/security_plus_sy0_701.yaml \
///     --apply
///
///   # 4. Batch ingest directory of manifests into draft TargetVersions:
///   dart run tool/ingest_curriculum.dart \
///     --dir content/ \
///     --apply
///
///   # 5. Advance draft TargetVersion to review_ready staging status:
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --stage-review
///
///   # 6. Promote draft or review_ready TargetVersion to published immutable status:
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
      throw Exception('Manifest must have a top-level map structure: $path');
    }
    return dartObj.cast<String, dynamic>();
  } else {
    final dynamic jsonNode = jsonDecode(content);
    if (jsonNode is! Map) {
      throw Exception('Manifest must have a top-level map structure: $path');
    }
    return jsonNode.cast<String, dynamic>();
  }
}

List<String> _findManifestFiles(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    throw Exception('Directory not found: $dirPath');
  }
  final files = <String>[];
  for (final entity in dir.listSync(recursive: false)) {
    if (entity is File) {
      final name = entity.path.toLowerCase();
      if ((name.endsWith('.yaml') || name.endsWith('.yml') || name.endsWith('.json')) &&
          !name.endsWith('.schema.json')) {
        files.add(entity.path);
      }
    }
  }
  files.sort();
  return files;
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

  Future<Map<String, dynamic>> restRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/$functionName');
    final req = await _client.postUrl(uri);
    req.headers.set('apikey', key);
    req.headers.set('Authorization', 'Bearer $key');
    req.headers.set('Content-Type', 'application/json; charset=utf-8');
    req.headers.set('Accept', 'application/json');

    final payload = jsonEncode(params);
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
  String? dirPath;
  bool isDryRun = false;
  bool isApply = false;
  bool isStageReview = false;
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
    } else if (arg == '--dir' && i + 1 < args.length) {
      dirPath = args[++i];
    } else if (arg == '--dry-run') {
      isDryRun = true;
    } else if (arg == '--apply') {
      isApply = true;
    } else if (arg == '--stage-review') {
      isStageReview = true;
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

  final selectedModes = [isDryRun, isApply, isStageReview, isPublish].where((b) => b).length;
  if (selectedModes != 1) {
    print('Error: You must specify exactly one mode:');
    print('  --dry-run      : Validate manifest(s) and check blueprint alignment');
    print('  --apply        : Ingest manifest(s) into draft TargetVersion(s) (service role)');
    print('  --stage-review : Promote draft TargetVersion to review_ready staging status');
    print('  --publish      : Promote draft/review_ready TargetVersion to published immutable status');
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

  // --------------------------------------------------------------------------
  // BATCH / DIRECTORY MODE
  // --------------------------------------------------------------------------
  if (dirPath != null) {
    print('Batch Directory: $dirPath');
    print('Mode           : ${isDryRun ? "DRY-RUN (Batch Validation)" : "APPLY (Batch Ingestion)"}');
    print('Endpoint       : $supabaseUrl');

    final manifestFiles = _findManifestFiles(dirPath);
    if (manifestFiles.isEmpty) {
      print('❌ No manifest files (.yaml, .yml, .json) found in $dirPath');
      exit(1);
    }
    print('Discovered ${manifestFiles.length} manifest file(s):');
    for (final f in manifestFiles) {
      print('  • $f');
    }

    // Phase 1: Validate ALL manifests in batch before writing anything
    print('\n====================================================');
    print('  Phase 1: Validating All Manifests in Batch');
    print('====================================================');
    final parsedManifests = <String, Map<String, dynamic>>{};
    final errors = <String>[];

    for (final f in manifestFiles) {
      try {
        final m = _parseManifest(f);
        _executeDryRun(m, null, null, filePath: f);
        parsedManifests[f] = m;
      } catch (e) {
        errors.add('Failed $f: $e');
      }
    }

    if (errors.isNotEmpty) {
      print('\n❌ Batch Validation FAILED. Encountered ${errors.length} error(s):');
      for (final err in errors) {
        print('  • $err');
      }
      print('\nBatch aborted. Zero changes written to database.');
      exit(1);
    }

    print('\n✅ Phase 1: All ${manifestFiles.length} manifest(s) passed validation cleanly!');

    // Phase 2: Produce Unified Ingestion Plan
    print('\n====================================================');
    print('  Phase 2: Ingestion Plan');
    print('====================================================');
    for (final entry in parsedManifests.entries) {
      final f = entry.key;
      final m = entry.value;
      final targetInfo = m['target'] as Map<String, dynamic>? ?? {};
      final sRel = m['source_release'] as Map<String, dynamic>? ?? {};
      final slug = targetInfo['slug']?.toString() ?? 'unknown-target';
      final vCode = targetInfo['version_code']?.toString() ?? sRel['version']?.toString() ?? 'v1';
      final domains = m['domains'] as List<dynamic>? ?? [];
      final stimuli = m['stimuli'] as List<dynamic>? ?? [];
      print('  Target: $slug (Version: $vCode)');
      print('    File: $f');
      print('    Domains: ${domains.length} | Stimuli: ${stimuli.length}');
    }

    if (isDryRun) {
      print('\n✅ Batch Dry-Run PASSED! All manifests conform to curriculum specifications.');
      print('Run with --apply to execute batch database ingestion:');
      print('  dart run tool/ingest_curriculum.dart --dir $dirPath --apply');
      exit(0);
    }

    // Phase 3: Apply All Manifests
    if (serviceKey == null || serviceKey.isEmpty) {
      print('\n❌ SECURITY ERROR: Privileged Ingestion requires a valid service-role key.');
      exit(1);
    }

    final client = SupabaseRestClient(supabaseUrl, serviceKey);
    print('\n====================================================');
    print('  Phase 3: Applying Batch Database Ingestion');
    print('====================================================');

    for (final entry in parsedManifests.entries) {
      final f = entry.key;
      final m = entry.value;
      final targetInfo = m['target'] as Map<String, dynamic>? ?? {};
      final sRel = m['source_release'] as Map<String, dynamic>? ?? {};
      final slug = targetInfo['slug']?.toString();
      final vCode = targetInfo['version_code']?.toString() ?? sRel['version']?.toString() ?? 'v1';
      if (slug == null || slug.isEmpty) {
        throw Exception('Manifest $f missing target.slug');
      }

      print('\n--- Ingesting: $slug ($vCode) from $f ---');
      await _executeApply(client, m, slug, vCode);
    }

    print('\n====================================================');
    print('✅ Batch Ingestion Complete! All manifests successfully ingested into draft status.');
    print('====================================================');
    exit(0);
  }

  // --------------------------------------------------------------------------
  // SINGLE MANIFEST MODE
  // --------------------------------------------------------------------------
  if (targetArg == null || targetArg.isEmpty) {
    print('Error: Missing required --target <slug> (or use --dir <directory>)');
    exit(1);
  }
  if (versionArg == null || versionArg.isEmpty) {
    print('Error: Missing required --version <version_code>');
    exit(1);
  }
  if (!isPublish && !isStageReview && (manifestPath == null || manifestPath.isEmpty)) {
    print('Error: Missing required --manifest <path> for dry-run or apply mode');
    exit(1);
  }

  print('Target Slug  : $targetArg');
  print('Target Vers  : $versionArg');
  if (manifestPath != null) print('Manifest File: $manifestPath');
  print('Mode         : ${isDryRun ? "DRY-RUN" : isApply ? "APPLY (Draft Ingestion)" : isStageReview ? "STAGE-REVIEW" : "PUBLISH"}');
  print('Endpoint     : $supabaseUrl');

  Map<String, dynamic>? manifest;
  if (manifestPath != null) {
    try {
      manifest = _parseManifest(manifestPath);
    } catch (e) {
      print('❌ Failed to parse manifest: $e');
      exit(1);
    }
  }

  // MODE 1: DRY RUN
  if (isDryRun) {
    print('\n--- Executing Manifest Dry-Run Validation ---');
    _executeDryRun(manifest!, targetArg, versionArg, filePath: manifestPath);
    print('\n✅ Dry-Run Validation PASSED cleanly!');
    print('Manifest is well-structured and ready for:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --manifest $manifestPath --apply');
    exit(0);
  }

  // MODES 2, 3, 4: Require Service-Role Key
  if (serviceKey == null || serviceKey.isEmpty) {
    print('\n❌ SECURITY ERROR: Privileged Ingestion, Staging & Publication requires a valid service-role key.');
    print('Official learning targets (created_by = NULL) are protected by database RLS.');
    print('Provide the key via:');
    print('  - SUPABASE_SERVICE_ROLE_KEY environment variable');
    print('  - SUPABASE_SERVICE_ROLE_KEY in .env');
    print('  - --service-key CLI flag');
    exit(1);
  }

  final client = SupabaseRestClient(supabaseUrl, serviceKey);

  // MODE 2: APPLY (Ingest into Draft TargetVersion)
  if (isApply) {
    print('\n--- Executing Draft TargetVersion Ingestion ---');
    await _executeApply(client, manifest!, targetArg, versionArg);
    print('\n✅ Ingestion into draft version completed successfully!');
    print('Next step: Advance to review staging or publish:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --stage-review');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --publish');
    exit(0);
  }

  // MODE 3: STAGE-REVIEW (Promote to review_ready)
  if (isStageReview) {
    print('\n--- Executing TargetVersion Promotion to Review-Ready ---');
    await _executeStageReview(client, targetArg, versionArg);
    print('\n✅ Staging complete! TargetVersion is now review_ready for QA and beta evaluation.');
    exit(0);
  }

  // MODE 4: PUBLISH (Promote to published immutable)
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
  String? targetSlug,
  String? versionCode, {
  String? filePath,
}) {
  // 1. Source release
  final sourceRelease = manifest['source_release'] as Map<String, dynamic>?;
  if (sourceRelease == null) {
    throw Exception('Missing "source_release" block in manifest ($filePath)');
  }
  final publisher = sourceRelease['publisher'] as String?;
  final title = sourceRelease['title'] as String?;
  final version = sourceRelease['version'] as String?;
  if (publisher == null || title == null || version == null) {
    throw Exception('"source_release" must have publisher, title, and version ($filePath)');
  }

  // 2. Target info
  final target = manifest['target'] as Map<String, dynamic>?;
  if (target == null) {
    throw Exception('Missing "target" block in manifest ($filePath)');
  }
  final manifestSlug = target['slug'] as String?;
  if (manifestSlug == null || manifestSlug.isEmpty) {
    throw Exception('Target must have a "slug" property ($filePath)');
  }

  // 3. Shared Stimuli (if present)
  final stimuli = manifest['stimuli'] as List<dynamic>? ?? [];
  final stimuliKeys = <String>{};
  for (final stim in stimuli) {
    if (stim is! Map) continue;
    final sKey = stim['id']?.toString() ?? stim['slug']?.toString();
    final sTitle = stim['title']?.toString();
    final sType = stim['stimulus_type']?.toString();
    if (sKey == null || sTitle == null || sType == null) {
      throw Exception('Stimulus missing id/slug, title, or stimulus_type');
    }
    stimuliKeys.add(sKey);
  }

  // 4. Domains & Objectives hierarchy
  final domains = manifest['domains'] as List<dynamic>? ?? [];
  if (domains.isEmpty) {
    throw Exception('Manifest must have at least one domain under "domains" ($filePath)');
  }

  int totalObjectives = 0;
  int totalConcepts = 0;
  int totalLessons = 0;
  int totalBlocks = 0;
  int totalLegacyQuestions = 0;
  int totalAssessmentItems = 0;
  final declaredConceptSlugs = <String>{};
  final referencedPrereqSlugs = <String>{};

  for (final domain in domains) {
    if (domain is! Map) continue;
    if (domain['code'] == null) {
      throw Exception('Domain missing code ($filePath)');
    }

    final objectives = domain['objectives'] as List<dynamic>? ?? [];
    totalObjectives += objectives.length;

    for (final objective in objectives) {
      if (objective is! Map) continue;
      final oCode = objective['code']?.toString() ?? '?';

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
      }

      // Lessons
      final lessons = objective['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        if (lesson is! Map) continue;
        totalLessons++;

        // Lesson blocks (ordered document model)
        final blocks = lesson['blocks'] as List<dynamic>? ?? [];
        totalBlocks += blocks.length;

        // Legacy questions
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
          totalLegacyQuestions++;
        }

        // Extensible assessment items
        final assessmentItems = lesson['assessment_items'] as List<dynamic>? ?? [];
        for (final item in assessmentItems) {
          if (item is! Map) continue;
          final prompt = item['prompt']?.toString() ?? '';
          final interactionType = item['interaction_type']?.toString();
          if (prompt.isEmpty) throw Exception('Assessment item prompt cannot be empty');
          if (interactionType == null || interactionType.isEmpty) {
            throw Exception('Assessment item missing interaction_type: "$prompt"');
          }
          final sRef = item['stimulus_id']?.toString() ?? item['stimulus_key']?.toString();
          if (sRef != null && !stimuliKeys.contains(sRef)) {
            print('  ⚠️ Warning: Assessment item references stimulus "$sRef" which is not defined in manifest stimuli.');
          }
          totalAssessmentItems++;
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

  print('Manifest Summary (${filePath ?? manifestSlug}):');
  print('  Publisher        : $publisher ("$title" - $version)');
  print('  Target           : $manifestSlug');
  print('  Domains          : ${domains.length}');
  print('  Objectives       : $totalObjectives');
  print('  Concepts         : $totalConcepts');
  print('  Shared Stimuli   : ${stimuli.length}');
  print('  Lessons          : $totalLessons');
  print('  Lesson Blocks    : $totalBlocks');
  print('  Assessment Items : $totalAssessmentItems');
  print('  Legacy Questions : $totalLegacyQuestions');
}

// ----------------------------------------------------------------------------
// Canonical Concept Resolution
// ----------------------------------------------------------------------------

Future<Map<String, dynamic>> _resolveOrInsertConcept(
  SupabaseRestClient client,
  String slug,
  String name,
  String? targetFieldId,
  Map<String, dynamic> conceptData,
) async {
  // 1. Invoke database RPC resolve_canonical_concept
  final rpcRes = await client.restRpc('resolve_canonical_concept', {
    'p_slug': slug,
    'p_name': name,
  });

  final matches = asList(rpcRes['body']);
  if (matches.isNotEmpty) {
    final match = matches.first as Map<String, dynamic>;
    final matchType = match['match_type'] as String;
    final matchedId = match['id'] as String;
    final canonicalSlug = match['slug'] as String;
    print('      [Canonical Concept Resolved ($matchType)] "$name" ($slug) -> canonical slug "$canonicalSlug" [ID: $matchedId]');
    return {'id': matchedId, 'slug': canonicalSlug, 'isNew': false};
  }

  // 2. If not found, insert new knowledge_concept with aliases
  final cEmoji = conceptData['emoji']?.toString() ?? '💡';
  final cShort = conceptData['short_definition']?.toString();
  final cDesc = conceptData['description']?.toString();
  final rawAliases = conceptData['aliases'] as List<dynamic>? ?? [];
  final aliases = rawAliases.map((e) => e.toString()).toList();

  final insertConceptRes = await client.restPost('knowledge_concepts', {
    'field_id': targetFieldId,
    'slug': slug,
    'name': name,
    'short_definition': cShort,
    'description': cDesc,
    'emoji': cEmoji,
    'aliases': aliases,
    'status': 'active',
  });

  final created = asList(insertConceptRes['body']);
  if (insertConceptRes['statusCode'] >= 400 || created.isEmpty) {
    throw Exception('Failed to insert knowledge concept: ${insertConceptRes['body']}');
  }
  final newId = created.first['id'] as String;
  print('      [Canonical Concept Created] "$name" ($slug) [ID: $newId]');
  return {'id': newId, 'slug': slug, 'isNew': true};
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
    print('Reusing existing $status TargetVersion [ID: $versionId]');
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

  // 4. Ingest Shared Stimuli (if defined)
  final stimuli = manifest['stimuli'] as List<dynamic>? ?? [];
  final stimulusIdMap = <String, String>{}; // key -> uuid
  int stimuliCount = 0;

  for (final stim in stimuli) {
    if (stim is! Map) continue;
    final stimKey = stim['id']?.toString() ?? stim['slug']?.toString() ?? 'stim-$stimuliCount';
    final stimType = stim['stimulus_type']?.toString() ?? 'scenario';
    final stimTitle = stim['title']?.toString() ?? 'Stimulus';
    final stimBody = stim['body']?.toString();
    final stimData = (stim['structured_data'] as Map?)?.cast<String, dynamic>() ?? {};
    final stimAssets = (stim['asset_refs'] as List?)?.toList() ?? [];
    final stimMeta = (stim['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final stimCitation = stim['citation']?.toString() ?? 'Official Stimulus';

    final insertStimRes = await client.restPost('assessment_stimuli', {
      'stimulus_type': stimType,
      'title': stimTitle,
      'body': stimBody,
      'structured_data': stimData,
      'asset_refs': stimAssets,
      'metadata': stimMeta,
      'created_by': null,
    });
    final sList = asList(insertStimRes['body']);
    if (insertStimRes['statusCode'] >= 400 || sList.isEmpty) {
      throw Exception('Failed to insert assessment_stimuli: ${insertStimRes['body']}');
    }
    final stimId = sList.first['id'] as String;
    stimulusIdMap[stimKey] = stimId;
    stimuliCount++;

    await client.restPost(
      'content_source_mappings',
      {
        'source_release_id': releaseId,
        'entity_type': 'assessment_stimulus',
        'entity_id': stimId,
        'relationship': 'official_blueprint',
        'citation_location': stimCitation,
        'notes': 'Assessment stimulus vignette mapping',
      },
      upsert: true,
      onConflict: 'source_release_id,entity_type,entity_id,relationship',
    );
  }

  // 5. Ingest Domains, Objectives, Concepts, Lessons, Blocks & Assessment Items
  final domains = manifest['domains'] as List<dynamic>? ?? [];
  final conceptMap = <String, String>{}; // declared slug -> resolved concept_id

  int nodesCount = 0;
  int conceptsCount = 0;
  int lessonsCount = 0;
  int blocksCount = 0;
  int itemsCount = 0;
  int questionsCount = 0;
  int provenanceCount = 1 + stimuliCount;

  for (final domain in domains) {
    if (domain is! Map) continue;
    final dCode = domain['code']?.toString();
    final dTitle = domain['title']?.toString() ?? '';
    final dDesc = domain['description']?.toString();
    final dWeight = (domain['weight'] as num?)?.toDouble() ?? 1.0;
    final dOrder = (domain['sort_order'] as num?)?.toInt() ?? (nodesCount + 1);
    final dCitation = domain['citation']?.toString() ?? 'Domain $dCode';

    // Domain curriculum_node
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

    // Objectives
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

      // Canonical Concept Resolution & Linking
      final concepts = objective['concepts'] as List<dynamic>? ?? [];
      for (final concept in concepts) {
        if (concept is! Map) continue;
        final cSlug = concept['slug']?.toString() ?? '';
        final cName = concept['name']?.toString() ?? '';
        final cCitation = concept['citation']?.toString() ?? oCitation;

        // Use canonical concept resolver
        final resolved = await _resolveOrInsertConcept(
          client,
          cSlug,
          cName,
          targetFieldId,
          concept.cast<String, dynamic>(),
        );
        final conceptId = resolved['id'] as String;
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
          'user_id': null,
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

        // Ordered Lesson Blocks (if present)
        final blocks = lesson['blocks'] as List<dynamic>? ?? [];
        int blockOrder = 0;
        for (final b in blocks) {
          if (b is! Map) continue;
          blockOrder++;
          final bType = b['block_type']?.toString() ?? 'markdown';
          final bContent = (b['content'] as Map?)?.cast<String, dynamic>() ?? {};
          final bMeta = (b['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
          final bOrder = (b['sort_order'] as num?)?.toInt() ?? blockOrder;

          final insertBlockRes = await client.restPost('lesson_blocks', {
            'lesson_id': lessonId,
            'sort_order': bOrder,
            'block_type': bType,
            'content': bContent,
            'metadata': bMeta,
          });
          final bList = asList(insertBlockRes['body']);
          if (insertBlockRes['statusCode'] >= 400 || bList.isEmpty) {
            throw Exception('Failed to insert lesson_block: ${insertBlockRes['body']}');
          }
          final blockId = bList.first['id'] as String;
          blocksCount++;

          await client.restPost(
            'content_source_mappings',
            {
              'source_release_id': releaseId,
              'entity_type': 'lesson_block',
              'entity_id': blockId,
              'relationship': 'derived_from',
              'citation_location': lCitation,
              'notes': 'Instructional lesson block document mapping',
            },
            upsert: true,
            onConflict: 'source_release_id,entity_type,entity_id,relationship',
          );
          provenanceCount++;
        }

        // Legacy Terms (backward compatibility)
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

        // Lesson Knowledge Concept Junction
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

        // Lesson Provenance
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

        // Extensible Assessment Items
        final assessmentItems = lesson['assessment_items'] as List<dynamic>? ?? [];
        for (final item in assessmentItems) {
          if (item is! Map) continue;
          final iType = item['interaction_type']?.toString() ?? 'single_choice';
          final iPrompt = item['prompt']?.toString() ?? '';
          final iRespSpec = (item['response_spec'] as Map?)?.cast<String, dynamic>() ?? {};
          final iScoreSpec = (item['scoring_spec'] as Map?)?.cast<String, dynamic>() ?? {};
          final iExplanation = item['explanation']?.toString();
          final iDifficulty = item['difficulty']?.toString() ?? 'intermediate';
          final iCogLevel = item['cognitive_level']?.toString();
          final iMeta = (item['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
          final iCitation = item['citation']?.toString() ?? lCitation;
          final sKey = item['stimulus_id']?.toString() ?? item['stimulus_key']?.toString();
          final sUuid = sKey != null ? stimulusIdMap[sKey] : null;

          final insertItemRes = await client.restPost('assessment_items', {
            'lesson_id': lessonId,
            'stimulus_id': sUuid,
            'interaction_type': iType,
            'prompt': iPrompt,
            'response_spec': iRespSpec,
            'scoring_spec': iScoreSpec,
            'explanation': iExplanation,
            'difficulty': iDifficulty,
            'cognitive_level': iCogLevel,
            'metadata': iMeta,
            'user_id': null,
          });
          final iList = asList(insertItemRes['body']);
          if (insertItemRes['statusCode'] >= 400 || iList.isEmpty) {
            throw Exception('Failed to insert assessment_item: ${insertItemRes['body']}');
          }
          final itemId = iList.first['id'] as String;
          itemsCount++;

          // Item concept links
          final itemConceptSlugs = (item['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          for (final slug in itemConceptSlugs) {
            final cid = conceptMap[slug];
            if (cid != null) {
              await client.restPost(
                'assessment_item_concepts',
                {
                  'assessment_item_id': itemId,
                  'concept_id': cid,
                  'role': 'primary',
                  'weight': 1.0,
                },
                upsert: true,
              );
            }
          }

          // Provenance mapping
          await client.restPost(
            'content_source_mappings',
            {
              'source_release_id': releaseId,
              'entity_type': 'assessment_item',
              'entity_id': itemId,
              'relationship': 'standards_benchmark',
              'citation_location': iCitation,
              'notes': 'Extensible assessment item alignment mapping',
            },
            upsert: true,
            onConflict: 'source_release_id,entity_type,entity_id,relationship',
          );
          provenanceCount++;
        }

        // Legacy Questions (backward compatibility)
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

  // 6. Connect concept prerequisite relations
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

  // 7. Version-to-Version Concept Mappings (if declared)
  final conceptMappings = manifest['concept_mappings'] as List<dynamic>? ?? [];
  for (final cm in conceptMappings) {
    if (cm is! Map) continue;
    final fromVersionCode = cm['from_version_code']?.toString();
    final fromConceptSlug = cm['from_concept_slug']?.toString();
    final toConceptSlug = cm['to_concept_slug']?.toString();
    final mappingType = cm['mapping_type']?.toString() ?? 'unchanged';
    final weight = (cm['transfer_weight'] as num?)?.toDouble() ?? 1.0;
    if (fromVersionCode != null && fromConceptSlug != null && toConceptSlug != null) {
      // Find from_target_version
      final fromVRes = await client.restGet('target_versions?target_id=eq.$targetId&version_code=eq.$fromVersionCode');
      final fromVList = asList(fromVRes['body']);
      if (fromVList.isNotEmpty) {
        final fromVid = fromVList.first['id'] as String;
        // Find from_concept
        final fromCRes = await client.restGet('knowledge_concepts?slug=eq.$fromConceptSlug');
        final fromCList = asList(fromCRes['body']);
        final toCid = conceptMap[toConceptSlug];
        if (fromCList.isNotEmpty && toCid != null) {
          final fromCid = fromCList.first['id'] as String;
          await client.restPost(
            'target_version_concept_mappings',
            {
              'from_target_version_id': fromVid,
              'from_concept_id': fromCid,
              'to_target_version_id': versionId,
              'to_concept_id': toCid,
              'mapping_type': mappingType,
              'transfer_weight': weight,
            },
            upsert: true,
          );
        }
      }
    }
  }

  print('\n----------------------------------------------------');
  print('Ingestion Results:');
  print('  Target Version ID    : $versionId (draft)');
  print('  Curriculum Nodes     : $nodesCount');
  print('  Knowledge Concepts   : $conceptsCount');
  print('  Shared Stimuli       : $stimuliCount');
  print('  Lessons Ingested     : $lessonsCount');
  print('  Lesson Blocks        : $blocksCount');
  print('  Assessment Items     : $itemsCount');
  print('  Legacy Questions     : $questionsCount');
  print('  Provenance Mappings  : $provenanceCount');
  print('----------------------------------------------------');
}

// ----------------------------------------------------------------------------
// Staging & Publication Logic
// ----------------------------------------------------------------------------

Future<void> _executeStageReview(
  SupabaseRestClient client,
  String targetSlug,
  String versionCode,
) async {
  final targetRes = await client.restGet('learning_targets?slug=ilike.*$targetSlug*&limit=1');
  final targetList = asList(targetRes['body']);
  if (targetList.isEmpty) {
    throw Exception('Target "$targetSlug" not found.');
  }
  final target = targetList.first as Map<String, dynamic>;
  final targetId = target['id'] as String;

  final versionRes = await client.restGet('target_versions?target_id=eq.$targetId&version_code=eq.$versionCode');
  final versionList = asList(versionRes['body']);
  if (versionList.isEmpty) {
    throw Exception('TargetVersion "$versionCode" not found.');
  }
  final version = versionList.first as Map<String, dynamic>;
  final versionId = version['id'] as String;
  final currentStatus = version['status'] as String;

  if (currentStatus == 'review_ready') {
    print('Notice: TargetVersion "$versionCode" is already in review_ready status.');
    return;
  }
  if (currentStatus == 'published' || currentStatus == 'retired') {
    throw Exception('Cannot change status of a $currentStatus TargetVersion.');
  }

  print('Promoting TargetVersion "$versionCode" [ID: $versionId] to review_ready...');
  final updateRes = await client.restPatch(
    'target_versions?id=eq.$versionId',
    {'status': 'review_ready'},
  );
  if (updateRes['statusCode'] >= 400 || asList(updateRes['body']).isEmpty) {
    throw Exception('Failed to promote to review_ready: ${updateRes['body']}');
  }
  print('TargetVersion "$versionCode" is now staged as REVIEW_READY for QA and verification.');
}

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
