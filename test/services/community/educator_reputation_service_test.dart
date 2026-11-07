import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/community/educator_reputation.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';
import 'package:learning_pwa/services/community/educator_reputation_service.dart';

void main() {
  group('EducatorReputationService & EducatorReputation', () {
    late EducatorReputationService service;

    setUp(() {
      service = EducatorReputationService();
    });

    test('calculates base reputation with zero activity', () {
      final rep = service.calculateReputation(
        educatorId: 'edu_1',
        upvotesCount: 0,
        acceptedAnswersCount: 0,
        totalAnswersCount: 0,
      );

      expect(rep.educatorId, 'edu_1');
      expect(rep.score, 0.0);
      expect(rep.tier, EducatorReputationTier.newContributor);
      expect(rep.credentialMultiplier, 1.0);
      expect(rep.hasVerifiedCredential, isFalse);
      expect(rep.qualityRatio, 1.0);
    });

    test('calculates active contributor without credentials', () {
      final rep = service.calculateReputation(
        educatorId: 'edu_2',
        upvotesCount: 10,
        acceptedAnswersCount: 2,
        totalAnswersCount: 2,
      );

      // raw = (10 * 1.0) + (2 * 5.0) = 20.0
      // Q = 0.5 + 0.5 * (3 / 3) = 1.0
      // score = 20.0 * 1.0 * 1.0 = 20.0
      expect(rep.score, 20.0);
      // Not verified, so it cannot be verifiedSpecialist even though score >= 20
      expect(rep.tier, EducatorReputationTier.activeContributor);
      expect(rep.hasVerifiedCredential, isFalse);
    });

    test('applies 1.5x multiplier for state-licensed credential and awards masterContributor tier', () {
      final verification = EducatorVerification(
        id: 'ver_1',
        educatorId: 'edu_3',
        verificationType: 'licensed_credential',
        jurisdiction: 'FL',
        issuer: 'FL DBPR',
        status: 'verified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final rep = service.calculateReputation(
        educatorId: 'edu_3',
        upvotesCount: 20,
        acceptedAnswersCount: 8,
        totalAnswersCount: 10,
        verifications: [verification],
      );

      // raw = (20 * 1.0) + (8 * 5.0) = 60.0
      // Q = 0.5 + 0.5 * (9 / 11) = 0.5 + 0.40909 = 0.909
      // mult = 1.5
      // score = 60 * 1.5 * 0.909 = 81.8
      expect(rep.hasVerifiedCredential, isTrue);
      expect(rep.licensedCredentialsCount, 1);
      expect(rep.credentialMultiplier, 1.5);
      expect(rep.score, greaterThanOrEqualTo(50.0));
      expect(rep.tier, EducatorReputationTier.masterContributor);
    });

    test('applies 1.2x multiplier for platform-vetted credential and awards verifiedSpecialist', () {
      final verification = EducatorVerification(
        id: 'ver_2',
        educatorId: 'edu_4',
        verificationType: 'platform_vetted',
        status: 'verified',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final rep = service.calculateReputation(
        educatorId: 'edu_4',
        upvotesCount: 10,
        acceptedAnswersCount: 3,
        totalAnswersCount: 4,
        verifications: [verification],
      );

      // raw = 10 + 15 = 25.0
      // Q = 0.5 + 0.5 * (4 / 5) = 0.9
      // score = 25.0 * 1.2 * 0.9 = 27.0
      expect(rep.hasVerifiedCredential, isTrue);
      expect(rep.platformVettedCount, 1);
      expect(rep.credentialMultiplier, 1.2);
      expect(rep.score, closeTo(27.0, 0.5));
      expect(rep.tier, EducatorReputationTier.verifiedSpecialist);
    });

    test('penalizes volume-spamming with low acceptance quality ratio', () {
      final rep = service.calculateReputation(
        educatorId: 'edu_spammer',
        upvotesCount: 5,
        acceptedAnswersCount: 1,
        totalAnswersCount: 100, // 100 answers, only 1 accepted
      );

      // raw = 5 + 5 = 10.0
      // Q = 0.5 + 0.5 * (2 / 101) = 0.5099
      // score = 10.0 * 1.0 * 0.5099 = 5.1
      expect(rep.score, closeTo(5.1, 0.2));
      expect(rep.tier, EducatorReputationTier.newContributor);
    });

    test('round-trips through JSON accurately', () {
      final original = EducatorReputation.compute(
        educatorId: 'edu_roundtrip',
        upvotesCount: 15,
        acceptedAnswersCount: 5,
        totalAnswersCount: 6,
        verifications: [
          EducatorVerification(
            id: 'ver_test',
            educatorId: 'edu_roundtrip',
            verificationType: 'licensed_credential',
            status: 'verified',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final json = original.toJson();
      final restored = EducatorReputation.fromJson(json);

      expect(restored.educatorId, original.educatorId);
      expect(restored.score, original.score);
      expect(restored.tier, original.tier);
      expect(restored.credentialMultiplier, original.credentialMultiplier);
      expect(restored.hasVerifiedCredential, original.hasVerifiedCredential);
      expect(restored.qualityRatio, original.qualityRatio);
    });
  });
}

