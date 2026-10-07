import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

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
  });
}

