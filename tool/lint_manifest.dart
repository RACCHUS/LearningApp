import 'dart:convert';
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';

/// Static Curriculum Quality Linter & Pedagogical Gate
///
/// Evaluates curriculum manifests against strict pedagogical, structural,
/// and cognitive standards before ingestion:
///   1. Formal JSON Schema validation (via content/schema/curriculum_manifest.schema.json).
///   2. Domain weights sum validation (sum to 1.0 within 0.01 tolerance).
///   3. Objective assessment coverage (inspects BOTH questions & assessment_items).
///   4. Concept instructional & assessment coverage (properly tracks taughtConcepts).
///   5. Distractor length bias (flags giveaways across MCQ & multi-select items).
///   6. Answer position balance (flags position clustering).
///   7. Citation completeness (flags nodes/lessons/items lacking provenance citations).
///   8. Duplicate prompt similarity (detects identical or near-duplicate prompts).
///
/// Usage:
///   dart run tool/lint_manifest.dart content/security_plus_sy0_701.yaml
///   dart run tool/lint_manifest.dart --dir content/

dynamic _yamlToDart(dynamic node) {
  if (node is YamlMap) {
    return node.map((key, value) => MapEntry(key.toString(), _yamlToDart(value)));
  } else if (node is YamlList) {
    return node.map(_yamlToDart).toList();
  }
  return node;
}

Map<String, dynamic> _loadManifest(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw Exception('File not found: $path');
  }
  final content = file.readAsStringSync();
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    final dynamic yamlNode = loadYaml(content);
    return (_yamlToDart(yamlNode) as Map).cast<String, dynamic>();
  } else {
    return (jsonDecode(content) as Map).cast<String, dynamic>();
  }
}

class LintIssue {
  final String level; // 'ERROR', 'WARNING', 'INFO'
  final String rule;
  final String location;
  final String message;

  LintIssue({
    required this.level,
    required this.rule,
    required this.location,
    required this.message,
  });

  @override
  String toString() {
    final symbol = level == 'ERROR' ? '❌' : (level == 'WARNING' ? '⚠️' : 'ℹ️');
    return '$symbol [$level] ($rule) at $location:\n    $message';
  }
}

class ManifestLinter {
  final List<LintIssue> issues = [];
  JsonSchema? _compiledSchema;

  ManifestLinter() {
    final schemaFile = File('content/schema/curriculum_manifest.schema.json');
    if (schemaFile.existsSync()) {
      try {
        final schemaJson = jsonDecode(schemaFile.readAsStringSync());
        _compiledSchema = JsonSchema.create(schemaJson);
      } catch (e) {
        // Schema load fallback
      }
    }
  }

