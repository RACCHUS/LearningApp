import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/taxonomy/official_taxonomy_sources.dart';

void main() {
  group('OfficialTaxonomyParser', () {
    test('parseCsv handles quoted commas, quotes, and embedded newlines', () {
      const csv =
          'Code,Title,Definition\r\n'
          '11.0701,"Computer Science","Theory, systems, and ""software""."\r\n'
          '13.0101,Education,"Line one\nLine two"\r\n';

      final rows = OfficialTaxonomyParser.parseCsv(csv);

      expect(rows, hasLength(3));
      expect(rows[1][1], 'Computer Science');
      expect(rows[1][2], 'Theory, systems, and "software".');
      expect(rows[2][2], 'Line one\nLine two');
    });

    test('parseCip2020Csv builds complete hierarchy semantics', () {
      const csv =
          'CIPFamily,CIPCode,CIPTitle,CIPDefinition,CrossReferences,Examples,Action,TextChange\n'
          '11,11,COMPUTER AND INFORMATION SCIENCES.,Broad family,,,No Substantive Changes,\n'
          '11,11.07,Computer Science.,Group definition,,,No Substantive Changes,\n'
          '11,11.0701,Computer Science.,Program definition,"11.0101; 30.1601","Software; Algorithms",No Substantive Changes,Yes\n';

      final records = OfficialTaxonomyParser.parseCip2020Csv(csv);

      expect(records, hasLength(3));
      expect(records[0]['level_code'], 'series');
      expect(records[0]['source_parent_code'], isNull);
      expect(records[1]['level_code'], 'group');
      expect(records[1]['source_parent_code'], '11');
      expect(records[2]['level_code'], 'program');
      expect(records[2]['source_parent_code'], '11.07');
      expect(records[2]['cross_references'], ['11.0101', '30.1601']);
      expect(records[2]['illustrative_examples'], ['Software', 'Algorithms']);
      expect(
        (records[2]['metadata'] as Map<String, dynamic>)['text_change'],
        'Yes',
      );
    });

    test('parseSoc2018Rows understands official four-column layout', () {
      final definitions = OfficialTaxonomyParser.parseSoc2018DefinitionsRows([
        ['2018 SOC Code', '2018 SOC Title', '2018 SOC Definition'],
        [
          '11-1011',
          'Chief Executives',
          'Determine and formulate policies and provide overall direction.'
        ],
      ]);

      final records = OfficialTaxonomyParser.parseSoc2018Rows(
        [
          ['Major Group', 'Minor Group', 'Broad Group', 'Detailed Occupation'],
          ['11-0000', '', '', 'Management Occupations'],
          ['', '11-1000', '', 'Top Executives'],
          ['', '', '11-1010', 'Chief Executives'],
          ['', '', '', '11-1011 Chief Executives'],
        ],
        definitions: definitions,
      );

      expect(records, hasLength(4));
      expect(records[0]['level'], 'major_group');
      expect(records[1]['level'], 'minor_group');
      expect(records[2]['level'], 'broad_occupation');
      expect(records[3]['level'], 'detailed_occupation');
      expect(records[3]['title'], 'Chief Executives');
      expect(records[3]['description'], startsWith('Determine and formulate'));
    });

    test('parseOnet31Rows joins occupation data with Job Zones', () {
      final records = OfficialTaxonomyParser.parseOnet31Rows(
        occupationRows: [
          ['O*NET-SOC Code', 'Title', 'Description'],
          [
            '15-1252.00',
            'Software Developers',
            'Research, design, and develop software.'
          ],
          [
            '15-1253.00',
            'Software Quality Assurance Analysts and Testers',
            'Develop and execute software tests.'
          ],
        ],
        jobZoneRows: [
          ['O*NET-SOC Code', 'Title', 'Job Zone', 'Date', 'Domain Source'],
          ['15-1252.00', 'Software Developers', '4', '08/2026', 'Analyst'],
        ],
      );

      expect(records, hasLength(2));
      expect(records[0]['taxonomy_version'], '2019');
      expect(records[0]['data_release_version'], 'onet_31_0');
      expect(records[0]['job_zone'], 4);
      expect(
        (records[0]['metadata'] as Map<String, dynamic>)['is_data_level'],
        isTrue,
      );
      expect(records[1]['job_zone'], isNull);
      expect(
        (records[1]['metadata'] as Map<String, dynamic>)['is_data_level'],
        isFalse,
      );
    });

    test('parseCip2020Csv ignores reserved placeholder series', () {
      const csv =
          'CIPFamily,CIPCode,CIPTitle,CIPDefinition,CrossReferences,Examples,Action,TextChange\n'
          '11,11,COMPUTER AND INFORMATION SCIENCES.,Broad family,,,No Substantive Changes,\n'
          '21,21,RESERVED.,,,,No Substantive Changes,\n'
          '55,55,RESERVED.,,,,No Substantive Changes,\n'
          '11,11.0701,Computer Science.,Program definition,,,No Substantive Changes,\n';

      final records = OfficialTaxonomyParser.parseCip2020Csv(csv);

      expect(records, hasLength(2));
      expect(records.map((r) => r['code']), ['11', '11.0701']);
      expect(
        records.any((r) => r['code'] == '21' || r['code'] == '55'),
        isFalse,
      );
    });

    test('parseCipSocCrosswalkRows deduplicates exact federal mappings', () {
      final rows = [
        ['CIP 2020 Code', 'CIP 2020 Title', 'SOC 2018 Code', 'SOC 2018 Title'],
        ['11.0701', 'Computer Science', '15-1252', 'Software Developers'],
        ['11.0701', 'Computer Science', '15-1252', 'Software Developers'],
        [
          '11.1003',
          'Computer and Information Systems Security',
          '15-1212',
          'Information Security Analysts'
        ],
      ];

      final mappings =
          OfficialTaxonomyParser.parseCipSocCrosswalkRows(rows);

      expect(mappings, hasLength(2));
      expect(mappings.first.cipCode, '11.0701');
      expect(mappings.first.socCode, '15-1252');
    });

    test('parseCipSocCrosswalkRows excludes federal NO MATCH sentinels', () {
      final rows = [
        ['CIP 2020 Code', 'CIP 2020 Title', 'SOC 2018 Code', 'SOC 2018 Title'],
        ['11.0701', 'Computer Science', '15-1252', 'Software Developers'],
        ['01.0508', 'Taxidermy/Taxidermist.', '99-9999', 'NO MATCH'],
        ['99.9999', 'NO MATCH', '13-1074', 'Farm Labor Contractors'],
      ];

      final mappings =
          OfficialTaxonomyParser.parseCipSocCrosswalkRows(rows);

      expect(mappings, hasLength(1));
      expect(mappings.single.cipCode, '11.0701');
      expect(mappings.single.socCode, '15-1252');
    });

    test('CIP lineage derives splits, merges, additions, and deletions', () {
      const csv =
          'CIPCode2010,CIPTitle2010,Action,CIPCode2020,CIPTitle2020\n'
          '11.0101,Old A,Split,11.0101,New A\n'
          '11.0101,Old A,Split,11.0102,New B\n'
          '11.0201,Old C,Merge,11.0301,Combined\n'
          '11.0202,Old D,Merge,11.0301,Combined\n'
          '11.0401,Same,No change,11.0401,Same\n'
          '11.0501,Old title,Title change,11.0501,New title\n'
          '11.0601,Deleted,Deleted,,\n'
          ',,New,11.0701,Introduced\n';

      final rows =
          OfficialTaxonomyParser.parseCip2010To2020Lineage(csv);

      expect(
        rows.where((row) => row['transition_type'] == 'split_into'),
        hasLength(2),
      );
      expect(
        rows.where((row) => row['transition_type'] == 'merged_into'),
        hasLength(2),
      );
      expect(
        rows.singleWhere((row) => row['from_code'] == '11.0401')[
            'transition_type'],
        'unchanged',
      );
      expect(
        rows.singleWhere((row) => row['from_code'] == '11.0501')[
            'transition_type'],
        'renamed',
      );
      expect(
        rows.singleWhere((row) => row['from_code'] == '11.0601')[
            'transition_type'],
        'deleted',
      );
      expect(
        rows.singleWhere((row) => row['to_code'] == '11.0701')[
            'transition_type'],
        'newly_introduced',
      );
    });

    test('SOC lineage derives cross-version code movement', () {
      final rows = [
        ['2010 SOC Code', '2010 SOC Title', '2018 SOC Code', '2018 SOC Title'],
        [
          '15-1132',
          'Software Developers, Applications',
          '15-1252',
          'Software Developers'
        ],
      ];

      final lineage =
          OfficialTaxonomyParser.parseSoc2010To2018Lineage(rows);

      expect(lineage, hasLength(1));
      expect(lineage.single['transition_type'], 'moved_to');
      expect(lineage.single['source_system'], 'bls_soc');
    });

    test('validateBundle fails closed on sample/truncated datasets', () {
      final report = OfficialTaxonomyParser.validateBundle(
        cipRecords: const [
          {'code': '11', 'level_code': 'series'},
          {'code': '11.0701', 'level_code': 'program'},
        ],
        socRecords: const [
          {'code': '15-0000', 'level': 'major_group'},
          {'code': '15-1252', 'level': 'detailed_occupation'},
        ],
        onetRecords: const [
          {'code': '15-1252.00', 'job_zone': 4},
        ],
        cipSocMappings: const [
          OfficialCipSocMapping(
            cipCode: '11.0701',
            socCode: '15-1252',
          ),
        ],
      );

      expect(report.isValid, isFalse);
      expect(report.errors, isNotEmpty);
      expect(report.throwIfInvalid, throwsStateError);
    });

    test('source manifest pins every authoritative artifact', () {
      expect(OfficialTaxonomySources.artifacts.keys, containsAll([
        'CIPCode2020.csv',
        'Crosswalk2010to2020.csv',
        'CIP2020_SOC2018_Crosswalk.xlsx',
        'soc_structure_2018.xlsx',
        'soc_2018_definitions.xlsx',
        'soc_2010_to_2018_crosswalk.xlsx',
        'Occupation Data.xlsx',
        'Job Zones.xlsx',
      ]));
      expect(OfficialTaxonomySources.manifestJson(), contains('onet_31_0'));
    });

    test('artifact specs pin cryptographic hashes and file sizes', () {
      expect(OfficialTaxonomySources.specs.length, 8);

      for (final spec in OfficialTaxonomySources.specs.values) {
        expect(
          RegExp(r'^[a-f0-9]{64}$').hasMatch(spec.expectedSha256),
          isTrue,
          reason: '${spec.name} must have a valid 64-char lowercase hex sha256',
        );
        expect(
          spec.expectedSizeBytes,
          greaterThan(10000),
          reason: '${spec.name} file size should be substantial',
        );
        expect(Uri.tryParse(spec.publisherUrl)?.hasScheme, isTrue);
        expect(Uri.tryParse(spec.retrievalUrl)?.hasScheme, isTrue);
      }

      // Verify provenance disentangling (BLS publisher vs Census/Archive retrieval)
      final socStructure = OfficialTaxonomySources.specs['soc_structure_2018.xlsx']!;
      expect(socStructure.publisherUrl, contains('bls.gov'));
      expect(socStructure.retrievalUrl, contains('census.gov'));

      final socCrosswalk = OfficialTaxonomySources.specs['soc_2010_to_2018_crosswalk.xlsx']!;
      expect(socCrosswalk.publisherUrl, contains('bls.gov'));
      expect(socCrosswalk.retrievalUrl, contains('web.archive.org'));
    });
  });
}
