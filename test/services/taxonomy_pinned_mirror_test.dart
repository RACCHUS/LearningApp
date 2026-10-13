import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/taxonomy/official_taxonomy_sources.dart';

void main() {
  test('BLS crosswalk fallback stays pinned to the same federal bytes', () {
    const name = 'soc_2010_to_2018_crosswalk.xlsx';
    final spec = OfficialTaxonomySources.specs[name]!;
    final mirrors = OfficialTaxonomySources.fallbackRetrievalUrls[name]!;

    expect(spec.publisherUrl,
        'https://www.bls.gov/soc/2018/soc_2010_to_2018_crosswalk.xlsx');
    expect(spec.expectedSizeBytes, 46630);
    expect(spec.expectedSha256,
        'f3a847561562d3e5a30eb848f2902a5f7b02e9c48b3d7f2cc8879899fbc242a7');
    expect(mirrors, hasLength(1));
    expect(
      mirrors.single,
      'https://raw.githubusercontent.com/theis188/us-jobs-data/'
      'c8d6ade6f007f5b3d546d6b4857b160fdd0405ce/'
      'soc_2010_to_2018_crosswalk.xlsx',
    );
    expect(Uri.parse(mirrors.single).scheme, 'https');
    expect(Uri.parse(spec.retrievalUrl).host, 'web.archive.org');
  });

  test('other pinned federal sources cannot silently use a mirror', () {
    for (final source in OfficialTaxonomySources.specs.values) {
      if (source.name == 'soc_2010_to_2018_crosswalk.xlsx') continue;
      expect(OfficialTaxonomySources.fallbackRetrievalUrls[source.name],
          isNull);
    }
  });
}
