import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import '../../tool/lint_manifest.dart';

dynamic yamlToDart(dynamic node) {
  if (node is YamlMap) {
    return node.map((key, value) => MapEntry(key.toString(), yamlToDart(value)));
  } else if (node is YamlList) {
    return node.map(yamlToDart).toList();
  }
  return node;
}

Map<String, dynamic> loadManifest(String relativePath) {
  final file = File(relativePath);
  expect(file.existsSync(), isTrue, reason: 'Manifest file must exist at $relativePath');
  final content = file.readAsStringSync();
  final dynamic yamlNode = loadYaml(content);
  return (yamlToDart(yamlNode) as Map).cast<String, dynamic>();
}

void validateManifestStructure(Map<String, dynamic> manifest, String expectedTargetSlug) {
  // 1. Source release(s)
  final rawReleases = manifest['source_releases'] as List<dynamic>?;
  final singleRelease = manifest['source_release'] as Map<String, dynamic>?;
  expect(rawReleases != null || singleRelease != null, isTrue, reason: 'Manifest must declare source_releases or source_release');
  final releases = rawReleases != null
      ? rawReleases.cast<Map<String, dynamic>>()
      : [singleRelease!];
  expect(releases, isNotEmpty);
  for (final rel in releases) {
    expect(rel['publisher'], isNotEmpty);
    expect(rel['title'], isNotEmpty);
    expect(rel['version'], isNotEmpty);
    expect(rel['source_url'], isNotEmpty);
  }

  // 2. Target info
  final target = manifest['target'] as Map<String, dynamic>?;
  expect(target, isNotNull);
  expect(target!['slug'], equals(expectedTargetSlug));
  expect(target['version_code'], isNotEmpty);

  // 3. Domains
  final domains = manifest['domains'] as List<dynamic>?;
  expect(domains, isNotNull);
  expect(domains!.length, greaterThanOrEqualTo(3));

  final conceptSlugs = <String>{};
  final prereqSlugs = <String>{};

  for (final domain in domains) {
    expect(domain, isA<Map>());
    final dMap = domain as Map<String, dynamic>;
    expect(dMap['code'], isNotEmpty);
    expect(dMap['title'], isNotEmpty);
    expect(dMap['citation'], isNotEmpty);

    final objectives = dMap['objectives'] as List<dynamic>?;
    expect(objectives, isNotNull);
    expect(objectives!.isNotEmpty, isTrue);

    for (final objective in objectives) {
      expect(objective, isA<Map>());
      final oMap = objective as Map<String, dynamic>;
      expect(oMap['code'], isNotEmpty);
      expect(oMap['title'], isNotEmpty);
      expect(oMap['citation'], isNotEmpty);

      // Concepts
      final concepts = oMap['concepts'] as List<dynamic>? ?? [];
      for (final concept in concepts) {
        expect(concept, isA<Map>());
        final cMap = concept as Map<String, dynamic>;
        expect(cMap['slug'], isNotEmpty);
        expect(cMap['name'], isNotEmpty);
        expect(cMap['short_definition'], isNotEmpty);
        conceptSlugs.add(cMap['slug'] as String);

        final prereqs = cMap['prerequisites'] as List<dynamic>? ?? [];
        for (final p in prereqs) {
          prereqSlugs.add(p.toString());
        }
      }

      // Lessons
      final lessons = oMap['lessons'] as List<dynamic>? ?? [];
      for (final lesson in lessons) {
        expect(lesson, isA<Map>());
        final lMap = lesson as Map<String, dynamic>;
        expect(lMap['title'], isNotEmpty);
        expect(lMap['description'], isNotEmpty);
        expect(lMap['citation'], isNotEmpty);

        final terms = lMap['terms'] as List<dynamic>? ?? [];
        for (final term in terms) {
          final tMap = term as Map<String, dynamic>;
          expect(tMap['term'], isNotEmpty);
          expect(tMap['definition'], isNotEmpty);
        }

        final questions = lMap['questions'] as List<dynamic>? ?? [];
        for (final q in questions) {
          final qMap = q as Map<String, dynamic>;
          expect(qMap['question_text'], isNotEmpty);
          final options = qMap['options'] as List<dynamic>;
          expect(options.length, greaterThanOrEqualTo(2));
          final correct = qMap['correct_answer'] as int;
          expect(correct, inInclusiveRange(0, options.length - 1));
          expect(qMap['explanation'], isNotEmpty);
          expect(qMap['citation'], isNotEmpty);
        }
      }
    }
  }

  // Ensure all prereqs are declared
  for (final p in prereqSlugs) {
    expect(conceptSlugs.contains(p), isTrue,
        reason: 'Prerequisite concept "$p" must be declared in the manifest');
  }
}

