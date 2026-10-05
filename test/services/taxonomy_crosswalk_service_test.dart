import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/taxonomy/taxonomy_crosswalk_service.dart';

void main() {
  group('Phase F: TaxonomyCrosswalkService Unit Tests', () {
    late TaxonomyCrosswalkService service;

    setUp(() {
      // In offline/mock mode (null client), service uses comprehensive fallback
      service = TaxonomyCrosswalkService(supabaseClient: null);
    });

    test('getCatalogClusters returns presentation clusters', () async {
      final clusters = await service.getCatalogClusters();
      expect(clusters, isNotEmpty);
      expect(clusters.length, 12);
      expect(clusters.any((c) => c.slug == 'computing-tech'), isTrue);
      expect(clusters.any((c) => c.slug == 'health-medicine'), isTrue);
      expect(clusters.any((c) => c.slug == 'engineering-tech'), isTrue);
    });

    test('getFields returns canonical fields', () async {
      final fields = await service.getFields();
      expect(fields, isNotEmpty);
      expect(fields.any((f) => f.slug == 'computer-sciences'), isTrue);
      expect(fields.any((f) => f.slug == 'mathematics-statistics-series'), isTrue);
    });

    test('getFieldBySlug resolves field properly', () async {
      final field = await service.getFieldBySlug('computer-sciences');
      expect(field, isNotNull);
      expect(field!.name, contains('Computer and Information Sciences'));

      final nonExistent = await service.getFieldBySlug('non-existent-field-xyz');
      expect(nonExistent, isNull);
    });

    test('getOccupationNodes returns 5-tier labor taxonomy', () async {
      final occupations = await service.getOccupationNodes();
      expect(occupations, isNotEmpty);
      expect(occupations.any((o) => o.code == '15-0000'), isTrue);
      expect(occupations.any((o) => o.code == '15-1252'), isTrue);
      expect(occupations.any((o) => o.code == '15-1252.00'), isTrue);
    });

    test('getOccupationByCode resolves exact SOC codes', () async {
      final occ = await service.getOccupationByCode('15-1252');
      expect(occ, isNotNull);
      expect(occ!.title, 'Software Developers');
      expect(occ.jobZone, 4);

      final onet = await service.getOccupationByCode('15-1252.00');
      expect(onet, isNotNull);
      expect(onet!.isOnetExtension, isTrue);
      expect(onet.taxonomySystem, 'onet_soc');
    });

    test('getTargetOccupations returns linked occupational crosswalk', () async {
      final crosswalks = await service.getTargetOccupations('target-bs-cs');
      expect(crosswalks, isNotEmpty);

      final dev = crosswalks.firstWhere((c) => c.occupationCode == '15-1252');
      expect(dev.occupationTitle, 'Software Developers');
      expect(dev.isPrimaryField, isTrue);
      expect(dev.classificationCode, '11.0701');
      expect(dev.jobZoneLabel, contains('Job Zone 4: Considerable Preparation'));
    });
  });
}
