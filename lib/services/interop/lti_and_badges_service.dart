import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/config/brand_config.dart';

/// Result of an LTI 1.3 Assignment and Grade Services (AGS) score synchronization.
class LtiGradeSyncResult {
  final bool success;
  final int statusCode;
  final String? message;

  const LtiGradeSyncResult({
    required this.success,
    required this.statusCode,
    this.message,
  });
}

/// Service handling 1EdTech Open Badges 3.0 issuance and LTI 1.3 LMS integration (OPP-5).
class LtiAndBadgesService {
  final http.Client _httpClient;

  LtiAndBadgesService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Creates a standard 1EdTech Open Badges 3.0 credential for an achievement.
  Map<String, dynamic> issueOpenBadge({
    required String recipientId,
    required String achievementId,
    required String achievementName,
    required String achievementDescription,
    required String criteriaNarrative,
    String? badgeImageUrl,
    List<BadgeAlignmentCore> alignments = const [],
  }) {
    final brand = BrandConfig.current;

    return OpenBadgeConverter.createBadgeCredential(
      credentialId: 'urn:uuid:${DateTime.now().microsecondsSinceEpoch}',
      recipientId: recipientId,
      achievementId: achievementId,
      achievementName: achievementName,
      achievementDescription: achievementDescription,
      criteriaNarrative: criteriaNarrative,
      issuerId: '${brand.organizationUrl}/issuer',
      issuerName: brand.organizationName,
      issuerUrl: brand.organizationUrl,
      issuerEmail: brand.supportEmail,
      badgeImageUrl: badgeImageUrl,
      alignments: alignments,
    );
  }

  /// Validates an Open Badges 3.0 credential map.
  OpenBadgeValidationResult validateBadge(Map<String, dynamic> badgeJson) {
    return OpenBadgeConverter.validateBadgeCredential(badgeJson);
  }

  /// Parses LTI 1.3 JWT claims into an [LtiLaunchMessage].
  LtiLaunchMessage parseLaunchClaims(Map<String, dynamic> claims) {
    return LtiLaunchMessage.fromJwtClaims(claims);
  }

  /// Syncs an assessment score back to an LMS via 1EdTech LTI AGS v2.0.
  Future<LtiGradeSyncResult> syncGradeToLms({
    required Uri lineItemUrl,
    required String bearerToken,
    required String userId,
    required double scoreGiven,
    double scoreMaximum = 100.0,
    String activityProgress = 'Completed',
    String gradingProgress = 'FullyGraded',
    String? comment,
  }) async {
    try {
      final payload = LtiGradePassbackPayload(
        userId: userId,
        scoreGiven: scoreGiven,
        scoreMaximum: scoreMaximum,
        activityProgress: activityProgress,
        gradingProgress: gradingProgress,
        timestamp: DateTime.now().toUtc(),
        comment: comment,
      );

      final response = await _httpClient.post(
        lineItemUrl,
        headers: {
          'Content-Type': 'application/vnd.ims.lis.v1.score+json',
          'Authorization': 'Bearer $bearerToken',
        },
        body: jsonEncode(payload.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return LtiGradeSyncResult(
          success: true,
          statusCode: response.statusCode,
          message: 'Score successfully posted to LMS',
        );
      } else {
        return LtiGradeSyncResult(
          success: false,
          statusCode: response.statusCode,
          message: 'LMS AGS rejected score: ${response.body}',
        );
      }
    } catch (e) {
      return LtiGradeSyncResult(
        success: false,
        statusCode: 0,
        message: 'Exception synchronizing score with LMS: $e',
      );
    }
  }
}