void main() {
  group('Curriculum Manifest Source & Provenance Tests', () {
    test('CompTIA Security+ (SY0-701) manifest conforms to official blueprint', () {
      final manifest = loadManifest('content/security_plus_sy0_701.yaml');
      validateManifestStructure(manifest, 'cert-comptia-security-plus');

      final domains = manifest['domains'] as List<dynamic>;
      expect(domains.length, equals(5));

      final domainCodes = domains.map((d) => (d as Map)['code']).toList();
      expect(domainCodes, equals(['1.0', '2.0', '3.0', '4.0', '5.0']));
    });

    test('Software Engineer (Career) manifest conforms to SWEBOK v4 & SOC 15-1252', () {
      final manifest = loadManifest('content/software_engineer_career.yaml');
      validateManifestStructure(manifest, 'career-software-engineer');

      final domains = manifest['domains'] as List<dynamic>;
      expect(domains.length, equals(5));

      final domainCodes = domains.map((d) => (d as Map)['code']).toList();
      expect(domainCodes, equals(['SWE-1', 'SWE-2', 'SWE-3', 'SWE-4', 'SWE-5']));
    });

    test('B.S. in Computer Science (Academic Program) manifest conforms to CS2023', () {
      final manifest = loadManifest('content/bs_computer_science.yaml');
      validateManifestStructure(manifest, 'program-bs-computer-science');

      final domains = manifest['domains'] as List<dynamic>;
      expect(domains.length, equals(5));

      final domainCodes = domains.map((d) => (d as Map)['code']).toList();
      expect(domainCodes, equals(['CS-101', 'CS-201', 'CS-301', 'CS-401', 'CS-501']));
    });

    test('CLEP Introductory Psychology manifest conforms to College Board 13-domain blueprint', () {
      final manifest = loadManifest('content/clep_introductory_psychology.yaml');
      validateManifestStructure(manifest, 'clep-introductory-psychology');

      final domains = manifest['domains'] as List<dynamic>;
      expect(domains.length, equals(13));

      final domainCodes = domains.map((d) => (d as Map)['code']).toList();
      expect(domainCodes, equals([
        '1.0', '2.0', '3.0', '4.0', '5.0', '6.0', '7.0',
        '8.0', '9.0', '10.0', '11.0', '12.0', '13.0',
      ]));

      final totalWeight = domains.fold<double>(
        0.0,
        (sum, d) => sum + ((d as Map)['weight'] as num).toDouble(),
      );
      expect((totalWeight - 1.0).abs(), lessThan(0.001));
    });

    test('Lesson concept scoping regression test: Objective A concepts do not leak into Objective B lessons', () {
      final manifest = loadManifest('content/security_plus_sy0_701.yaml');
      final domains = manifest['domains'] as List<dynamic>;

      // Objective 1.1 concepts
      final obj11 = ((domains[0] as Map)['objectives'] as List<dynamic>)[0] as Map;
      final obj11Concepts = ((obj11['concepts'] as List<dynamic>).map((c) => (c as Map)['slug'])).toSet();
      expect(obj11Concepts, containsAll(['sec-cia-triad', 'sec-aaa-framework', 'sec-zero-trust']));

      // Objective 1.2 lesson
      final obj12 = ((domains[0] as Map)['objectives'] as List<dynamic>)[1] as Map;
      final obj12Lesson = (obj12['lessons'] as List<dynamic>)[0] as Map;
      final obj12LessonConcepts = (obj12Lesson['concept_slugs'] as List<dynamic>).cast<String>().toSet();

      // Regression check: Objective 1.2 lesson must NOT have any concepts from Objective 1.1
      expect(obj12LessonConcepts.intersection(obj11Concepts), isEmpty);
      expect(obj12LessonConcepts, containsAll(['sec-symmetric-asymmetric', 'sec-pki-certificates']));
    });

    test('Manifest with cross-version concept_mappings loads and validates structure', () {
      final manifest = loadManifest('test/fixtures/curriculum_manifest_version_upgrade.yaml');
      expect(manifest['concept_mappings'], isNotNull);
      final mappings = manifest['concept_mappings'] as List<dynamic>;
      expect(mappings.length, equals(2));

      final renamed = mappings[0] as Map<String, dynamic>;
      expect(renamed['from_version_code'], equals('SY0-601'));
      expect(renamed['from_concept_slug'], equals('sec-symmetric-crypto'));
      expect(renamed['to_concept_slug'], equals('sec-crypto-fundamentals'));
      expect(renamed['mapping_type'], equals('renamed'));
      expect(renamed['transfer_weight'], equals(0.90));
      expect(renamed['metadata'], isNotNull);

      final removed = mappings[1] as Map<String, dynamic>;
      expect(removed['from_version_code'], equals('SY0-601'));
      expect(removed['from_concept_slug'], equals('sec-legacy-md5'));
      expect(removed['to_concept_slug'], isNull);
      expect(removed['mapping_type'], equals('removed'));
      expect(removed['transfer_weight'], equals(0.00));
    });

    test('Linter enforces concept mapping invariants', () {
      final baseManifest = loadManifest('test/fixtures/curriculum_manifest_version_upgrade.yaml');

      // 1. Removed mapping cannot specify destination slug
      final invalidRemovedDest = Map<String, dynamic>.from(baseManifest);
      invalidRemovedDest['concept_mappings'] = [
        {
          'from_version_code': 'SY0-601',
          'from_concept_slug': 'sec-legacy-md5',
          'to_concept_slug': 'sec-crypto-fundamentals',
          'mapping_type': 'removed',
          'transfer_weight': 0.0,
        }
      ];
      final linter1 = ManifestLinter();
      linter1.lint('test.yaml', invalidRemovedDest);
      expect(linter1.issues.any((i) => i.rule == 'removed-mapping-destination'), isTrue);

      // 2. Removed mapping cannot have non-zero transfer weight
      final invalidRemovedWeight = Map<String, dynamic>.from(baseManifest);
      invalidRemovedWeight['concept_mappings'] = [
        {
          'from_version_code': 'SY0-601',
          'from_concept_slug': 'sec-legacy-md5',
          'to_concept_slug': null,
          'mapping_type': 'removed',
          'transfer_weight': 0.5,
        }
      ];
      final linter2 = ManifestLinter();
      linter2.lint('test.yaml', invalidRemovedWeight);
      expect(linter2.issues.any((i) => i.rule == 'removed-mapping-weight'), isTrue);

      // 3. Active mapping must specify destination slug
      final invalidActiveDest = Map<String, dynamic>.from(baseManifest);
      invalidActiveDest['concept_mappings'] = [
        {
          'from_version_code': 'SY0-601',
          'from_concept_slug': 'sec-symmetric-crypto',
          'to_concept_slug': null,
          'mapping_type': 'renamed',
          'transfer_weight': 0.9,
        }
      ];
      final linter3 = ManifestLinter();
      linter3.lint('test.yaml', invalidActiveDest);
      expect(linter3.issues.any((i) => i.rule == 'active-mapping-destination'), isTrue);
    });
  });

  group('Teaching-only objectives (ingestion plan v1.2 §7.4)', () {
    const path = 'content/open_openstax_prealgebra_1e.yaml';

    Map<String, dynamic> firstLesson(Map<String, dynamic> manifest) {
      final objective = ((manifest['domains'] as List).first['objectives'] as List).first as Map;
      return ((objective['lessons'] as List).first as Map).cast<String, dynamic>();
    }

    List<LintIssue> lintWith(void Function(Map<String, dynamic> lesson) change) {
      final manifest = loadManifest(path);
      change(firstLesson(manifest));
      return (ManifestLinter()..lint(path, manifest)).issues;
    }

    test('an objective with no items and no teaching-only tag is an error', () {
      final issues = lintWith((l) => l['assessment_items'] = <dynamic>[]);
      expect(issues.any((i) => i.rule == 'objective-assessment-coverage' && i.level == 'ERROR'), isTrue);
    });

    test('a declared teaching-only objective is a warning, not an error', () {
      final issues = lintWith((l) {
        l['assessment_items'] = <dynamic>[];
        l['tags'] = [...(l['tags'] as List), 'teaching-only'];
      });
      expect(issues.any((i) => i.rule == 'objective-teaching-only' && i.level == 'WARNING'), isTrue);
      expect(issues.where((i) => i.level == 'ERROR'), isEmpty);
    });

    test('a simulation block without a body is an error (mirrors the DB check)', () {
      final ok = lintWith((l) => (l['blocks'] as List).add({
            'sort_order': 99,
            'block_type': 'simulation',
            'content': {'simulation_id': 'x', 'body': 'Shown when unavailable.'},
          }));
      expect(ok.any((i) => i.rule == 'simulation-missing-body'), isFalse);
      final bad = lintWith((l) => (l['blocks'] as List).add({
            'sort_order': 99,
            'block_type': 'simulation',
            'content': {'simulation_id': 'x', 'fallback_body': 'Not the field the database checks.'},
          }));
      expect(bad.any((i) => i.rule == 'simulation-missing-body' && i.level == 'ERROR'), isTrue);
    });

    test('a performance task must match the DB check and be usable (plan §8.8)', () {
      Map<String, dynamic> task() => {
            'title': 'Build it',
            'body': 'Fallback text.',
            'brief': 'Do the work.',
            'exemplar': 'What good looks like.',
            'verification': 'self_check',
            'criteria': [
              {'id': 'a', 'text': 'First'},
              {'id': 'b', 'text': 'Second'},
            ],
          };
      List<LintIssue> withTask(Map<String, dynamic> content) => lintWith((l) => (l['blocks'] as List)
          .add({'sort_order': 99, 'block_type': 'performance_task', 'content': content}));
      bool has(List<LintIssue> issues, String rule) =>
          issues.any((i) => i.rule == rule && i.level == 'ERROR');

      final ok = withTask(task());
      expect(ok.where((i) => i.rule.startsWith('performance-task')), isEmpty);
      expect(ok.where((i) => i.rule == 'json-schema'), isEmpty);
      for (final key in ['title', 'body', 'brief', 'exemplar']) {
        expect(has(withTask(task()..remove(key)), 'performance-task-missing-$key'), isTrue, reason: key);
      }
      expect(has(withTask(task()..['verification'] = 'checker'), 'performance-task-verification'), isTrue);
      expect(has(withTask(task()..['criteria'] = [{'text': 'one'}]), 'performance-task-criteria'), isTrue);
      expect(has(withTask(task()..['criteria'] = ['a', 'b']), 'performance-task-criteria'), isTrue);
      expect(has(withTask(task()..['criteria'] = [{'text': 'a'}, {'text': ' '}]), 'performance-task-criteria'), isTrue);
    });

    test('a teaching-only lesson cannot carry assessment items', () {
      final issues = lintWith((l) => l['tags'] = [...(l['tags'] as List), 'teaching-only']);
      expect(issues.any((i) => i.rule == 'teaching-only-has-assessments' && i.level == 'ERROR'), isTrue);
    });
  });
}

