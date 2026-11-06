import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('BrandConfigCore', () {
    test('vanilla default configuration contains expected standard properties', () {
      final config = BrandConfigCore.vanilla();
      expect(config.appName, equals('LearningApp'));
      expect(config.tagline, contains('Evidence-based'));
      expect(config.supportEmail, equals('support@example.org'));
      expect(config.primaryColorHex, equals('#0288D1'));
      expect(config.secondaryColorHex, equals('#00897B'));
      expect(config.primaryColorValue, equals(0xFF0288D1));
      expect(config.features.enableByokAi, isTrue);
      expect(config.features.enableAdultLiteracy, isTrue);
    });

    test('serializes and deserializes custom white-label branding from JSON cleanly', () {
      final customJson = {
        'app_name': 'CivicsMaster',
        'tagline': 'Master the Naturalization Exam with Spaced Retrieval',
        'organization_name': 'Civic Literacy Foundation',
        'organization_url': 'https://civics.example.org',
        'support_email': 'help@civics.example.org',
        'primary_color_hex': '#1E88E5',
        'secondary_color_hex': '#43A047',
        'dark_primary_color_hex': '#64B5F6',
        'dark_secondary_color_hex': '#81C784',
        'terms_of_service_url': 'https://civics.example.org/terms',
        'privacy_policy_url': 'https://civics.example.org/privacy',
        'features': {
          'enable_byok_ai': false,
          'enable_hands_free': true,
          'enable_adult_literacy': true,
          'custom_civic_quiz': true,
        },
      };

      final config = BrandConfigCore.fromJson(customJson);
      expect(config.appName, equals('CivicsMaster'));
      expect(config.tagline, equals('Master the Naturalization Exam with Spaced Retrieval'));
      expect(config.primaryColorHex, equals('#1E88E5'));
      expect(config.primaryColorValue, equals(0xFF1E88E5));
      expect(config.secondaryColorValue, equals(0xFF43A047));
      expect(config.darkPrimaryColorValue, equals(0xFF64B5F6));
      expect(config.darkSecondaryColorValue, equals(0xFF81C784));

      // Features
      expect(config.features.enableByokAi, isFalse);
      expect(config.features.enableHandsFree, isTrue);
      expect(config.features.isEnabled('custom_civic_quiz'), isTrue);
      expect(config.features.isEnabled('non_existent_flag'), isFalse);

      // Roundtrip
      final encoded = config.toJson();
      final roundtripped = BrandConfigCore.fromJson(encoded);
      expect(roundtripped.appName, equals(config.appName));
      expect(roundtripped.primaryColorHex, equals(config.primaryColorHex));
      expect(roundtripped.features.enableByokAi, isFalse);
    });

    test('parseJsonString handles invalid or malformed JSON with graceful fallback', () {
      final fallback = BrandConfigCore.parseJsonString('not a json string');
      expect(fallback.appName, equals('LearningApp'));
      expect(fallback.primaryColorValue, equals(0xFF0288D1));
    });

    test('parseHexColor handles various formatting with and without hash', () {
      expect(BrandConfigCore.parseHexColor('#FFAA00'), equals(0xFFFFAA00));
      expect(BrandConfigCore.parseHexColor('FFAA00'), equals(0xFFFFAA00));
      expect(BrandConfigCore.parseHexColor('80FFAA00'), equals(0x80FFAA00));
      expect(BrandConfigCore.parseHexColor('invalid', fallback: 0xFF123456), equals(0xFF123456));
    });
  });
}

