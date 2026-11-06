/// Alignment to an external educational competency or standard (e.g. 1EdTech CASE).
class BadgeAlignmentCore {
  final String targetName;
  final String targetUrl;
  final String? targetFramework;
  final String? targetCode;
  final String? targetDescription;

  const BadgeAlignmentCore({
    required this.targetName,
    required this.targetUrl,
    this.targetFramework,
    this.targetCode,
    this.targetDescription,
  });

  factory BadgeAlignmentCore.fromJson(Map<String, dynamic> json) {
    return BadgeAlignmentCore(
      targetName: json['targetName'] as String? ?? '',
      targetUrl: json['targetUrl'] as String? ?? '',
      targetFramework: json['targetFramework'] as String?,
      targetCode: json['targetCode'] as String?,
      targetDescription: json['targetDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'targetName': targetName,
        'targetUrl': targetUrl,
        if (targetFramework != null) 'targetFramework': targetFramework,
        if (targetCode != null) 'targetCode': targetCode,
        if (targetDescription != null) 'targetDescription': targetDescription,
      };
}

/// Validation outcome for an Open Badges 3.0 credential.
class OpenBadgeValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const OpenBadgeValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Formatter and validator for 1EdTech Open Badges 3.0 (OBv3) and
/// W3C Verifiable Credentials 1.1 / 2.0 standards.
class OpenBadgeConverter {
  static const List<String> standardContexts = [
    'https://www.w3.org/2018/credentials/v1',
    'https://purl.imsglobal.org/spec/ob/v3p0/context.json',
  ];

  static const List<String> standardTypes = [
    'VerifiableCredential',
    'OpenBadgeCredential',
  ];

  /// Creates a compliant 1EdTech Open Badges 3.0 Verifiable Credential.
  static Map<String, dynamic> createBadgeCredential({
    required String credentialId,
    required String recipientId,
    required String achievementId,
    required String achievementName,
    required String achievementDescription,
    required String criteriaNarrative,
    required String issuerId,
    required String issuerName,
    required String issuerUrl,
    String? issuerEmail,
    String? badgeImageUrl,
    DateTime? issuanceDate,
    List<BadgeAlignmentCore> alignments = const [],
  }) {
    final issuedAt = (issuanceDate ?? DateTime.now().toUtc()).toUtc();

    final achievement = <String, dynamic>{
      'id': achievementId,
      'type': ['Achievement'],
      'name': achievementName,
      'description': achievementDescription,
      'criteria': {
        'narrative': criteriaNarrative,
      },
      if (badgeImageUrl != null && badgeImageUrl.isNotEmpty)
        'image': {
          'id': badgeImageUrl,
          'type': 'Image',
        },
      if (alignments.isNotEmpty)
        'alignment': alignments.map((a) => a.toJson()).toList(),
    };

    return {
      '@context': standardContexts,
      'id': credentialId,
      'type': standardTypes,
      'issuer': {
        'id': issuerId,
        'type': ['Profile'],
        'name': issuerName,
        'url': issuerUrl,
        if (issuerEmail != null) 'email': issuerEmail,
      },
      'issuanceDate': issuedAt.toIso8601String(),
      'credentialSubject': {
        'id': recipientId,
        'type': ['AchievementSubject'],
        'achievement': achievement,
      },
    };
  }

  /// Validates that an Open Badges 3.0 map conforms to required W3C VC and OBv3 structure.
  static OpenBadgeValidationResult validateBadgeCredential(
      Map<String, dynamic> json) {
    final errors = <String>[];
    final warnings = <String>[];

    // 1. @context check
    final context = json['@context'];
    if (context is! List ||
        !context.contains('https://www.w3.org/2018/credentials/v1') ||
        !context
            .contains('https://purl.imsglobal.org/spec/ob/v3p0/context.json')) {
      errors.add(
          'Missing mandatory @context URIs (https://www.w3.org/2018/credentials/v1 and https://purl.imsglobal.org/spec/ob/v3p0/context.json)');
    }

    // 2. id check
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      errors.add('Missing or empty "id" credential URI');
    }

    // 3. type check
    final type = json['type'];
    if (type is! List ||
        !type.contains('VerifiableCredential') ||
        !type.contains('OpenBadgeCredential')) {
      errors.add(
          'Missing mandatory types "VerifiableCredential" and "OpenBadgeCredential"');
    }

    // 4. issuer check
    final issuer = json['issuer'];
    if (issuer is! Map) {
      errors.add('Missing or invalid "issuer" object');
    } else {
      if (issuer['id'] is! String || (issuer['id'] as String).isEmpty) {
        errors.add('Issuer missing mandatory "id" URI');
      }
      if (issuer['name'] is! String || (issuer['name'] as String).isEmpty) {
        errors.add('Issuer missing mandatory "name" string');
      }
    }

    // 5. issuanceDate check
    final issuanceDate = json['issuanceDate'];
    if (issuanceDate is! String || DateTime.tryParse(issuanceDate) == null) {
      errors.add('Missing or invalid ISO-8601 "issuanceDate"');
    }

    // 6. credentialSubject check
    final subject = json['credentialSubject'];
    if (subject is! Map) {
      errors.add('Missing or invalid "credentialSubject" object');
    } else {
      if (subject['id'] is! String || (subject['id'] as String).isEmpty) {
        errors.add('CredentialSubject missing mandatory recipient "id"');
      }

      final achievement = subject['achievement'];
      if (achievement is! Map) {
        errors.add('CredentialSubject missing "achievement" specification');
      } else {
        if (achievement['name'] is! String ||
            (achievement['name'] as String).isEmpty) {
          errors.add('Achievement missing mandatory "name"');
        }
        if (achievement['criteria'] is! Map ||
            (achievement['criteria'] as Map)['narrative'] is! String) {
          errors.add('Achievement missing mandatory "criteria.narrative"');
        }
      }
    }

    return OpenBadgeValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
