import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
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
  test('supported reviewed credentials map to correct private-goal types', () {
    final entry = VerifiedDestination.fromJson(sample());
    expect(entry.supportedPrivateGoalType, TargetType.certification);

    final rn = sample()..['destination_type'] = 'licensure_exam';
    expect(VerifiedDestination.fromJson(rn).supportedPrivateGoalType,
        TargetType.licensureExam);

    final license = sample()..['destination_type'] = 'professional_license';
    expect(VerifiedDestination.fromJson(license).supportedPrivateGoalType,
        isNull); // Never disguise a professional license as a certification.
  });

  test('official preparation resource parses issuer-owned link metadata', () {
    final link = OfficialPreparationLink.fromJson({
      'resource_key': 'az900-guide',
      'title': 'Microsoft AZ-900 Study Guide',
      'resource_kind': 'official_study_guide',
      'resource_url':
          'https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-900',
      'source_publisher': 'Microsoft Learn',
    });
    expect(link.resourceTypeLabel, 'Official study guide');
    expect(link.resourceUrl.scheme, 'https');
  });

  test('refuse non-HTTPS preparation resources', () {
    expect(
      () => OfficialPreparationLink.fromJson({
        'resource_key': 'invalid',
        'title': 'Untrusted',
        'resource_kind': 'issuer_training',
        'resource_url': 'http://unsafe.test/',
        'source_publisher': 'Unknown',
      }),
      throwsFormatException,
    );
  });

}
