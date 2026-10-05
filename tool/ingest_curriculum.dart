import 'dart:convert';
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';
import 'lint_manifest.dart';

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
///   # 6. Promote review_ready TargetVersion to published immutable status:
///   dart run tool/ingest_curriculum.dart \
///     --target cert-comptia-security-plus \
///     --version SY0-701 \
///     --publish
///
/// Note: Publication strictly requires "review_ready" staging status.

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

void _validateJsonSchema(Map<String, dynamic> manifest, {String? filePath}) {
  final schemaFile = File('content/schema/curriculum_manifest.schema.json');
  if (!schemaFile.existsSync()) {
    throw Exception('JSON Schema contract file not found at ${schemaFile.path}');
  }
  final schemaJson = jsonDecode(schemaFile.readAsStringSync());
  final schema = JsonSchema.create(schemaJson);
  final result = schema.validate(manifest);
  if (!result.isValid) {
    print('\n❌ JSON Schema Validation Errors (${filePath ?? "manifest"}):');
    for (final err in result.errors) {
      print('  • [${err.schemaPath}] ${err.message}');
    }
    throw Exception(
      'Manifest failed formal JSON Schema validation with ${result.errors.length} error(s).',
    );
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
    print('  --dry-run      : Validate manifest(s) against JSON Schema & blueprint alignment');
    print('  --apply        : Ingest manifest(s) into draft TargetVersion(s) (service role)');
    print('  --stage-review : Promote draft TargetVersion to review_ready staging status');
    print('  --publish      : Promote review_ready TargetVersion to published immutable status');
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
    print('  Phase 1: Validating All Manifests in Batch (Schema + Referential)');
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
      final sRel = (m['source_releases'] as List<dynamic>?)?.isNotEmpty == true
          ? (m['source_releases'] as List<dynamic>).first as Map<String, dynamic>
          : m['source_release'] as Map<String, dynamic>? ?? {};
      final slug = targetInfo['slug']?.toString() ?? 'unknown-target';
      final vCode = targetInfo['version_code']?.toString() ?? sRel['version']?.toString() ?? 'v1';
      final domains = m['domains'] as List<dynamic>? ?? [];
      final stimuli = m['stimuli'] as List<dynamic>? ?? [];
      print('  Target: $slug (Version: $vCode)');
      print('    File: $f');
      print('    Domains: ${domains.length} | Root Stimuli: ${stimuli.length}');
    }

    if (isDryRun) {
      print('\n✅ Batch Dry-Run PASSED! All manifests conform to JSON Schema and curriculum specifications.');
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
      final sRel = (m['source_releases'] as List<dynamic>?)?.isNotEmpty == true
          ? (m['source_releases'] as List<dynamic>).first as Map<String, dynamic>
          : m['source_release'] as Map<String, dynamic>? ?? {};
      final slug = targetInfo['slug']?.toString();
      final vCode = targetInfo['version_code']?.toString() ?? sRel['version']?.toString() ?? 'v1';
      if (slug == null || slug.isEmpty) {
        throw Exception('Manifest $f missing target.slug');
      }

      print('\n--- Ingesting: $slug ($vCode) from $f ---');
      await _executeApply(client, m, slug, vCode, filePath: f);
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
    await _executeApply(client, manifest!, targetArg, versionArg, filePath: manifestPath);
    print('\n✅ Ingestion into draft version completed successfully!');
    print('Next step: Advance to review staging or publish:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --stage-review');
    exit(0);
  }

  // MODE 3: STAGE-REVIEW (Promote to review_ready)
  if (isStageReview) {
    print('\n--- Executing TargetVersion Promotion to Review-Ready ---');
    await _executeStageReview(client, targetArg, versionArg);
    print('\n✅ Staging complete! TargetVersion is now review_ready for QA and beta evaluation.');
    print('Next step: Promote to published immutable status:');
    print('  dart run tool/ingest_curriculum.dart --target $targetArg --version $versionArg --publish');
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
  // 1. JSON Schema validation
  _validateJsonSchema(manifest, filePath: filePath);

  // 1.5 Pedagogical Quality & Referential Integrity Linter
  final linter = ManifestLinter();
  linter.lint(filePath ?? 'manifest', manifest);
  if (linter.hasErrors) {
    print('\n❌ Pedagogical Quality Linter Errors (${filePath ?? "manifest"}):');
    for (final issue in linter.issues.where((i) => i.level == 'ERROR')) {
      print('  • $issue');
    }
    throw Exception('Manifest failed pedagogical quality linter (${filePath ?? "manifest"}). Ingestion blocked.');
  }
  if (linter.hasWarnings) {
    print('\n⚠️ Pedagogical Quality Linter Warnings (${filePath ?? "manifest"}):');
    for (final issue in linter.issues.where((i) => i.level == 'WARNING')) {
      print('  • $issue');
    }
  }

  // 2. Source release(s)
  final rawReleases = manifest['source_releases'] as List<dynamic>?;
  final singleRelease = manifest['source_release'] as Map<String, dynamic>?;
  if (rawReleases == null && singleRelease == null) {
    throw Exception('Manifest must have "source_releases" or "source_release" ($filePath)');
  }
  final releases = rawReleases != null
      ? rawReleases.cast<Map<String, dynamic>>()
      : [singleRelease!];

  for (final rel in releases) {
    final pub = rel['publisher'] as String?;
    final title = rel['title'] as String?;
    final ver = rel['version'] as String?;
    if (pub == null || title == null || ver == null) {
      throw Exception('Each source_release must have publisher, title, and version ($filePath)');
    }
  }

  // 3. Target info
  final target = manifest['target'] as Map<String, dynamic>?;
  if (target == null) {
    throw Exception('Missing "target" block in manifest ($filePath)');
  }
  final manifestSlug = target['slug'] as String?;
  if (manifestSlug == null || manifestSlug.isEmpty) {
    throw Exception('Target must have a "slug" property ($filePath)');
  }

  // 4. Collect Stimuli from root, domains, and objectives
  final stimuliKeys = <String>{};
  void registerStimuli(List<dynamic>? stimList, String scope) {
    if (stimList == null) return;
    for (final stim in stimList) {
      if (stim is! Map) continue;
      final sKey = stim['id']?.toString() ?? stim['slug']?.toString();
      final sTitle = stim['title']?.toString();
      final sType = stim['stimulus_type']?.toString();
      if (sKey == null || sTitle == null || sType == null) {
        throw Exception('Stimulus in $scope missing id, title, or stimulus_type');
      }
      stimuliKeys.add(sKey);
    }
  }

  registerStimuli(manifest['stimuli'] as List<dynamic>?, 'root');

  // 5. Domains & Objectives hierarchy
  final domains = manifest['domains'] as List<dynamic>? ?? [];
  if (domains.isEmpty) {
    throw Exception('Manifest must have at least one domain under "domains" ($filePath)');
  }

  int totalObjectives = 0;
  int totalConcepts = 0;
  int totalLessons = 0;
  int totalBlocks = 0;
  int totalFlashcards = 0;
  int totalLegacyQuestions = 0;
  int totalAssessmentItems = 0;
  final declaredConceptSlugs = <String>{};
  final referencedPrereqSlugs = <String>{};

  for (final domain in domains) {
    if (domain is! Map) continue;
    if (domain['code'] == null) {
      throw Exception('Domain missing code ($filePath)');
    }
    registerStimuli(domain['stimuli'] as List<dynamic>?, 'domain ${domain['code']}');

    final objectives = domain['objectives'] as List<dynamic>? ?? [];
    totalObjectives += objectives.length;

    for (final objective in objectives) {
      if (objective is! Map) continue;
      final oCode = objective['code']?.toString() ?? '?';
      registerStimuli(objective['stimuli'] as List<dynamic>?, 'objective $oCode');

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

      // Objective Flashcards
      final flashcards = objective['flashcards'] as List<dynamic>? ?? [];
      for (final fc in flashcards) {
        if (fc is! Map) continue;
        final front = fc['front']?.toString() ?? '';
        final back = fc['back']?.toString() ?? '';
        if (front.isEmpty || back.isEmpty) {
          throw Exception('Flashcard in objective $oCode missing front or back text');
        }
        totalFlashcards++;
      }

      // Lessons
      final lessons = objective['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        if (lesson is! Map) continue;
        totalLessons++;

        // Verify lesson concept slugs if declared
        final lessonSlugs = (lesson['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList();
        if (lessonSlugs != null) {
          for (final s in lessonSlugs) {
            if (!declaredConceptSlugs.contains(s)) {
              print('  ⚠️ Warning: Lesson "${lesson['title']}" references concept "$s" which has not been declared yet.');
            }
          }
        }

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
  print('  Releases         : ${releases.length} authoritative source release(s)');
  print('  Target           : $manifestSlug');
  print('  Domains          : ${domains.length}');
  print('  Objectives       : $totalObjectives');
  print('  Concepts         : $totalConcepts');
  print('  Shared Stimuli   : ${stimuliKeys.length}');
  print('  Flashcards       : $totalFlashcards');
  print('  Lessons          : $totalLessons');
  print('  Lesson Blocks    : $totalBlocks');
  print('  Assessment Items : $totalAssessmentItems');
  print('  Legacy Questions : $totalLegacyQuestions');
}

// ----------------------------------------------------------------------------
// Ambiguity-Safe Canonical Concept Resolution (Handled Atomically in DB RPC)
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// Ingestion (Apply) Logic
// ----------------------------------------------------------------------------

Map<String, dynamic> _prepareManifestPayload({
  required Map<String, dynamic> manifest,
  required String targetSlug,
  required String versionCode,
  Map<String, String>? conceptMap,
}) {
  final cMap = conceptMap ?? const {};
  // 1. Target & TargetVersion
  final target = Map<String, dynamic>.from(manifest['target'] as Map? ?? {});
  target['slug'] = targetSlug;

  final targetVersionRaw = manifest['target_version'] as Map?;
  final targetVersion = Map<String, dynamic>.from(targetVersionRaw ?? {});
  targetVersion['version_code'] = versionCode;
  targetVersion['title'] = targetVersion['title'] ?? target['version_title'] ?? versionCode;
  targetVersion['description'] = targetVersion['description'] ?? target['version_description'];

  // 2. Source Releases
  final rawReleases = manifest['source_releases'] as List<dynamic>?;
  final singleRelease = manifest['source_release'] as Map<String, dynamic>?;
  final releases = <Map<String, dynamic>>[];
  if (rawReleases != null) {
    for (final r in rawReleases) {
      if (r is Map) releases.add(Map<String, dynamic>.from(r));
    }
  } else if (singleRelease != null) {
    releases.add(Map<String, dynamic>.from(singleRelease));
  }

  // 3. Collect all declared concepts across manifest (root + domains/objectives)
  final declaredConcepts = <Map<String, dynamic>>[];
  final seenConceptSlugs = <String>{};

  void addDeclaredConcept(Map<String, dynamic> c) {
    final slug = c['slug']?.toString();
    if (slug == null || slug.isEmpty || seenConceptSlugs.contains(slug)) return;
    seenConceptSlugs.add(slug);
    declaredConcepts.add({
      'slug': slug,
      'name': c['name'] ?? slug,
      'canonical_concept': c['canonical_concept'],
      'short_definition': c['short_definition'],
      'description': c['description'],
      'emoji': c['emoji'] ?? '💡',
      'aliases': c['aliases'] ?? [],
      'source_release_id': c['source_release_id'],
      'citation': c['citation'] ?? c['citation_location'],
      'notes': c['notes'] ?? c['citation_notes'],
    });
  }

  if (manifest['concepts'] is List) {
    for (final c in manifest['concepts'] as List) {
      if (c is Map) addDeclaredConcept(Map<String, dynamic>.from(c));
    }
  }

  // 4. Shared Stimuli (collect from root, domain, and objective scopes)
  final stimuli = <Map<String, dynamic>>[];
  final seenStimKeys = <String>{};

  void collectStimuli(List<dynamic>? list) {
    if (list == null) return;
    for (final s in list) {
      if (s is! Map) continue;
      final key = s['id']?.toString() ?? s['slug']?.toString() ?? s['stimulus_key']?.toString() ?? 'stim-${stimuli.length + 1}';
      if (seenStimKeys.contains(key)) continue;
      seenStimKeys.add(key);

      stimuli.add({
        'stimulus_key': key,
        'title': s['title'],
        'body': s['body'] ?? s['body_markdown'],
        'stimulus_type': s['stimulus_type'] ?? 'scenario',
        'media_url': s['media_url'],
        'credit': s['credit'],
        'attribution': s['attribution'],
        'source_release_id': s['source_release_id'],
        'citation': s['citation'] ?? s['citation_location'],
        'notes': s['notes'] ?? s['citation_notes'],
      });
    }
  }

  collectStimuli(manifest['stimuli'] as List<dynamic>?);

  // 5. Standalone Target Flashcards
  final flashcards = <Map<String, dynamic>>[];
  final rawFlashcards = manifest['flashcards'] as List<dynamic>? ?? [];
  for (final fc in rawFlashcards) {
    if (fc is! Map) continue;
    final cSlugs = (fc['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final cIds = cSlugs.map((s) => cMap[s]).whereType<String>().toList();
    flashcards.add({
      'front': fc['front'],
      'back': fc['back'],
      'explanation': fc['explanation'],
      'concept_ids': cIds,
      'concept_slugs': cSlugs,
      'source_release_id': fc['source_release_id'],
      'citation': fc['citation'] ?? fc['citation_location'],
      'notes': fc['notes'] ?? fc['citation_notes'],
    });
  }

  // 6. Domains & Objectives
  final domains = <Map<String, dynamic>>[];
  final rawDomains = manifest['domains'] as List<dynamic>? ?? [];

  for (int dIdx = 0; dIdx < rawDomains.length; dIdx++) {
    final d = rawDomains[dIdx];
    if (d is! Map) continue;
    collectStimuli(d['stimuli'] as List<dynamic>?);

    final objectives = <Map<String, dynamic>>[];
    final rawObjectives = d['objectives'] as List<dynamic>? ?? [];

    for (int oIdx = 0; oIdx < rawObjectives.length; oIdx++) {
      final obj = rawObjectives[oIdx];
      if (obj is! Map) continue;
      collectStimuli(obj['stimuli'] as List<dynamic>?);

      // Objective concepts
      final objDeclaredConcepts = obj['concepts'] as List<dynamic>? ?? [];
      final objConceptIds = <String>{};
      final objConceptSlugs = <String>[];
      for (final c in objDeclaredConcepts) {
        if (c is Map) {
          addDeclaredConcept(Map<String, dynamic>.from(c));
          if (c['slug'] != null) {
            final s = c['slug'].toString();
            objConceptSlugs.add(s);
            final id = cMap[s];
            if (id != null) objConceptIds.add(id);
          }
        }
      }

      // Objective Flashcards
      final objFlashcards = <Map<String, dynamic>>[];
      for (final fc in (obj['flashcards'] as List<dynamic>? ?? [])) {
        if (fc is! Map) continue;
        final cSlugs = (fc['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final cIds = cSlugs.isNotEmpty
            ? cSlugs.map((s) => cMap[s]).whereType<String>().toList()
            : objConceptIds.toList();
        objFlashcards.add({
          'front': fc['front'],
          'back': fc['back'],
          'explanation': fc['explanation'],
          'concept_ids': cIds,
          'concept_slugs': cSlugs.isNotEmpty ? cSlugs : objConceptSlugs,
          'source_release_id': fc['source_release_id'],
          'citation': fc['citation'] ?? fc['citation_location'],
          'notes': fc['notes'] ?? fc['citation_notes'],
        });
      }

      // Objective Assessment Items
      final objItems = <Map<String, dynamic>>[];
      for (final item in (obj['assessment_items'] as List<dynamic>? ?? [])) {
        if (item is! Map) continue;
        final cSlugs = (item['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final cIds = cSlugs.isNotEmpty
            ? cSlugs.map((s) => cMap[s]).whereType<String>().toList()
            : objConceptIds.toList();
        objItems.add({
          'stimulus_key': item['stimulus_key'] ?? item['stimulus_id'],
          'prompt': item['prompt'],
          'interaction_type': item['interaction_type'] ?? 'single_choice',
          'response_spec': item['response_spec'] ?? {},
          'scoring_spec': item['scoring_spec'] ?? {},
          'explanation': item['explanation'],
          'concept_ids': cIds,
          'concept_slugs': cSlugs.isNotEmpty ? cSlugs : objConceptSlugs,
          'source_release_id': item['source_release_id'],
          'citation': item['citation'] ?? item['citation_location'],
          'notes': item['notes'] ?? item['citation_notes'],
        });
      }

      // Lessons
      final lessons = <Map<String, dynamic>>[];
      final rawLessons = obj['lessons'] as List<dynamic>? ?? [];

      for (int lIdx = 0; lIdx < rawLessons.length; lIdx++) {
        final l = rawLessons[lIdx];
        if (l is! Map) continue;

        // Scoped lesson concept linking (NO global leakage!)
        final lConceptSlugs = (l['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList();
        final lConceptIds = (lConceptSlugs != null && lConceptSlugs.isNotEmpty)
            ? lConceptSlugs.map((s) => cMap[s]).whereType<String>().toList()
            : objConceptIds.toList();

        // Lesson Blocks
        final blocks = <Map<String, dynamic>>[];
        for (int bIdx = 0; bIdx < (l['blocks'] as List<dynamic>? ?? []).length; bIdx++) {
          final b = (l['blocks'] as List<dynamic>)[bIdx];
          if (b is! Map) continue;
          blocks.add({
            'block_type': b['block_type'] ?? 'markdown',
            'content': b['content'] ?? {},
            'sort_order': b['sort_order'] ?? (bIdx + 1),
            'source_release_id': b['source_release_id'],
            'citation': b['citation'] ?? b['citation_location'],
            'notes': b['notes'] ?? b['citation_notes'],
          });
        }

        // Lesson Terms
        final terms = <Map<String, dynamic>>[];
        for (final t in (l['terms'] as List<dynamic>? ?? [])) {
          if (t is! Map) continue;
          terms.add({
            'term': t['term'],
            'definition': t['definition'],
          });
        }

        // Lesson Questions
        final questions = <Map<String, dynamic>>[];
        for (final q in (l['questions'] as List<dynamic>? ?? [])) {
          if (q is! Map) continue;
          questions.add({
            'question_text': q['question_text'] ?? q['question'],
            'question': q['question_text'] ?? q['question'],
            'options': q['options'] ?? [],
            'correct_answer': q['correct_answer'] ?? q['correct_index'] ?? 0,
            'correct_index': q['correct_answer'] ?? q['correct_index'] ?? 0,
            'explanation': q['explanation'],
          });
        }

        // Lesson Assessment Items
        final lessonItems = <Map<String, dynamic>>[];
        for (final item in (l['assessment_items'] as List<dynamic>? ?? [])) {
          if (item is! Map) continue;
          final cSlugs = (item['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final cIds = cSlugs.isNotEmpty
              ? cSlugs.map((s) => cMap[s]).whereType<String>().toList()
              : lConceptIds;
          lessonItems.add({
            'stimulus_key': item['stimulus_key'] ?? item['stimulus_id'],
            'prompt': item['prompt'],
            'interaction_type': item['interaction_type'] ?? 'single_choice',
            'response_spec': item['response_spec'] ?? {},
            'scoring_spec': item['scoring_spec'] ?? {},
            'explanation': item['explanation'],
            'concept_ids': cIds,
            'concept_slugs': cSlugs.isNotEmpty ? cSlugs : (lConceptSlugs ?? objConceptSlugs),
            'source_release_id': item['source_release_id'],
            'citation': item['citation'] ?? item['citation_location'],
            'notes': item['notes'] ?? item['citation_notes'],
          });
        }

        lessons.add({
          'title': l['title'],
          'description': l['description'] ?? l['summary'],
          'order_index': l['order_index'] ?? (lIdx + 1),
          'source_release_id': l['source_release_id'],
          'citation': l['citation'] ?? l['citation_location'],
          'notes': l['notes'] ?? l['citation_notes'],
          'concept_ids': lConceptIds,
          'concept_slugs': lConceptSlugs ?? objConceptSlugs,
          'blocks': blocks,
          'terms': terms,
          'questions': questions,
          'assessment_items': lessonItems,
        });
      }

      objectives.add({
        'code': obj['code'],
        'title': obj['title'],
        'description': obj['description'],
        'sort_order': obj['sort_order'] ?? (oIdx + 1),
        'bloom_level': obj['bloom_level'] ?? 'understand',
        'source_release_id': obj['source_release_id'],
        'citation': obj['citation'] ?? obj['citation_location'],
        'notes': obj['notes'] ?? obj['citation_notes'],
        'concept_ids': objConceptIds.toList(),
        'concept_slugs': objConceptSlugs,
        'flashcards': objFlashcards,
        'assessment_items': objItems,
        'lessons': lessons,
      });
    }

    domains.add({
      'code': d['code'],
      'title': d['title'],
      'description': d['description'],
      'sort_order': d['sort_order'] ?? (dIdx + 1),
      'weight': d['weight'],
      'source_release_id': d['source_release_id'],
      'citation': d['citation'] ?? d['citation_location'],
      'notes': d['notes'] ?? d['citation_notes'],
      'objectives': objectives,
    });
  }

  return {
    'field': manifest['field'],
    'target': target,
    'target_version': targetVersion,
    'source_releases': releases,
    'stimuli': stimuli,
    'flashcards': flashcards,
    'domains': domains,
    'concepts': declaredConcepts,
    if (manifest['source_mappings'] != null)
      'source_mappings': manifest['source_mappings'],
    if (manifest['target_version_concept_mappings'] != null)
      'target_version_concept_mappings': manifest['target_version_concept_mappings'],
    if (manifest['concept_mappings'] != null)
      'concept_mappings': manifest['concept_mappings'],
  };
}

Future<void> _executeApply(
  SupabaseRestClient client,
  Map<String, dynamic> manifest,
  String targetSlug,
  String versionCode, {
  String? filePath,
}) async {
  print('====================================================');
  print('Authoritative Curriculum Ingestion Pipeline (--apply)');
  print('====================================================');

  // 1. Pre-flight JSON Schema validation & Pedagogical Quality Linter
  _validateJsonSchema(manifest, filePath: filePath);
  final linter = ManifestLinter();
  linter.lint(filePath ?? 'manifest', manifest);
  if (linter.hasErrors) {
    print('\n❌ Pedagogical Quality Linter Errors (${filePath ?? "manifest"}):');
    for (final issue in linter.issues.where((i) => i.level == 'ERROR')) {
      print('  • $issue');
    }
    throw Exception('Manifest failed pedagogical quality linter (${filePath ?? "manifest"}). Ingestion blocked.');
  }
  if (linter.hasWarnings) {
    print('\n⚠️ Pedagogical Quality Linter Warnings (${filePath ?? "manifest"}):');
    for (final issue in linter.issues.where((i) => i.level == 'WARNING')) {
      print('  • $issue');
    }
  }

  // 2. Locate target (exact slug match)
  print('Locating learning target with slug "$targetSlug"...');
  final targetRes = await client.restGet('learning_targets?slug=eq.$targetSlug&limit=1');
  final targetList = asList(targetRes['body']);
  String canonicalSlug = targetSlug;
  String? targetId;
  if (targetList.isNotEmpty) {
    final targetRow = targetList.first as Map<String, dynamic>;
    targetId = targetRow['id'] as String;
    canonicalSlug = targetRow['slug'] as String;
    print('Found existing target: "${targetRow['title']}" ($canonicalSlug) [ID: $targetId]');
  } else {
    print('Target "$targetSlug" does not exist yet; will be created during atomic manifest ingestion.');
  }

  // 3. Check TargetVersion status (prevent overwriting published/retired or frozen review_ready)
  if (targetId != null) {
    print('Checking target_version "$versionCode"...');
    final versionRes = await client.restGet('target_versions?target_id=eq.$targetId&version_code=eq.$versionCode');
    final versionList = asList(versionRes['body']);

    if (versionList.isNotEmpty) {
      final existingVersion = versionList.first as Map<String, dynamic>;
      final status = existingVersion['status'] as String;

      if (status == 'published' || status == 'retired') {
        throw Exception(
          'TargetVersion "$versionCode" is already "$status". '
          'Strict database immutability prevents modifying published/retired versions. '
          'To update curriculum, create a new draft version code (e.g. "$versionCode-draft" or next iteration).',
        );
      }

      if (status == 'review_ready') {
        throw Exception(
          'TargetVersion "$versionCode" is in "review_ready" status (frozen QA snapshot). '
          'To modify curriculum or re-apply, set its status back to "draft" first.',
        );
      }
    }
  }

  // 4. Prepare normalized payload packaging all declared concepts & provenance
  print('Packaging curriculum manifest & canonical concepts for atomic transaction...');
  final payload = _prepareManifestPayload(
    manifest: manifest,
    targetSlug: canonicalSlug,
    versionCode: versionCode,
  );

  // 5. Execute atomic transactional ingestion RPC
  print('Executing atomic database transaction via RPC "ingest_curriculum_manifest"...');
  final rpcRes = await client.restRpc('ingest_curriculum_manifest', {'payload': payload});
  if (rpcRes['statusCode'] >= 400) {
    throw Exception('Transactional ingestion RPC failed (${rpcRes['statusCode']}): ${rpcRes['body']}');
  }

  final result = rpcRes['body'] as Map<String, dynamic>;
  print('\n----------------------------------------------------');
  print('Ingestion Results (Atomic Transaction Succeeded):');
  print('  Target Version ID    : ${result['target_version_id']} (draft)');
  print('  Concepts Resolved    : ${result['concepts_count']}');
  print('  Domains Ingested     : ${result['domains_count']}');
  print('  Objectives Ingested  : ${result['objectives_count']}');
  print('  Lessons Ingested     : ${result['lessons_count']}');
  print('  Lesson Blocks        : ${result['blocks_count']}');
  print('  Assessment Items     : ${result['assessment_items_count']}');
  print('  Flashcards Ingested  : ${result['flashcards_count']}');
  print('  Legacy Questions     : ${result['questions_count']}');
  print('  Shared Stimuli       : ${result['stimuli_count']}');
  print('  Provenance Mappings  : ${result['mappings_count']}');
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
  final targetRes = await client.restGet('learning_targets?slug=eq.$targetSlug&limit=1');
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
  print('TargetVersion "$versionCode" is now staged as REVIEW_READY for QA and beta evaluation.');
}

Future<void> _executePublish(
  SupabaseRestClient client,
  String targetSlug,
  String versionCode, {
  bool retirePrevious = false,
}) async {
  // 1. Locate target (exact match)
  final targetRes = await client.restGet('learning_targets?slug=eq.$targetSlug&limit=1');
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

  // Publication strictly requires review_ready status
  if (currentStatus != 'review_ready') {
    throw Exception(
      'TargetVersion "$versionCode" is currently in "$currentStatus" status. '
      'Publication strictly requires "review_ready" staging status to ensure QA verification. '
      'Run with --stage-review first.',
    );
  }

  // 3. Atomically publish (and optionally retire previous) via DB transaction RPC
  print('Promoting TargetVersion "$versionCode" [ID: $versionId] to published (atomic transaction)...');
  final publishRes = await client.restRpc('publish_target_version', {
    'p_version_id': versionId,
    'p_retire_previous': retirePrevious,
  });

  if (publishRes['statusCode'] >= 400) {
    throw Exception('Failed to publish version: ${publishRes['body']}');
  }

  final resBody = publishRes['body'] as Map<String, dynamic>? ?? {};
  final retiredCount = resBody['retired_previous_count'] ?? 0;
  if (retirePrevious && retiredCount > 0) {
    print('Atomically retired $retiredCount previous published version(s).');
  }

  print('TargetVersion "$versionCode" is now PUBLISHED and strictly IMMUTABLE under database RLS.');
}
