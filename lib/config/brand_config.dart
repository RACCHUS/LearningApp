import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Flutter application wrapper for [BrandConfigCore], supporting
/// `--dart-define=BRAND_CONFIG=...` build injection and theme color conversions.
class BrandConfig {
  static const String _defineJson = String.fromEnvironment('BRAND_CONFIG');
  static const String _defineAppName = String.fromEnvironment('APP_NAME');

  static BrandConfigCore _instance = _loadInitialConfig();

  static BrandConfigCore _loadInitialConfig() {
    if (_defineJson.isNotEmpty) {
      return BrandConfigCore.parseJsonString(_defineJson);
    }
    if (_defineAppName.isNotEmpty) {
      return BrandConfigCore(appName: _defineAppName);
    }
    return BrandConfigCore.vanilla();
  }

  /// The active brand configuration for the application.
  static BrandConfigCore get current => _instance;

  /// Sets or overrides the current brand configuration (e.g. for testing or runtime loads).
  static void set(BrandConfigCore config) {
    _instance = config;
  }

  /// Resets the configuration back to build-time or vanilla defaults.
  static void reset() {
    _instance = _loadInitialConfig();
  }

  // Convenience Flutter Color accessors
  static Color get primaryColor => Color(_instance.primaryColorValue);
  static Color get secondaryColor => Color(_instance.secondaryColorValue);
  static Color get darkPrimaryColor => Color(_instance.darkPrimaryColorValue);
  static Color get darkSecondaryColor => Color(_instance.darkSecondaryColorValue);

  static String get appName => _instance.appName;
  static String get tagline => _instance.tagline;
  static String get supportEmail => _instance.supportEmail;
  static String get termsUrl => _instance.termsOfServiceUrl;
  static String get privacyUrl => _instance.privacyPolicyUrl;
  static FeatureFlagsCore get features => _instance.features;
}

