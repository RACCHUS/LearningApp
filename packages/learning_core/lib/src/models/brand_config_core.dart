import 'dart:convert';

/// Feature flag toggles configurable per deployment / institution fork.
class FeatureFlagsCore {
  final bool enableByokAi;
  final bool enableHandsFree;
  final bool enableOfflineSync;
  final bool enableAdultLiteracy;
  final bool enablePerformanceAssessments;
  final bool enableTaxonomyExplorer;
  final bool enableQtiExport;
  final bool enableCommunityQa;
  final Map<String, bool> customFlags;

  const FeatureFlagsCore({
    this.enableByokAi = true,
    this.enableHandsFree = true,
    this.enableOfflineSync = true,
    this.enableAdultLiteracy = true,
    this.enablePerformanceAssessments = true,
    this.enableTaxonomyExplorer = true,
    this.enableQtiExport = true,
    this.enableCommunityQa = true,
    this.customFlags = const {},
  });

  factory FeatureFlagsCore.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureFlagsCore();
    final custom = <String, bool>{};
    json.forEach((key, value) {
      if (!{
        'enable_byok_ai',
        'enable_hands_free',
        'enable_offline_sync',
        'enable_adult_literacy',
        'enable_performance_assessments',
        'enable_taxonomy_explorer',
        'enable_qti_export',
        'enable_community_qa',
      }.contains(key) && value is bool) {
        custom[key] = value;
      }
    });

    return FeatureFlagsCore(
      enableByokAi: json['enable_byok_ai'] as bool? ?? true,
      enableHandsFree: json['enable_hands_free'] as bool? ?? true,
      enableOfflineSync: json['enable_offline_sync'] as bool? ?? true,
      enableAdultLiteracy: json['enable_adult_literacy'] as bool? ?? true,
      enablePerformanceAssessments:
          json['enable_performance_assessments'] as bool? ?? true,
      enableTaxonomyExplorer: json['enable_taxonomy_explorer'] as bool? ?? true,
      enableQtiExport: json['enable_qti_export'] as bool? ?? true,
      enableCommunityQa: json['enable_community_qa'] as bool? ?? true,
      customFlags: custom,
    );
  }

  Map<String, dynamic> toJson() => {
        'enable_byok_ai': enableByokAi,
        'enable_hands_free': enableHandsFree,
        'enable_offline_sync': enableOfflineSync,
        'enable_adult_literacy': enableAdultLiteracy,
        'enable_performance_assessments': enablePerformanceAssessments,
        'enable_taxonomy_explorer': enableTaxonomyExplorer,
        'enable_qti_export': enableQtiExport,
        'enable_community_qa': enableCommunityQa,
        ...customFlags,
      };

  bool isEnabled(String flagName) {
    switch (flagName) {
      case 'byok_ai':
      case 'enable_byok_ai':
        return enableByokAi;
      case 'hands_free':
      case 'enable_hands_free':
        return enableHandsFree;
      case 'offline_sync':
      case 'enable_offline_sync':
        return enableOfflineSync;
      case 'adult_literacy':
      case 'enable_adult_literacy':
        return enableAdultLiteracy;
      case 'performance_assessments':
      case 'enable_performance_assessments':
        return enablePerformanceAssessments;
      case 'taxonomy_explorer':
      case 'enable_taxonomy_explorer':
        return enableTaxonomyExplorer;
      case 'qti_export':
      case 'enable_qti_export':
        return enableQtiExport;
      case 'community_qa':
      case 'enable_community_qa':
        return enableCommunityQa;
      default:
        return customFlags[flagName] ?? false;
    }
  }
}

/// Brand specification and theme metadata for white-label forks.
class BrandConfigCore {
  final String appName;
  final String tagline;
  final String organizationName;
  final String organizationUrl;
  final String supportEmail;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String darkPrimaryColorHex;
  final String darkSecondaryColorHex;
  final String termsOfServiceUrl;
  final String privacyPolicyUrl;
  final FeatureFlagsCore features;

