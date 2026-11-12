// Stable authored item IDs (plan PR-2b): target-aware linter enforcement and
// ingestion propagation into assessment_items.metadata.source_item_id.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/ingest_curriculum.dart';
import '../../tool/lint_manifest.dart';

Map<String, dynamic> _load(String path) =>
    jsonDecode(jsonEncode(loadYaml(File(path).readAsStringSync()))) as Map<String, dynamic>;

Map<String, dynamic> _algebra() => _load('content/clep_college_algebra.yaml');

List<Map<String, dynamic>> _lessons(Map<String, dynamic> m) => [
      for (final d in m['domains'] as List)
        for (final o in (d as Map)['objectives'] as List)
          for (final l in (o as Map)['lessons'] as List) (l as Map).cast<String, dynamic>(),
    ];

List<LintIssue> _idIssues(Map<String, dynamic> manifest, {String path = 'content/clep_college_algebra.yaml'}) {
  final linter = ManifestLinter()..lint(path, manifest);
  return linter.issues.where((i) => i.rule == 'stable-item-id').toList();
}

void main() {
  group('College Algebra authored IDs', () {
    test('committed manifest has 60 simulation + 40 formative unique ids and lints clean', () {
      final m = _algebra();
      final sim = [for (final l in _lessons(m)) ...(l['assessment_items'] as List? ?? const [])];
      final fmt = [for (final l in _lessons(m)) ...(l['questions'] as List? ?? const [])];
      expect(sim, hasLength(60));
      expect(fmt, hasLength(40));
      final ids = [...sim, ...fmt].map((i) => (i as Map)['id']).toList();
      expect(ids.toSet(), hasLength(100));
      expect(ids.where((id) => (id as String).startsWith('alg-sim-')), hasLength(60));
      expect(ids.where((id) => (id as String).startsWith('alg-fmt-')), hasLength(40));
      expect(_idIssues(m), isEmpty);
    });

    test('missing id on an algebra item is an error', () {
      final m = _algebra();
      ((_lessons(m).first['assessment_items'] as List).first as Map).remove('id');
      final issues = _idIssues(m);
      expect(issues, hasLength(1));
      expect(issues.single.level, 'ERROR');
      expect(issues.single.message, contains('requires a stable authored id'));
    });

    test('missing id on a formative algebra question is an error', () {
      final m = _algebra();
      ((_lessons(m).first['questions'] as List).first as Map).remove('id');
      expect(_idIssues(m), hasLength(1));
    });

    test('duplicate, blank and malformed ids are errors', () {
      final m = _algebra();
      final items = _lessons(m).first['assessment_items'] as List;
      (items[1] as Map)['id'] = (items[0] as Map)['id'];
      (items[2] as Map)['id'] = '';
      ((_lessons(m)[1]['assessment_items'] as List).first as Map)['id'] = 'Alg_Bad ID';
      final messages = _idIssues(m).map((i) => i.message).toList();
      expect(messages.where((msg) => msg.contains('Duplicate item id')), hasLength(1));
      expect(messages.where((msg) => msg.contains('lowercase kebab-case')), hasLength(2));
    });

    test('enforcement follows target slug, not file name', () {
      final m = _algebra();
      ((_lessons(m).first['assessment_items'] as List).first as Map).remove('id');
      expect(_idIssues(m, path: 'content/renamed_course.yaml'), hasLength(1));
    });

    test('reordering items keeps ids and stays lint clean', () {
      final m = _algebra();
      final before = collectAssessmentItemIds(m, fromMetadata: false).toSet();
      for (final l in _lessons(m)) {
        final items = l['assessment_items'] as List?;
        if (items != null) l['assessment_items'] = items.reversed.toList();
      }
      expect(collectAssessmentItemIds(m, fromMetadata: false).toSet(), before);
      expect(_idIssues(m), isEmpty);
    });
  });

  group('Other targets', () {
    test('manifests without ids stay valid (Psychology)', () {
      final m = _load('content/clep_introductory_psychology.yaml');
      expect(collectAssessmentItemIds(m, fromMetadata: false), isEmpty);
      expect(_idIssues(m, path: 'content/clep_introductory_psychology.yaml'), isEmpty);
    });

    test('optional ids on other targets are still checked for duplicates', () {
      final m = _load('content/clep_introductory_psychology.yaml');
      final items = [
        for (final l in _lessons(m)) ...(l['assessment_items'] as List? ?? const []),
      ];
      expect(items.length, greaterThan(1));
      (items[0] as Map)['id'] = 'psy-sim-shared';
      (items[1] as Map)['id'] = 'psy-sim-shared';
      final issues = _idIssues(m, path: 'content/clep_introductory_psychology.yaml');
      expect(issues.map((i) => i.message), [contains('Duplicate item id "psy-sim-shared"')]);
    });
  });

  group('Ingestion identity propagation', () {
    test('assessmentItemMetadata copies id into source_item_id without mutating input', () {
      final item = {
        'id': 'alg-sim-x',
        'metadata': {'bank': 'simulation_exam'},
      };
      final meta = assessmentItemMetadata(item);
      expect(meta, {'bank': 'simulation_exam', 'source_item_id': 'alg-sim-x'});
      expect(item['metadata'], {'bank': 'simulation_exam'});
    });

    test('items without id keep their metadata unchanged', () {
      expect(assessmentItemMetadata({'metadata': {'bank': 'practice'}}), {'bank': 'practice'});
      expect(assessmentItemMetadata(<String, dynamic>{}), isEmpty);
    });

    test('conflicting or blank ids fail closed', () {
      expect(
        () => assessmentItemMetadata({
          'id': 'alg-sim-a',
          'metadata': {'source_item_id': 'alg-sim-b'},
        }),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('conflicts'))),
      );
      expect(() => assessmentItemMetadata({'id': ' '}), throwsA(isA<Exception>()));
      expect(() => assessmentItemMetadata({'id': 7}), throwsA(isA<Exception>()));
    });

    test('real algebra payload carries all 60 simulation ids in document order', () {
      final m = _algebra();
      final payload = prepareManifestPayloadForTesting(
        manifest: m,
        targetSlug: 'clep-college-algebra',
        versionCode: '2026',
      );
      final authored = collectAssessmentItemIds(m, fromMetadata: false);
      expect(authored, hasLength(60));
      expect(collectAssessmentItemIds(payload, fromMetadata: true), authored);
    });

    test('a mapper that drops ids would be detected', () {
      final m = _algebra();
      final payload = prepareManifestPayloadForTesting(
        manifest: m,
        targetSlug: 'clep-college-algebra',
        versionCode: '2026',
      );
      // Simulate the pre-PR-2b mapper: strip source_item_id from one item.
      void stripFirst(dynamic n) {
        if (n is Map) {
          final meta = n['metadata'];
          if (n.containsKey('prompt') && meta is Map && meta.remove('source_item_id') != null) {
            throw StateError('stripped');
          }
          n.values.forEach(stripFirst);
        } else if (n is List) {
          n.forEach(stripFirst);
        }
      }

      expect(() => stripFirst(payload), throwsStateError);
      expect(
        collectAssessmentItemIds(payload, fromMetadata: true),
        isNot(collectAssessmentItemIds(m, fromMetadata: false)),
      );
    });
  });
}
