import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/theme/app_theme.dart';

void main() {
  setUp(() {
    BrandConfig.reset();
  });

  tearDown(() {
    BrandConfig.reset();
  });

  group('BrandConfig Flutter integration', () {
    testWidgets('defaults to vanilla branding and standard theme colors', (tester) async {
      expect(BrandConfig.appName, equals('LearningApp'));
      expect(BrandConfig.primaryColor, equals(const Color(0xFF0288D1)));
      expect(BrandConfig.secondaryColor, equals(const Color(0xFF00897B)));

      final light = AppTheme.lightTheme();
      // Brand primary is darkened just enough for 4.5:1 text contrast.
      expect(light.colorScheme.primary,
          equals(AppTheme.accessibleLightPrimary(const Color(0xFF0288D1))));

      final dark = AppTheme.darkTheme();
      expect(dark.colorScheme.primary, equals(const Color(0xFF4FC3F7)));
    });

    testWidgets('dynamically updates theme when custom brand configuration is applied', (tester) async {
      const customBrand = BrandConfigCore(
        appName: 'EduPilot',
        primaryColorHex: '#E91E63', // Pink
        secondaryColorHex: '#9C27B0', // Purple
        darkPrimaryColorHex: '#F48FB1',
        darkSecondaryColorHex: '#CE93D8',
      );

      BrandConfig.set(customBrand);

      expect(BrandConfig.appName, equals('EduPilot'));
      expect(BrandConfig.primaryColor, equals(const Color(0xFFE91E63)));
      expect(BrandConfig.secondaryColor, equals(const Color(0xFF9C27B0)));

      final customLight = AppTheme.lightTheme();
      expect(customLight.colorScheme.primary,
          equals(AppTheme.accessibleLightPrimary(const Color(0xFFE91E63))));
      expect(customLight.colorScheme.secondary, equals(const Color(0xFF9C27B0)));

      final customDark = AppTheme.darkTheme();
      expect(customDark.colorScheme.primary, equals(const Color(0xFFF48FB1)));
      expect(customDark.colorScheme.secondary, equals(const Color(0xFFCE93D8)));
    });
  });
}

