import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/taxonomy/taxonomy_importer.dart';

void main() {
  group('Phase F: TaxonomyImporter Unit Tests', () {
    test('calculateChecksum produces standard deterministic SHA256', () {
      const data = 'CIP 2020 Standard Taxonomy';
      final hash1 = TaxonomyImporter.calculateChecksum(data);
      final hash2 = TaxonomyImporter.calculateChecksum(data);
      expect(hash1, hash2);
      expect(hash1.length, 64);
    });

    test('deterministicUuid produces stable RFC-4122 database-safe IDs', () {
      final first = TaxonomyImporter.deterministicUuid('cip|2020|11.0701');
      final second = TaxonomyImporter.deterministicUuid('cip|2020|11.0701');
      final other = TaxonomyImporter.deterministicUuid('cip|2020|11.1003');

      expect(first, second);
      expect(first, isNot(other));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(first),
        isTrue,
      );
    });

    test('parseCipNodes performs two-pass parent resolution', () {
      final raw = [
        {
          'code': '11',
          'title': 'Computer and Information Sciences and Support Services',
          'level_code': 'series',
        },
        {
          'code': '11.07',
          'title': 'Computer Science',
          'level_code': 'group',
          'source_parent_code': '11',
        },
        {
          'code': '11.0701',
          'title': 'Computer Science',
          'level_code': 'program',
          'source_parent_code': '11.07',
          'definition': 'General theoretical and practical computer science.',
          'cross_references': ['11.0101'],
        },
      ];

      final nodes = TaxonomyImporter.parseCipNodes(
        rawRecords: raw,
        sourceReleaseId: 'rel-cip-2020',
        version: '2020',
      );

      expect(nodes.length, 3);

      final series = nodes.firstWhere((n) => n.code == '11');
      final group = nodes.firstWhere((n) => n.code == '11.07');
      final program = nodes.firstWhere((n) => n.code == '11.0701');

      expect(series.parentId, isNull);
      expect(group.parentId, series.id);
      expect(program.parentId, group.id);
      expect(program.levelDepth, 3);
      expect(program.crossReferences, contains('11.0101'));
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(series.id), isTrue);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(program.id), isTrue);
    });

    test('parseOccupationNodes enforces 5-tier parentage and O*NET segregation', () {
      final raw = [
        {
          'code': '15-0000',
          'title': 'Computer and Mathematical Occupations',
          'level': 'major_group',
        },
        {
          'code': '15-1200',
          'title': 'Computer Occupations',
          'level': 'minor_group',
        },
        {
          'code': '15-1250',
          'title': 'Software and Web Developers',
          'level': 'broad_occupation',
        },
        {
          'code': '15-1252',
          'title': 'Software Developers',
          'level': 'detailed_occupation',
          'job_zone': 4,
        },
        {
          'code': '15-1252.00',
          'title': 'Software Developers (O*NET)',
          'level': 'onet_extension',
          'job_zone': 4,
        },
      ];

      final occupations = TaxonomyImporter.parseOccupationNodes(
        rawRecords: raw,
        baseSourceReleaseId: 'rel-soc-2018',
        onetSourceReleaseId: 'rel-onet-31',
      );

      expect(occupations.length, 5);

      final major = occupations.firstWhere((o) => o.code == '15-0000');
      final minor = occupations.firstWhere((o) => o.code == '15-1200');
      final broad = occupations.firstWhere((o) => o.code == '15-1250');
      final detailed = occupations.firstWhere((o) => o.code == '15-1252');
      final onet = occupations.firstWhere((o) => o.code == '15-1252.00');

      // Parent link chain
      expect(minor.parentId, major.id);
      expect(broad.parentId, minor.id);
      expect(detailed.parentId, broad.id);
      expect(onet.parentId, detailed.id);

      // Check constraints
      expect(detailed.taxonomySystem, 'bls_soc');
      expect(detailed.dataReleaseVersion, isNull);

      expect(onet.taxonomySystem, 'onet_soc');
      expect(onet.taxonomyVersion, '2019');
      expect(onet.dataReleaseVersion, 'onet_31_0');
      expect(onet.sourceReleaseId, 'rel-onet-31');
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(detailed.id), isTrue);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(onet.id), isTrue);
    });

    test('parseLineageRecords validates transition types and nullable endpoints', () {
      final valid = [
        {
          'source_system': 'cip',
          'from_version': '2010',
          'from_code': '11.0701',
          'to_version': '2020',
          'to_code': '11.0701',
          'transition_type': 'unchanged',
        },
        {
          'source_system': 'cip',
          'from_version': '2010',
          'from_code': '51.9999',
          'to_version': '2020',
          'to_code': null,
          'transition_type': 'deleted',
        },
        {
          'source_system': 'cip',
          'from_version': '2010',
          'from_code': null,
          'to_version': '2020',
          'to_code': '30.7001',
          'transition_type': 'newly_introduced',
        },
      ];

      final results = TaxonomyImporter.parseLineageRecords(valid);
      expect(results.length, 3);
      expect(results[1].transitionType, 'deleted');
      expect(results[1].toCode, isNull);
      expect(results[2].transitionType, 'newly_introduced');
      expect(results[2].fromCode, isNull);

      // Invalid deleted transition (has to_code)
      expect(
        () => TaxonomyImporter.parseLineageRecords([
          {
            'source_system': 'cip',
            'from_version': '2010',
            'from_code': '11.0101',
            'to_version': '2020',
            'to_code': '11.0101',
            'transition_type': 'deleted', // Invalid: to_code must be null
          }
        ]),
        throwsFormatException,
      );

      // Invalid unknown transition type
      expect(
        () => TaxonomyImporter.parseLineageRecords([
          {
            'source_system': 'cip',
            'from_version': '2010',
            'from_code': '11.0101',
            'to_version': '2020',
            'to_code': '11.0101',
            'transition_type': 'invalid_transition_type',
          }
        ]),
        throwsFormatException,
      );
    });
  });
}
