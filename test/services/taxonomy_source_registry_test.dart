import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> registry;

  setUpAll(() {
    registry = Map<String, dynamic>.from(
      jsonDecode(File('data/taxonomy/source_registry.json').readAsStringSync())
          as Map,
    );
  });

  test('source registry has unique documented, non-published source IDs', () {
    expect(registry['schema_version'], 1);
    final sources = (registry['sources'] as List).cast<Map<String, dynamic>>();
    expect(sources, isNotEmpty);
    final ids = <String>{};
    for (final source in sources) {
      final id = source['id'] as String;
      expect(ids.add(id), isTrue, reason: 'Duplicate source: $id');
      expect(Uri.tryParse(source['url'] as String)?.hasAuthority, isTrue);
      expect((source['rights'] as String).trim(), isNotEmpty);
      expect((source['cadence'] as String).trim(), isNotEmpty);
      expect((source['status'] as String).trim(), isNotEmpty);
    }
  });

  test('release-specific counts reference valid sources and query columns', () {
    final sources = (registry['sources'] as List)
        .cast<Map<String, dynamic>>()
        .map((source) => source['id'] as String)
        .toSet();
    final checks =
        (registry['coverage_checks'] as List).cast<Map<String, dynamic>>();
    final ids = <String>{};
    for (final check in checks) {
      expect(ids.add(check['id'] as String), isTrue);
      expect(sources.contains(check['source_id']), isTrue);
      expect((check['table'] as String), matches(RegExp(r'^[a-z_]+$')));
      final filters = Map<String, String>.from(check['filters'] as Map);
      expect(filters, isNotEmpty);
      for (final entry in filters.entries) {
        expect(entry.key, matches(RegExp(r'^[a-z_]+$')));
        expect(entry.value.startsWith('eq.'), isTrue);
      }
      final expected = check['expected'];
      expect(expected == null || (expected is int && expected > 0), isTrue);
    }

    final expectedCounts = {
      'cip_2020_series': 48,
      'soc_2018_major': 23,
      'soc_2018_minor': 98,
      'soc_2018_broad': 459,
      'soc_2018_detailed': 867,
      'onet_31_0_extensions': 1016,
    };
    for (final check in checks) {
      final id = check['id'];
      if (expectedCounts.containsKey(id)) {
        expect(check['expected'], expectedCounts[id]);
      }
    }
    expect(checks.map((check) => check['id']).toSet(),
        containsAll(expectedCounts.keys));
  });

  test('all six learnable target types are included in the baseline', () {
    expect(
      (registry['target_types'] as List).cast<String>().toSet(),
      {
        'career',
        'academic_program',
        'certification',
        'licensure_exam',
        'standardized_exam',
        'curriculum_standard',
      },
    );
  });
}
