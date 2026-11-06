/// Represents a parsed and validated 1EdTech LTI 1.3 Resource Link Launch message.
class LtiLaunchMessage {
  static const String claimMessageType =
      'https://purl.imsglobal.org/spec/lti/claim/message_type';
  static const String claimVersion =
      'https://purl.imsglobal.org/spec/lti/claim/version';
  static const String claimResourceLink =
      'https://purl.imsglobal.org/spec/lti/claim/resource_link';
  static const String claimRoles =
      'https://purl.imsglobal.org/spec/lti/claim/roles';
  static const String claimContext =
      'https://purl.imsglobal.org/spec/lti/claim/context';
  static const String claimTargetLinkUri =
      'https://purl.imsglobal.org/spec/lti/claim/target_link_uri';
  static const String claimAgsEndpoint =
      'https://purl.imsglobal.org/spec/lti-ags/claim/endpoint';

  final String messageType;
  final String version;
  final String resourceLinkId;
  final String? resourceLinkTitle;
  final String? contextId;
  final String? contextTitle;
  final String? contextLabel;
  final List<String> roles;
  final String? targetLinkUri;
  final String? agsLineItemUrl;
  final List<String> agsScopes;
  final String? userSub;

  const LtiLaunchMessage({
    required this.messageType,
    required this.version,
    required this.resourceLinkId,
    this.resourceLinkTitle,
    this.contextId,
    this.contextTitle,
    this.contextLabel,
    this.roles = const [],
    this.targetLinkUri,
    this.agsLineItemUrl,
    this.agsScopes = const [],
    this.userSub,
  });

  /// Factory parsing LTI 1.3 JWT claims into a typed launch model.
  factory LtiLaunchMessage.fromJwtClaims(Map<String, dynamic> claims) {
    final resourceLink =
        (claims[claimResourceLink] as Map?)?.cast<String, dynamic>() ?? {};
    final contextMap =
        (claims[claimContext] as Map?)?.cast<String, dynamic>() ?? {};
    final agsMap =
        (claims[claimAgsEndpoint] as Map?)?.cast<String, dynamic>() ?? {};

    final rawRoles = claims[claimRoles] as List? ?? [];
    final rolesList = rawRoles.map((r) => r.toString()).toList();

    final rawScopes = agsMap['scope'] as List? ?? [];
    final scopesList = rawScopes.map((s) => s.toString()).toList();

    return LtiLaunchMessage(
      messageType: claims[claimMessageType] as String? ?? 'LtiResourceLinkRequest',
      version: claims[claimVersion] as String? ?? '1.3.0',
      resourceLinkId: resourceLink['id'] as String? ?? '',
      resourceLinkTitle: resourceLink['title'] as String?,
      contextId: contextMap['id'] as String?,
      contextTitle: contextMap['title'] as String?,
      contextLabel: contextMap['label'] as String?,
      roles: rolesList,
      targetLinkUri: claims[claimTargetLinkUri] as String?,
      agsLineItemUrl: agsMap['lineitem'] as String?,
      agsScopes: scopesList,
      userSub: claims['sub'] as String?,
    );
  }

  /// Whether the launching user has a learner / student role.
  bool get isLearner => roles.any((r) =>
      r.contains('membership#Learner') ||
      r.contains('membership#Student') ||
      r.toLowerCase().contains('learner'));

  /// Whether the launching user has an instructor / faculty role.
  bool get isInstructor => roles.any((r) =>
      r.contains('membership#Instructor') ||
      r.contains('membership#Faculty') ||
      r.toLowerCase().contains('instructor'));

  /// Whether the launching user is an LMS administrator.
  bool get isAdmin => roles.any((r) =>
      r.contains('membership#Administrator') ||
      r.toLowerCase().contains('admin'));

  /// Whether the launch contains an Assignment and Grade Services lineitem URL.
  bool get hasGradeService =>
      agsLineItemUrl != null && agsLineItemUrl!.isNotEmpty;
}

/// 1EdTech LTI Assignment and Grade Services (AGS) v2.0 Score Payload.
class LtiGradePassbackPayload {
  final String userId;
  final double scoreGiven;
  final double scoreMaximum;
  final String activityProgress;
  final String gradingProgress;
  final DateTime timestamp;
  final String? comment;

  const LtiGradePassbackPayload({
    required this.userId,
    required this.scoreGiven,
    this.scoreMaximum = 100.0,
    this.activityProgress = 'Completed',
    this.gradingProgress = 'FullyGraded',
    required this.timestamp,
    this.comment,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'scoreGiven': scoreGiven,
        'scoreMaximum': scoreMaximum,
        'activityProgress': activityProgress,
        'gradingProgress': gradingProgress,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (comment != null) 'comment': comment,
      };
}

