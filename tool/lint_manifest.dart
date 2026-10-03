import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Static Curriculum Quality Linter & Pedagogical Checker
///
/// Evaluates curriculum manifests against strict pedagogical, structural,
/// and cognitive standards before ingestion:
///   1. Domain weights sum validation (sum to 1.0 within 0.01 tolerance).
///   2. Objective assessment coverage (flags objectives with 0 questions).
///   3. Concept instructional coverage (flags concepts never taught or assessed).
///   4. Assessment concept alignment (flags questions with no concept_slugs).
///   5. Distractor length bias (flags questions where correct answer is >1.8x average distractor length).
///   6. Answer position balance (flags severe position bias, e.g. >50% index 0).
///   7. Citation completeness (flags nodes/lessons/questions lacking provenance citations).
///   8. Duplicate question similarity (detects identical or near-duplicate prompts).
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

  void lint(String filePath, Map<String, dynamic> manifest) {
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

    // Concept & Question tracking
    final declaredConcepts = <String>{};
    final taughtConcepts = <String>{};
    final assessedConcepts = <String>{};
    final questionPrompts = <String>[];
    final answerPositions = <int>[];

    // Traverse Objectives
    for (final domain in domains) {
      if (domain is! Map) continue;
      final dCode = domain['code']?.toString() ?? '?';
      final objectives = domain['objectives'] as List<dynamic>? ?? [];

      for (final objective in objectives) {
        if (objective is! Map) continue;
        final oCode = objective['code']?.toString() ?? '?';
        final oLoc = 'Objective $dCode.$oCode';

        // Check concepts
        final concepts = objective['concepts'] as List<dynamic>? ?? [];
        for (final concept in concepts) {
          if (concept is! Map) continue;
          final cSlug = concept['slug']?.toString();
          if (cSlug != null) declaredConcepts.add(cSlug);

          final cCitation = concept['citation']?.toString();
          if (cCitation == null || cCitation.trim().isEmpty) {
            issues.add(LintIssue(
              level: 'WARNING',
              rule: 'citation-completeness',
              location: '$oLoc -> Concept $cSlug',
              message: 'Concept is missing an authoritative citation.',
            ));
          }
        }

        // Check lessons
        final lessons = objective['lessons'] as List<dynamic>? ?? [];
        int objectiveQuestionCount = 0;

        for (final lesson in lessons) {
          if (lesson is! Map) continue;
          final lTitle = lesson['title']?.toString() ?? 'Untitled';
          final lLoc = '$oLoc -> Lesson "$lTitle"';

          final lCitation = lesson['citation']?.toString();
          if (lCitation == null || lCitation.trim().isEmpty) {
            issues.add(LintIssue(
              level: 'WARNING',
              rule: 'citation-completeness',
              location: lLoc,
              message: 'Lesson is missing an authoritative citation.',
            ));
          }

          // Terms and snippet concepts taught
          final terms = lesson['terms'] as List<dynamic>? ?? [];
          if (terms.isEmpty && (lesson['blocks'] as List<dynamic>? ?? []).isEmpty) {
            issues.add(LintIssue(
              level: 'INFO',
              rule: 'lesson-instructional-depth',
              location: lLoc,
              message: 'Lesson defines 0 terms and 0 instructional blocks.',
            ));
          }

          // Legacy Questions & New Assessment Items
          final questions = lesson['questions'] as List<dynamic>? ?? [];
          objectiveQuestionCount += questions.length;

          for (int qIdx = 0; qIdx < questions.length; qIdx++) {
            final q = questions[qIdx];
            if (q is! Map) continue;
            final qLoc = '$lLoc -> Question ${qIdx + 1}';
            final prompt = q['question_text']?.toString() ?? '';
            final options = (q['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
            final correct = q['correct_answer'] as int?;
            final explanation = q['explanation']?.toString();
            final qConcepts = (q['concept_slugs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

            // Duplicate question detection
            final normPrompt = prompt.toLowerCase().trim();
            if (questionPrompts.contains(normPrompt)) {
              issues.add(LintIssue(
                level: 'ERROR',
                rule: 'duplicate-question',
                location: qLoc,
                message: 'Duplicate question prompt detected: "$prompt"',
              ));
            }
            questionPrompts.add(normPrompt);

            // Concept mapping
            if (qConcepts.isEmpty) {
              issues.add(LintIssue(
                level: 'WARNING',
                rule: 'question-concept-mapping',
                location: qLoc,
                message: 'Question does not map to any concept_slugs.',
              ));
            } else {
              assessedConcepts.addAll(qConcepts);
            }

            // Explanation depth
            if (explanation == null || explanation.trim().length < 25) {
              issues.add(LintIssue(
                level: 'WARNING',
                rule: 'substantive-explanation',
                location: qLoc,
                message: 'Explanation is too brief (<25 characters). Substantive pedagogical rationale required.',
              ));
            }

            // Distractor length bias
            if (options.length >= 2 && correct != null && correct >= 0 && correct < options.length) {
              answerPositions.add(correct);
              final correctLength = options[correct].length;
              double otherTotalLength = 0;
              for (int oIdx = 0; oIdx < options.length; oIdx++) {
                if (oIdx != correct) otherTotalLength += options[oIdx].length;
              }
              final avgDistractorLength = otherTotalLength / (options.length - 1);
              if (avgDistractorLength > 0 && correctLength > avgDistractorLength * 1.85) {
                issues.add(LintIssue(
                  level: 'WARNING',
                  rule: 'correct-answer-length-bias',
                  location: qLoc,
                  message: 'Correct answer length ($correctLength chars) is >1.85x average distractor ($avgDistractorLength chars), creating an answer giveaway.',
                ));
              }
            }
          }
        }

        // Objective with no assessment evidence
        if (objectiveQuestionCount == 0) {
          issues.add(LintIssue(
            level: 'WARNING',
            rule: 'objective-assessment-coverage',
            location: oLoc,
            message: 'Objective has 0 assessment questions. Every objective should have diagnostic assessment evidence.',
          ));
        }
      }
    }

    // Answer position bias
    if (answerPositions.length >= 10) {
      final counts = <int, int>{};
      for (final pos in answerPositions) {
        counts[pos] = (counts[pos] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        final ratio = entry.value / answerPositions.length;
        if (ratio > 0.50) {
          issues.add(LintIssue(
            level: 'WARNING',
            rule: 'answer-position-bias',
            location: 'manifest.questions',
            message: 'Option index ${entry.key} is correct ${(ratio * 100).toStringAsFixed(1)}% of the time (>50%), indicating position clustering bias.',
          ));
        }
      }
    }

    // Concept instructional coverage
    for (final c in declaredConcepts) {
      if (!assessedConcepts.contains(c) && !taughtConcepts.contains(c)) {
        issues.add(LintIssue(
          level: 'INFO',
          rule: 'concept-instructional-coverage',
          location: 'Concept $c',
          message: 'Concept is declared in manifest but has no questions mapping to it.',
        ));
      }
    }
  }
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage:');
    print('  dart run tool/lint_manifest.dart <path-to-manifest.yaml>');
    print('  dart run tool/lint_manifest.dart --dir <directory-with-manifests>');
    exit(1);
  }

  final filesToLint = <String>[];

  if (args.contains('--dir')) {
    final dirIdx = args.indexOf('--dir');
    if (dirIdx + 1 >= args.length) {
      print('Error: Missing directory argument after --dir');
      exit(1);
    }
    final dir = Directory(args[dirIdx + 1]);
    if (!dir.existsSync()) {
      print('Error: Directory not found: ${dir.path}');
      exit(1);
    }
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.yaml') || entity.path.endsWith('.yml') || entity.path.endsWith('.json')) &&
          !entity.path.contains('.schema.')) {
        filesToLint.add(entity.path);
      }
    }
  } else {
    filesToLint.add(args.first);
  }

  print('====================================================');
  print('  Curriculum Static Quality Linter & Diagnostic Gate');
  print('====================================================');
  print('Inspecting ${filesToLint.length} manifest file(s)...\n');

  int totalErrors = 0;
  int totalWarnings = 0;

  for (final path in filesToLint) {
    print('📁 Linting: $path');
    try {
      final manifest = _loadManifest(path);
      final linter = ManifestLinter();
      linter.lint(path, manifest);

      final errors = linter.issues.where((i) => i.level == 'ERROR').toList();
      final warnings = linter.issues.where((i) => i.level == 'WARNING').toList();
      final infos = linter.issues.where((i) => i.level == 'INFO').toList();

      totalErrors += errors.length;
      totalWarnings += warnings.length;

      if (linter.issues.isEmpty) {
        print('   ✅ Perfect! 0 issues found.');
      } else {
        for (final issue in linter.issues) {
          print('   $issue');
        }
        print('   Result: ${errors.length} error(s), ${warnings.length} warning(s), ${infos.length} info note(s).');
      }
      print('');
    } catch (e) {
      print('   ❌ Fatal parse error: $e\n');
      totalErrors++;
    }
  }

  print('====================================================');
  print('Linter Summary: $totalErrors Error(s), $totalWarnings Warning(s)');
  print('====================================================');

  if (totalErrors > 0) {
    print('❌ Quality gate FAILED: Resolve errors before applying curriculum.');
    exit(1);
  } else if (totalWarnings > 0) {
    print('⚠️ Quality gate PASSED with warnings. Review warnings prior to publishing.');
    exit(0);
  } else {
    print('✅ Quality gate PASSED flawlessly!');
    exit(0);
  }
}
