import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('CaseStandardsConverter (1EdTech CASE 1.0, ECO-13, OPP-5)', () {
    const items = [
      CaseCompetencyItem(
        identifier: 'cna-std-01',
        humanCodingScheme: 'CNA.1.1',
        fullStatement: 'Demonstrate proper 20-second hand hygiene prior to resident contact.',
        conceptSlug: 'cna-hand-hygiene',
      ),
      CaseCompetencyItem(
        identifier: 'cna-std-02',
        humanCodingScheme: 'CNA.1.2',
        fullStatement: 'Measure and record radial pulse within +/- 2 BPM accuracy.',
        conceptSlug: 'cna-radial-pulse',
        parentIdentifier: 'cna-std-01',
      ),
    ];

    test('exports competencies to compliant 1EdTech CASE 1.0 JSON-LD package', () {
      final casePkg = CaseStandardsConverter.exportPackage(
        documentId: 'doc-prometric-cna-2024',
        title: 'Prometric Clinical Skills Standards: CNA Licensure',
        description: 'Standardized clinical competency framework for Nurse Aides.',
        publisher: 'Prometric / State Board of Nursing',
        version: '2024.1',
        items: items,
      );

      expect(casePkg['@context'], equals(CaseStandardsConverter.caseContext));
      expect(casePkg['CFDocument']['identifier'], equals('doc-prometric-cna-2024'));
      expect(casePkg['CFDocument']['publisher'], equals('Prometric / State Board of Nursing'));

      final cfItems = (casePkg['CFItems'] as List).cast<Map<String, dynamic>>();
      expect(cfItems.length, equals(2));
      expect(cfItems.first['humanCodingScheme'], equals('CNA.1.1'));
      expect(cfItems.first['conceptKeyword'], equals('cna-hand-hygiene'));

      final cfAssoc = (casePkg['CFAssociations'] as List).cast<Map<String, dynamic>>();
      expect(cfAssoc.length, equals(1));
      expect(cfAssoc.first['associationType'], equals('isChildOf'));
      expect(cfAssoc.first['originNodeURI'], contains('cna-std-02'));
      expect(cfAssoc.first['destinationNodeURI'], contains('cna-std-01'));
    });

    test('imports 1EdTech CASE 1.0 JSON-LD package into summary model', () {
      final exported = CaseStandardsConverter.exportPackage(
        documentId: 'doc-test',
        title: 'Test Document',
        description: 'Description',
        publisher: 'Test Publisher',
        items: items,
      );

      final imported = CaseStandardsConverter.importPackage(exported);

      expect(imported.identifier, equals('doc-test'));
      expect(imported.title, equals('Test Document'));
      expect(imported.publisher, equals('Test Publisher'));
      expect(imported.items.length, equals(2));
      expect(imported.items.first.identifier, equals('cna-std-01'));
      expect(imported.items.first.humanCodingScheme, equals('CNA.1.1'));
    });
  });
}