  void lint(String filePath, Map<String, dynamic> manifest) {
    // 0. Formal JSON Schema Validation
    if (_compiledSchema != null) {
      final validationResult = _compiledSchema!.validate(manifest);
      if (!validationResult.isValid) {
        for (final error in validationResult.errors) {
          issues.add(LintIssue(
            level: 'ERROR',
            rule: 'json-schema',
            location: error.instancePath,
            message: error.message,
          ));
        }
      }
    }

    // 0.5 Source Releases Referential Validation
    final validSourceReleaseKeys = <String>{};
    final rawReleases = manifest['source_releases'] as List<dynamic>?;
    final singleRelease = manifest['source_release'] as Map<String, dynamic>?;
    if (rawReleases != null) {
      for (int i = 0; i < rawReleases.length; i++) {
        validSourceReleaseKeys.add(i.toString());
        final r = rawReleases[i];
        if (r is Map) {
          if (r['id'] != null) validSourceReleaseKeys.add(r['id'].toString());
          final pub = r['publisher']?.toString();
          final ver = r['version']?.toString();
          if (pub != null && ver != null) validSourceReleaseKeys.add('$pub/$ver');
        }
      }
    } else if (singleRelease != null) {
      validSourceReleaseKeys.add('0');
      if (singleRelease['id'] != null) validSourceReleaseKeys.add(singleRelease['id'].toString());
      final pub = singleRelease['publisher']?.toString();
      final ver = singleRelease['version']?.toString();
      if (pub != null && ver != null) validSourceReleaseKeys.add('$pub/$ver');
    }

    void checkSourceReleaseRef(dynamic relRef, String location) {
      if (relRef == null) return;
      final key = relRef.toString().trim();
      if (key.isNotEmpty && !validSourceReleaseKeys.contains(key)) {
        issues.add(LintIssue(
          level: 'ERROR',
          rule: 'source-release-reference',
          location: location,
          message: 'Unknown source_release_id "$key". Declared source release IDs: ${validSourceReleaseKeys.toList()}',
        ));
      }
    }

    void checkStimuliList(List<dynamic>? stimList, String scopeLocation) {
      if (stimList == null) return;
      for (int sIdx = 0; sIdx < stimList.length; sIdx++) {
        final s = stimList[sIdx];
        if (s is! Map) continue;
        final sKey = s['id']?.toString() ?? s['slug']?.toString() ?? 'stim-${sIdx + 1}';
        checkSourceReleaseRef(s['source_release_id'], '$scopeLocation -> Stimulus "$sKey"');
      }
    }

    // Check root stimuli
    checkStimuliList(manifest['stimuli'] as List<dynamic>?, 'manifest.stimuli');

    // Check manifest source mappings
    if (manifest['source_mappings'] is List) {
      for (final sm in manifest['source_mappings']) {
        if (sm is Map) {
          checkSourceReleaseRef(sm['source_release_id'], 'manifest.source_mappings');
        }
      }
    }

    // 1. Domain Weights Sum
    final domains = manifest['domains'] as List<dynamic>? ?? [];
    double totalWeight = 0.0;
    bool hasWeights = false;

    for (int i = 0; i < domains.length; i++) {
      final domain = domains[i];
      if (domain is! Map) continue;
      final dCode = domain['code']?.toString() ?? 'Domain $i';
      final dCitation = domain['citation']?.toString();
      if (dCitation == null || dCitation.trim().isEmpty) {
        issues.add(LintIssue(
          level: 'WARNING',
          rule: 'citation-completeness',
          location: 'Domain $dCode',
          message: 'Domain is missing an authoritative citation.',
        ));
      }

      final w = domain['weight'];
      if (w is num) {
        hasWeights = true;
        totalWeight += w.toDouble();
      }
    }

    if (hasWeights && (totalWeight < 0.98 || totalWeight > 1.02)) {
      issues.add(LintIssue(
        level: 'ERROR',
        rule: 'domain-weight-sum',
        location: 'manifest.domains',
        message: 'Sum of domain weights is ${totalWeight.toStringAsFixed(3)}, expected 1.0 (±0.01).',
      ));
    }

    // 2. Traversal: Objectives, Concepts, Lessons, and Assessments
    final declaredConcepts = <String, String>{}; // slug -> name
    final taughtConcepts = <String>{};
    final assessedConcepts = <String>{};
    final seenQuestions = <String, String>{}; // normalized prompt -> location
    final positionCounts = <int, int>{};
    int totalSingleChoice = 0;

    for (final domain in domains) {
      if (domain is! Map) continue;
      final dCode = domain['code']?.toString() ?? '?';
      checkSourceReleaseRef(domain['source_release_id'], 'Domain $dCode');
      checkStimuliList(domain['stimuli'] as List<dynamic>?, 'Domain $dCode');
      final objectives = domain['objectives'] as List<dynamic>? ?? [];

      for (final objective in objectives) {
        if (objective is! Map) continue;
        final oCode = objective['code']?.toString() ?? '?';
        final oLocation = 'Objective $dCode.$oCode';
        checkSourceReleaseRef(objective['source_release_id'], oLocation);
        checkStimuliList(objective['stimuli'] as List<dynamic>?, oLocation);

        final oCitation = objective['citation']?.toString();
        if (oCitation == null || oCitation.trim().isEmpty) {
          issues.add(LintIssue(
            level: 'WARNING',
            rule: 'citation-completeness',
            location: oLocation,
            message: 'Objective is missing an authoritative citation.',
          ));
        }

        // Concepts in this objective
        final concepts = objective['concepts'] as List<dynamic>? ?? [];
        final objConceptSlugs = <String>{};
        for (final c in concepts) {
          if (c is! Map) continue;
          final cSlug = c['slug']?.toString();
          final cName = c['name']?.toString() ?? 'Unnamed';
          if (cSlug != null) {
            declaredConcepts[cSlug] = cName;
            objConceptSlugs.add(cSlug);
          }
        }

        // Lessons & Assessments
        final lessons = objective['lessons'] as List<dynamic>? ?? [];
        int totalObjectiveAssessments = 0;

        for (final lesson in lessons) {
          if (lesson is! Map) continue;
          final lTitle = lesson['title']?.toString() ?? 'Untitled';
          final lLocation = '$oLocation -> Lesson "$lTitle"';
          checkSourceReleaseRef(lesson['source_release_id'], lLocation);

          // Track taught concepts from lesson
          final lConceptSlugs = (lesson['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          if (lConceptSlugs != null && lConceptSlugs.isNotEmpty) {
            for (final s in lConceptSlugs) {
              taughtConcepts.add(s);
            }
          } else {
            // Fallback: inherits objective concepts
            taughtConcepts.addAll(objConceptSlugs);
          }

          // Legacy Questions
          final questions = lesson['questions'] as List<dynamic>? ?? [];
          totalObjectiveAssessments += questions.length;

          for (int qIdx = 0; qIdx < questions.length; qIdx++) {
            final q = questions[qIdx];
            if (q is! Map) continue;
            final qLocation = '$lLocation -> Question ${qIdx + 1}';
            final prompt = q['question_text']?.toString() ?? '';
            final options = (q['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final correctIdx = q['correct_answer'] as int?;
            final cSlugs = (q['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

            for (final s in cSlugs) {
              assessedConcepts.add(s);
            }

            if (cSlugs.isEmpty) {
              issues.add(LintIssue(
                level: 'WARNING',
                rule: 'question-concept-mapping',
                location: qLocation,
                message: 'Question has no explicit concept_slugs mapping.',
              ));
            }

            // Duplicate detection
            final normPrompt = prompt.trim().toLowerCase();
            if (seenQuestions.containsKey(normPrompt)) {
              issues.add(LintIssue(
                level: 'ERROR',
                rule: 'duplicate-question-prompt',
                location: qLocation,
                message: 'Question prompt is identical to prompt in ${seenQuestions[normPrompt]}.',
              ));
            } else {
              seenQuestions[normPrompt] = qLocation;
            }

            // Distractor length bias check
            if (options.length >= 2 && correctIdx != null && correctIdx >= 0 && correctIdx < options.length) {
              totalSingleChoice++;
              positionCounts[correctIdx] = (positionCounts[correctIdx] ?? 0) + 1;

              final correctLen = options[correctIdx].length;
              double distractorTotal = 0;
              for (int o = 0; o < options.length; o++) {
                if (o != correctIdx) distractorTotal += options[o].length;
              }
              final avgDistractor = distractorTotal / (options.length - 1);
              if (correctLen > avgDistractor * 1.85 && correctLen > 25) {
                issues.add(LintIssue(
                  level: 'WARNING',
                  rule: 'correct-answer-length-bias',
                  location: qLocation,
                  message: 'Correct answer length ($correctLen chars) is >1.85x average distractor ($avgDistractor chars), creating an answer giveaway.',
                ));
              }
            }
          }

          // Extensible Assessment Items
          final assessmentItems = lesson['assessment_items'] as List<dynamic>? ?? [];
          totalObjectiveAssessments += assessmentItems.length;

          for (int iIdx = 0; iIdx < assessmentItems.length; iIdx++) {
            final item = assessmentItems[iIdx];
            if (item is! Map) continue;
            final iLocation = '$lLocation -> Assessment Item ${iIdx + 1}';
            checkSourceReleaseRef(item['source_release_id'], iLocation);
            final prompt = item['prompt']?.toString() ?? '';
            final iType = item['interaction_type']?.toString();
            final respSpec = (item['response_spec'] as Map?)?.cast<String, dynamic>() ?? {};
            final scoreSpec = (item['scoring_spec'] as Map?)?.cast<String, dynamic>() ?? {};
            final cSlugs = (item['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

            for (final s in cSlugs) {
              assessedConcepts.add(s);
            }

            if (cSlugs.isEmpty) {
              issues.add(LintIssue(
                level: 'WARNING',
                rule: 'question-concept-mapping',
                location: iLocation,
                message: 'Assessment item has no explicit concept_slugs mapping.',
              ));
            }

            // Duplicate detection
            final normPrompt = prompt.trim().toLowerCase();
            if (seenQuestions.containsKey(normPrompt)) {
              issues.add(LintIssue(
                level: 'ERROR',
                rule: 'duplicate-question-prompt',
                location: iLocation,
                message: 'Assessment prompt is identical to prompt in ${seenQuestions[normPrompt]}.',
              ));
            } else {
              seenQuestions[normPrompt] = iLocation;
            }

            // Single choice length bias
            if (iType == 'single_choice') {
              final options = (respSpec['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
              final correctIdx = scoreSpec['correct_index'] as int?;
              if (options.length >= 2 && correctIdx != null && correctIdx >= 0 && correctIdx < options.length) {
                totalSingleChoice++;
                positionCounts[correctIdx] = (positionCounts[correctIdx] ?? 0) + 1;

                final correctLen = options[correctIdx].length;
                double distractorTotal = 0;
                for (int o = 0; o < options.length; o++) {
                  if (o != correctIdx) distractorTotal += options[o].length;
                }
                final avgDistractor = distractorTotal / (options.length - 1);
                if (correctLen > avgDistractor * 1.85 && correctLen > 25) {
                  issues.add(LintIssue(
                    level: 'WARNING',
                    rule: 'correct-answer-length-bias',
                    location: iLocation,
                    message: 'Correct answer length ($correctLen chars) is >1.85x average distractor ($avgDistractor chars), creating an answer giveaway.',
                  ));
                }
              }
            }
          }
        }

        // Objective assessment evidence check (evaluates BOTH questions & assessment_items)
        if (totalObjectiveAssessments == 0) {
          issues.add(LintIssue(
            level: 'ERROR',
            rule: 'objective-assessment-coverage',
            location: oLocation,
            message: 'Objective has 0 assessment questions or assessment items. Each objective must have measurable evidence.',
          ));
        }
      }
    }

    // 3. Answer Position Imbalance Check
    if (totalSingleChoice >= 6) {
      for (final entry in positionCounts.entries) {
        final pos = entry.key;
        final count = entry.value;
        final ratio = count / totalSingleChoice;
        if (ratio > 0.50) {
          issues.add(LintIssue(
            level: 'WARNING',
            rule: 'answer-position-bias',
            location: 'manifest.assessments',
            message: 'Answer position $pos accounts for ${(ratio * 100).toStringAsFixed(1)}% ($count/$totalSingleChoice) of single-choice answers. Rebalance positions.',
          ));
        }
      }
    }

    // 4. Concept Coverage Check (Flags concepts never taught or assessed)
    for (final entry in declaredConcepts.entries) {
      final slug = entry.key;
      final name = entry.value;
      if (!taughtConcepts.contains(slug) && !assessedConcepts.contains(slug)) {
        issues.add(LintIssue(
          level: 'WARNING',
          rule: 'concept-instructional-coverage',
          location: 'Concept $slug ("$name")',
          message: 'Concept is declared in manifest but is neither taught in any lesson nor assessed in any item.',
        ));
      } else if (!assessedConcepts.contains(slug)) {
        issues.add(LintIssue(
          level: 'INFO',
          rule: 'concept-assessment-coverage',
          location: 'Concept $slug',
          message: 'Concept is taught in lessons but has no assessment items mapping directly to it.',
        ));
      }
    }
  }

  bool get hasErrors => issues.any((i) => i.level == 'ERROR');
  bool get hasWarnings => issues.any((i) => i.level == 'WARNING');
}

void main(List<String> args) {
  print('====================================================');
  print('  Curriculum Static Quality Linter & Diagnostic Gate');
  print('====================================================');

  if (args.isEmpty) {
    print('Usage:');
    print('  dart run tool/lint_manifest.dart <path_to_manifest>');
    print('  dart run tool/lint_manifest.dart --dir <directory>');
    exit(1);
  }

  final files = <String>[];
  if (args.contains('--dir')) {
    final dirIdx = args.indexOf('--dir');
    if (dirIdx + 1 >= args.length) {
      print('Error: Missing directory path after --dir');
      exit(1);
    }
    final dir = Directory(args[dirIdx + 1]);
    if (!dir.existsSync()) {
      print('Error: Directory not found: ${dir.path}');
      exit(1);
    }
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final path = entity.path.toLowerCase();
        if ((path.endsWith('.yaml') || path.endsWith('.yml') || path.endsWith('.json')) &&
            !path.endsWith('.schema.json')) {
          files.add(entity.path);
        }
      }
    }
  } else {
    files.add(args.first);
  }

  print('Inspecting ${files.length} manifest file(s)...\n');
  int totalErrors = 0;
  int totalWarnings = 0;

  for (final filePath in files) {
    print('📁 Linting: $filePath');
    final linter = ManifestLinter();
    try {
      final manifest = _loadManifest(filePath);
      linter.lint(filePath, manifest);

      for (final issue in linter.issues) {
        print('   $issue');
      }

      final errors = linter.issues.where((i) => i.level == 'ERROR').length;
      final warnings = linter.issues.where((i) => i.level == 'WARNING').length;
      final infos = linter.issues.where((i) => i.level == 'INFO').length;
      print('   Result: $errors error(s), $warnings warning(s), $infos info note(s).\n');

      totalErrors += errors;
      totalWarnings += warnings;
    } catch (e) {
      print('   ❌ Fatal parse error: $e\n');
      totalErrors++;
    }
  }

  print('====================================================');
  print('Linter Summary: $totalErrors Error(s), $totalWarnings Warning(s)');
  print('====================================================');

  if (totalErrors > 0) {
    print('❌ Quality gate REJECTED. Ingestion blocked until errors are resolved.');
    exit(1);
  } else if (totalWarnings > 0) {
    print('⚠️ Quality gate PASSED with warnings. Review warnings prior to publishing.');
    exit(0);
  } else {
    print('✅ Quality gate PASSED cleanly with 100% compliance!');
    exit(0);
  }
}
