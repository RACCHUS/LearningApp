import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('OpenBadgeConverter (1EdTech Open Badges 3.0 / W3C VC)', () {
    test('creates compliant Open Badges 3.0 Verifiable Credential', () {
      final credential = OpenBadgeConverter.createBadgeCredential(
        credentialId: 'urn:uuid:credential-civics-101',
        recipientId: 'did:key:z6MkhaXgBZDvotDkL5257faiz48Z8x28zzqy9Nn6nwAZnnGQ',
        achievementId: 'https://learningapp.org/achievements/us-civics-master',
        achievementName: 'US Citizenship Naturalization Civics Master',
        achievementDescription:
            'Demonstrated mastery across 100 official USCIS civics questions with >= 90% FSRS retrievability.',
        criteriaNarrative:
            'Completed 100 questions with spaced repetition reviews over 30 days maintaining FSRS retrievability above 0.90.',
        issuerId: 'https://learningapp.org/issuers/civics-academy',
        issuerName: 'Open Civics Learning Academy',
        issuerUrl: 'https://learningapp.org',
        issuerEmail: 'credentials@learningapp.org',
        badgeImageUrl: 'https://learningapp.org/assets/badges/civics_master.png',
        issuanceDate: DateTime.parse('2026-11-06T12:00:00Z'),
        alignments: const [
          BadgeAlignmentCore(
            targetName: 'USCIS 100 Civics Questions',
            targetUrl: 'https://www.uscis.gov/citizenship/find-study-materials-and-resources/study-for-the-test',
            targetFramework: 'USCIS Naturalization Standards',
            targetCode: 'USCIS-CIVICS-100',
          ),
        ],
      );

      // Verify W3C VC context and types
      final contexts = credential['@context'] as List;
      expect(contexts, contains('https://www.w3.org/2018/credentials/v1'));
      expect(contexts, contains('https://purl.imsglobal.org/spec/ob/v3p0/context.json'));

      final types = credential['type'] as List;
      expect(types, contains('VerifiableCredential'));
      expect(types, contains('OpenBadgeCredential'));

      // Issuer
      final issuer = credential['issuer'] as Map<String, dynamic>;
      expect(issuer['name'], equals('Open Civics Learning Academy'));
      expect(issuer['type'], contains('Profile'));

      // Credential Subject & Achievement
      final subject = credential['credentialSubject'] as Map<String, dynamic>;
      expect(subject['type'], contains('AchievementSubject'));
      final achievement = subject['achievement'] as Map<String, dynamic>;
      expect(achievement['name'], equals('US Citizenship Naturalization Civics Master'));
      expect(achievement['criteria']['narrative'], contains('Completed 100 questions'));
      expect(achievement['image']['id'], equals('https://learningapp.org/assets/badges/civics_master.png'));

      // Alignments
      final alignments = achievement['alignment'] as List;
      expect(alignments.length, equals(1));
      expect(alignments[0]['targetCode'], equals('USCIS-CIVICS-100'));

      // Validate with OpenBadgeValidator
      final validation = OpenBadgeConverter.validateBadgeCredential(credential);
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
    });

    test('validates and flags missing required properties in malformed badges', () {
      final invalidCredential = {
        '@context': ['https://www.w3.org/2018/credentials/v1'], // Missing OBv3 context
        'id': 'urn:uuid:bad',
        'type': ['VerifiableCredential'], // Missing OpenBadgeCredential
        'issuer': {'id': 'https://example.org'}, // Missing issuer name
        'issuanceDate': 'invalid-date',
        'credentialSubject': {
          'id': 'recipient-123',
          'achievement': {
            // Missing name and criteria narrative
          },
        },
      };

      final result = OpenBadgeConverter.validateBadgeCredential(invalidCredential);
      expect(result.isValid, isFalse);
      expect(result.errors.length, greaterThanOrEqualTo(4));
      expect(result.errors.any((e) => e.contains('@context')), isTrue);
      expect(result.errors.any((e) => e.contains('OpenBadgeCredential')), isTrue);
      expect(result.errors.any((e) => e.contains('issuanceDate')), isTrue);
      expect(result.errors.any((e) => e.contains('narrative')), isTrue);
    });
  });
}

