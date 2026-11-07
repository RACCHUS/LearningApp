import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/community/educator_verification.dart';

/// Reputation tier for community educators (ECO-04).
enum EducatorReputationTier {
  masterContributor('Master Contributor'),
  verifiedSpecialist('Verified Specialist'),
  activeContributor('Active Contributor'),
  newContributor('New Contributor');

  final String displayName;
  const EducatorReputationTier(this.displayName);

  static EducatorReputationTier fromString(String? value) {
    if (value == null) return EducatorReputationTier.newContributor;
    for (final tier in EducatorReputationTier.values) {
      if (tier.name.toLowerCase() == value.toLowerCase() ||
          tier.displayName.toLowerCase() == value.toLowerCase()) {
        return tier;
      }
    }
    return EducatorReputationTier.newContributor;
  }
}

/// Represents the calculated evidence-weighted reputation of an educator (ECO-04).
///
/// Implements Phase 2 Invariant:
/// - Evidence-weighted reputation over raw post volume gaming.
/// - Weighting: Accepted answers (5x) + Upvotes (1x) multiplied by
///   credential verification tier and acceptance quality ratio.
@immutable
class EducatorReputation {
  final String educatorId;
  final double score;
  final int upvotesCount;
  final int acceptedAnswersCount;
  final int totalAnswersCount;
  final double qualityRatio;
  final EducatorReputationTier tier;
  final double credentialMultiplier;
  final bool hasVerifiedCredential;
  final int licensedCredentialsCount;
  final int platformVettedCount;
  final int selfDeclaredCount;

  const EducatorReputation({
    required this.educatorId,
    required this.score,
    required this.upvotesCount,
    required this.acceptedAnswersCount,
    required this.totalAnswersCount,
    required this.qualityRatio,
    required this.tier,
    required this.credentialMultiplier,
    required this.hasVerifiedCredential,
    this.licensedCredentialsCount = 0,
    this.platformVettedCount = 0,
    this.selfDeclaredCount = 0,
  });

  /// Factory constructor computing evidence-weighted reputation directly from activity metrics and verifications.
  factory EducatorReputation.compute({
    required String educatorId,
    required int upvotesCount,
    required int acceptedAnswersCount,
    required int totalAnswersCount,
    List<EducatorVerification> verifications = const [],
  }) {
    int licensed = 0;
    int platformVetted = 0;
    int selfDeclared = 0;

    for (final v in verifications) {
      if (v.isVerified) {
        if (v.isLicensed) {
          licensed++;
        } else if (v.isPlatformVetted) {
          platformVetted++;
        }
      } else if (v.isSelfDeclared) {
        selfDeclared++;
      }
    }

    final hasVerified = (licensed > 0 || platformVetted > 0);

    // Credential multiplier: 1.5 for state licensed, 1.2 for platform vetted, 1.0 default
    double multiplier = 1.0;
    if (licensed > 0) {
      multiplier = 1.5;
    } else if (platformVetted > 0) {
      multiplier = 1.2;
    }

    // Acceptance quality ratio: 0.5 + 0.5 * min(1.0, (accepted + 1) / (total + 1))
    // Ensures educators who post thousands of low quality answers get penalized
    final double qualityRatio;
    if (totalAnswersCount <= 0) {
      qualityRatio = 1.0;
    } else {
      final ratio = (acceptedAnswersCount + 1.0) / (totalAnswersCount + 1.0);
      qualityRatio = 0.5 + 0.5 * (ratio > 1.0 ? 1.0 : ratio);
    }

    // Raw score = upvotes * 1.0 + accepted * 5.0
    final rawScore = (upvotesCount * 1.0) + (acceptedAnswersCount * 5.0);
    final calculatedScore = double.parse((rawScore * multiplier * qualityRatio).toStringAsFixed(1));

    // Contributor tier derivation
    final EducatorReputationTier tier;
    if (hasVerified && calculatedScore >= 50.0) {
      tier = EducatorReputationTier.masterContributor;
    } else if (hasVerified && calculatedScore >= 20.0) {
      tier = EducatorReputationTier.verifiedSpecialist;
    } else if (calculatedScore >= 10.0) {
      tier = EducatorReputationTier.activeContributor;
    } else {
      tier = EducatorReputationTier.newContributor;
    }

    return EducatorReputation(
      educatorId: educatorId,
      score: calculatedScore,
      upvotesCount: upvotesCount,
      acceptedAnswersCount: acceptedAnswersCount,
      totalAnswersCount: totalAnswersCount,
      qualityRatio: double.parse(qualityRatio.toStringAsFixed(3)),
      tier: tier,
      credentialMultiplier: multiplier,
      hasVerifiedCredential: hasVerified,
      licensedCredentialsCount: licensed,
      platformVettedCount: platformVetted,
      selfDeclaredCount: selfDeclared,
    );
  }

  factory EducatorReputation.fromJson(Map<String, dynamic> json) {
    return EducatorReputation(
      educatorId: json['educator_id'] as String,
      score: (json['score'] as num).toDouble(),
      upvotesCount: json['upvotes_count'] as int? ?? 0,
      acceptedAnswersCount: json['accepted_answers_count'] as int? ?? 0,
      totalAnswersCount: json['total_answers_count'] as int? ?? 0,
      qualityRatio: (json['quality_ratio'] as num?)?.toDouble() ?? 1.0,
      tier: EducatorReputationTier.fromString(json['tier'] as String?),
      credentialMultiplier: (json['credential_multiplier'] as num?)?.toDouble() ?? 1.0,
      hasVerifiedCredential: json['has_verified_credential'] as bool? ?? false,
      licensedCredentialsCount: json['licensed_credentials_count'] as int? ?? 0,
      platformVettedCount: json['platform_vetted_count'] as int? ?? 0,
      selfDeclaredCount: json['self_declared_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'educator_id': educatorId,
      'score': score,
      'upvotes_count': upvotesCount,
      'accepted_answers_count': acceptedAnswersCount,
      'total_answers_count': totalAnswersCount,
      'quality_ratio': qualityRatio,
      'tier': tier.name,
      'credential_multiplier': credentialMultiplier,
      'has_verified_credential': hasVerifiedCredential,
      'licensed_credentials_count': licensedCredentialsCount,
      'platform_vetted_count': platformVettedCount,
      'self_declared_count': selfDeclaredCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EducatorReputation &&
        other.educatorId == educatorId &&
        other.score == score &&
        other.upvotesCount == upvotesCount &&
        other.acceptedAnswersCount == acceptedAnswersCount &&
        other.totalAnswersCount == totalAnswersCount &&
        other.qualityRatio == qualityRatio &&
        other.tier == tier &&
        other.credentialMultiplier == credentialMultiplier &&
        other.hasVerifiedCredential == hasVerifiedCredential &&
        other.licensedCredentialsCount == licensedCredentialsCount &&
        other.platformVettedCount == platformVettedCount &&
        other.selfDeclaredCount == selfDeclaredCount;
  }

  @override
  int get hashCode => Object.hash(
        educatorId,
        score,
        upvotesCount,
        acceptedAnswersCount,
        totalAnswersCount,
        qualityRatio,
        tier,
        credentialMultiplier,
        hasVerifiedCredential,
        licensedCredentialsCount,
        platformVettedCount,
        selfDeclaredCount,
      );
}