  const BrandConfigCore({
    this.appName = 'LearningApp',
    this.tagline = 'Evidence-based mastery learning for everyone',
    this.organizationName = 'LearningApp Open Project',
    this.organizationUrl = 'https://github.com/RACCHUS/LearningApp',
    this.supportEmail = 'support@example.org',
    this.primaryColorHex = '#0288D1',
    this.secondaryColorHex = '#00897B',
    this.darkPrimaryColorHex = '#4FC3F7',
    this.darkSecondaryColorHex = '#80CBC4',
    this.termsOfServiceUrl = '/terms',
    this.privacyPolicyUrl = '/privacy',
    this.features = const FeatureFlagsCore(),
  });

  /// Factory creating default vanilla configuration.
  factory BrandConfigCore.vanilla() => const BrandConfigCore();

  /// Parse from JSON map.
  factory BrandConfigCore.fromJson(Map<String, dynamic> json) {
    return BrandConfigCore(
      appName: json['app_name'] as String? ?? 'LearningApp',
      tagline: json['tagline'] as String? ??
          'Evidence-based mastery learning for everyone',
      organizationName:
          json['organization_name'] as String? ?? 'LearningApp Open Project',
      organizationUrl: json['organization_url'] as String? ??
          'https://github.com/RACCHUS/LearningApp',
      supportEmail: json['support_email'] as String? ?? 'support@example.org',
      primaryColorHex: json['primary_color_hex'] as String? ?? '#0288D1',
      secondaryColorHex: json['secondary_color_hex'] as String? ?? '#00897B',
      darkPrimaryColorHex:
          json['dark_primary_color_hex'] as String? ?? '#4FC3F7',
      darkSecondaryColorHex:
          json['dark_secondary_color_hex'] as String? ?? '#80CBC4',
      termsOfServiceUrl: json['terms_of_service_url'] as String? ?? '/terms',
      privacyPolicyUrl: json['privacy_policy_url'] as String? ?? '/privacy',
      features: json['features'] is Map<String, dynamic>
          ? FeatureFlagsCore.fromJson(json['features'] as Map<String, dynamic>)
          : const FeatureFlagsCore(),
    );
  }

  /// Parses brand configuration from a JSON string.
  static BrandConfigCore parseJsonString(String rawJson) {
    try {
      final decoded = json.decode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return BrandConfigCore.fromJson(decoded);
      }
    } catch (_) {
      // Fallback on decode failure
    }
    return BrandConfigCore.vanilla();
  }

  Map<String, dynamic> toJson() => {
        'app_name': appName,
        'tagline': tagline,
        'organization_name': organizationName,
        'organization_url': organizationUrl,
        'support_email': supportEmail,
        'primary_color_hex': primaryColorHex,
        'secondary_color_hex': secondaryColorHex,
        'dark_primary_color_hex': darkPrimaryColorHex,
        'dark_secondary_color_hex': darkSecondaryColorHex,
        'terms_of_service_url': termsOfServiceUrl,
        'privacy_policy_url': privacyPolicyUrl,
        'features': features.toJson(),
      };

  /// Parses an ARGB integer from a hex color string (e.g. #0288D1 -> 0xFF0288D1).
  static int parseHexColor(String hexString, {int fallback = 0xFF0288D1}) {
    var hex = hexString.replaceAll('#', '').trim();
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  int get primaryColorValue => parseHexColor(primaryColorHex, fallback: 0xFF0288D1);
  int get secondaryColorValue =>
      parseHexColor(secondaryColorHex, fallback: 0xFF00897B);
  int get darkPrimaryColorValue =>
      parseHexColor(darkPrimaryColorHex, fallback: 0xFF4FC3F7);
  int get darkSecondaryColorValue =>
      parseHexColor(darkSecondaryColorHex, fallback: 0xFF80CBC4);
}

