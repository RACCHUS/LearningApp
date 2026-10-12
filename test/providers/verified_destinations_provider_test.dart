import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/verified_destinations_provider.dart';

void main() {
  Map<String, dynamic> sample() => {
        'source_namespace': 'pmi',
        'source_key': 'pmp',
        'title': 'Project Management Professional (PMP)',
        'issuer_name': 'Project Management Institute',
        'destination_type': 'certification',
        'jurisdiction': 'Global',
        'official_url': 'https://www.pmi.org/certifications/project-management-pmp',
        'requirements_status': 'not_verified',
        'popularity_status': 'not_measured',
        'verified_at': '2026-10-11T23:00:00Z',
      };

  test('issuer-reviewed listing is an identity only, not a course or rank', () {
    final item = VerifiedDestination.fromJson(sample());
    expect(item.displayType, 'Certification');
    expect(item.officialUrl.host, 'www.pmi.org');
    expect(item.requirementsStatus, 'not_verified');
    expect(item.popularityStatus, 'not_measured');
  });

  test('search includes credential name, issuer, region and type', () {
    final item = VerifiedDestination.fromJson(sample());
    expect(item.matches('  pMp '), isTrue);
    expect(item.matches('project management institute'), isTrue);
    expect(item.matches('certification'), isTrue);
    expect(item.matches('global'), isTrue);
    expect(item.matches('nonexistent'), isFalse);
  });

  test('never accept insecure or malformed external issuer links', () {
    final data = sample();
    data['official_url'] = 'http://example.org/exam';
    expect(() => VerifiedDestination.fromJson(data), throwsFormatException);
    data['official_url'] = 'not a URL';
    expect(() => VerifiedDestination.fromJson(data), throwsFormatException);
  });
}
