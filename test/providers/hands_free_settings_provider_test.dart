import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';

void main() {
  group('HandsFreeSettings Tests', () {
    group('Default settings', () {
      test('should create settings with default values', () {
        const settings = HandsFreeSettings();

        expect(settings.defaultHandsFreeMode, false);
        expect(settings.globalVoiceCommands, true);
        expect(settings.autoLessonHandsFree, true);
        expect(settings.voiceTimeout, const Duration(seconds: 5));
        expect(settings.confidenceThreshold, 0.7);
        expect(settings.autoRequestPermissions, true);
        expect(settings.showVoiceIndicator, true);
        expect(settings.announceCommands, false);
        expect(settings.enableWakeWord, false);
        expect(settings.wakeWord, 'hey learning');
        expect(settings.persistAcrossSessions, true);
      });

      test('should create settings with custom values', () {
        const settings = HandsFreeSettings(
          defaultHandsFreeMode: true,
          globalVoiceCommands: false,
          autoLessonHandsFree: false,
          voiceTimeout: Duration(seconds: 10),
          confidenceThreshold: 0.8,
          autoRequestPermissions: false,
          showVoiceIndicator: false,
          announceCommands: true,
          enableWakeWord: true,
          wakeWord: 'hey assistant',
          persistAcrossSessions: false,
        );

        expect(settings.defaultHandsFreeMode, true);
        expect(settings.globalVoiceCommands, false);
        expect(settings.autoLessonHandsFree, false);
        expect(settings.voiceTimeout, const Duration(seconds: 10));
        expect(settings.confidenceThreshold, 0.8);
        expect(settings.autoRequestPermissions, false);
        expect(settings.showVoiceIndicator, false);
        expect(settings.announceCommands, true);
        expect(settings.enableWakeWord, true);
        expect(settings.wakeWord, 'hey assistant');
        expect(settings.persistAcrossSessions, false);
      });
    });

    group('copyWith', () {
      const original = HandsFreeSettings();

      test('should copy with updated boolean flags', () {
        final updated = original.copyWith(
          defaultHandsFreeMode: true,
          globalVoiceCommands: false,
        );

        expect(updated.defaultHandsFreeMode, true);
        expect(updated.globalVoiceCommands, false);
        expect(updated.autoLessonHandsFree, original.autoLessonHandsFree);
        expect(updated.voiceTimeout, original.voiceTimeout);
      });

      test('should copy with updated voice timeout', () {
        final updated = original.copyWith(
          voiceTimeout: const Duration(seconds: 15),
        );

        expect(updated.voiceTimeout, const Duration(seconds: 15));
        expect(updated.defaultHandsFreeMode, original.defaultHandsFreeMode);
      });

      test('should copy with updated confidence threshold', () {
        final updated = original.copyWith(
          confidenceThreshold: 0.9,
        );

        expect(updated.confidenceThreshold, 0.9);
        expect(updated.voiceTimeout, original.voiceTimeout);
      });

      test('should copy with updated wake word', () {
        final updated = original.copyWith(
          enableWakeWord: true,
          wakeWord: 'custom wake word',
        );

        expect(updated.enableWakeWord, true);
        expect(updated.wakeWord, 'custom wake word');
      });

      test('should copy with multiple updates', () {
        final updated = original.copyWith(
          defaultHandsFreeMode: true,
          autoLessonHandsFree: false,
          voiceTimeout: const Duration(seconds: 8),
          confidenceThreshold: 0.85,
          showVoiceIndicator: false,
        );

        expect(updated.defaultHandsFreeMode, true);
        expect(updated.autoLessonHandsFree, false);
        expect(updated.voiceTimeout, const Duration(seconds: 8));
        expect(updated.confidenceThreshold, 0.85);
        expect(updated.showVoiceIndicator, false);
        // Unchanged values
        expect(updated.globalVoiceCommands, original.globalVoiceCommands);
        expect(updated.wakeWord, original.wakeWord);
      });

      test('should maintain original values when no parameters provided', () {
        final updated = original.copyWith();

        expect(updated.defaultHandsFreeMode, original.defaultHandsFreeMode);
        expect(updated.globalVoiceCommands, original.globalVoiceCommands);
        expect(updated.voiceTimeout, original.voiceTimeout);
        expect(updated.confidenceThreshold, original.confidenceThreshold);
      });
    });

    group('JSON serialization', () {
      test('should serialize to JSON', () {
        const settings = HandsFreeSettings(
          defaultHandsFreeMode: true,
          voiceTimeout: Duration(seconds: 10),
          confidenceThreshold: 0.8,
        );

        final json = settings.toJson();

        expect(json['defaultHandsFreeMode'], true);
        expect(json['globalVoiceCommands'], true);
        expect(json['voiceTimeoutMs'], 10000);
        expect(json['confidenceThreshold'], 0.8);
        expect(json['wakeWord'], 'hey learning');
      });

      test('should deserialize from JSON', () {
        final json = {
          'defaultHandsFreeMode': true,
          'globalVoiceCommands': false,
          'autoLessonHandsFree': false,
          'voiceTimeoutMs': 8000,
          'confidenceThreshold': 0.85,
          'autoRequestPermissions': false,
          'showVoiceIndicator': false,
          'announceCommands': true,
          'enableWakeWord': true,
          'wakeWord': 'custom',
          'persistAcrossSessions': false,
        };

        final settings = HandsFreeSettings.fromJson(json);

        expect(settings.defaultHandsFreeMode, true);
        expect(settings.globalVoiceCommands, false);
        expect(settings.autoLessonHandsFree, false);
        expect(settings.voiceTimeout, const Duration(milliseconds: 8000));
        expect(settings.confidenceThreshold, 0.85);
        expect(settings.autoRequestPermissions, false);
        expect(settings.showVoiceIndicator, false);
        expect(settings.announceCommands, true);
        expect(settings.enableWakeWord, true);
        expect(settings.wakeWord, 'custom');
        expect(settings.persistAcrossSessions, false);
      });

      test('should handle missing JSON fields with defaults', () {
        final json = <String, dynamic>{};

        final settings = HandsFreeSettings.fromJson(json);

        expect(settings.defaultHandsFreeMode, false);
        expect(settings.globalVoiceCommands, true);
        expect(settings.voiceTimeout, const Duration(milliseconds: 5000));
        expect(settings.confidenceThreshold, 0.7);
      });

      test('should round-trip JSON serialization', () {
        const original = HandsFreeSettings(
          defaultHandsFreeMode: true,
          voiceTimeout: Duration(seconds: 12),
          confidenceThreshold: 0.75,
          wakeWord: 'test wake word',
        );

        final json = original.toJson();
        final restored = HandsFreeSettings.fromJson(json);

        expect(restored.defaultHandsFreeMode, original.defaultHandsFreeMode);
        expect(restored.globalVoiceCommands, original.globalVoiceCommands);
        expect(restored.voiceTimeout, original.voiceTimeout);
        expect(restored.confidenceThreshold, original.confidenceThreshold);
        expect(restored.wakeWord, original.wakeWord);
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        const settings = HandsFreeSettings(
          defaultHandsFreeMode: true,
          confidenceThreshold: 0.8,
        );

        final str = settings.toString();

        expect(str, contains('defaultHandsFreeMode: true'));
        expect(str, contains('globalVoiceCommands: true'));
        expect(str, contains('confidenceThreshold: 0.8'));
      });
    });

    group('Settings scenarios', () {
      test('should create privacy-focused settings', () {
        const privacySettings = HandsFreeSettings(
          defaultHandsFreeMode: false,
          globalVoiceCommands: false,
          autoRequestPermissions: false,
          showVoiceIndicator: true,
          persistAcrossSessions: false,
        );

        expect(privacySettings.defaultHandsFreeMode, false);
        expect(privacySettings.globalVoiceCommands, false);
        expect(privacySettings.autoRequestPermissions, false);
        expect(privacySettings.showVoiceIndicator, true);
        expect(privacySettings.persistAcrossSessions, false);
      });

      test('should create power-user settings', () {
        const powerSettings = HandsFreeSettings(
          defaultHandsFreeMode: true,
          globalVoiceCommands: true,
          autoLessonHandsFree: true,
          voiceTimeout: Duration(seconds: 3),
          confidenceThreshold: 0.6,
          enableWakeWord: true,
          announceCommands: true,
        );

        expect(powerSettings.defaultHandsFreeMode, true);
        expect(powerSettings.globalVoiceCommands, true);
        expect(powerSettings.voiceTimeout, const Duration(seconds: 3));
        expect(powerSettings.confidenceThreshold, 0.6);
        expect(powerSettings.enableWakeWord, true);
      });

      test('should create accessibility-optimized settings', () {
        const accessibilitySettings = HandsFreeSettings(
          defaultHandsFreeMode: true,
          globalVoiceCommands: true,
          autoLessonHandsFree: true,
          voiceTimeout: Duration(seconds: 10),
          confidenceThreshold: 0.5,
          autoRequestPermissions: true,
          showVoiceIndicator: true,
          announceCommands: true,
        );

        expect(accessibilitySettings.defaultHandsFreeMode, true);
        expect(accessibilitySettings.voiceTimeout, const Duration(seconds: 10));
        expect(accessibilitySettings.confidenceThreshold, 0.5);
        expect(accessibilitySettings.announceCommands, true);
      });

      test('should handle confidence threshold boundaries', () {
        const lowConfidence = HandsFreeSettings(confidenceThreshold: 0.0);
        const highConfidence = HandsFreeSettings(confidenceThreshold: 1.0);
        const midConfidence = HandsFreeSettings(confidenceThreshold: 0.7);

        expect(lowConfidence.confidenceThreshold, 0.0);
        expect(highConfidence.confidenceThreshold, 1.0);
        expect(midConfidence.confidenceThreshold, 0.7);
      });

      test('should handle various timeout durations', () {
        const shortTimeout = HandsFreeSettings(voiceTimeout: Duration(seconds: 1));
        const mediumTimeout = HandsFreeSettings(voiceTimeout: Duration(seconds: 5));
        const longTimeout = HandsFreeSettings(voiceTimeout: Duration(seconds: 30));

        expect(shortTimeout.voiceTimeout, const Duration(seconds: 1));
        expect(mediumTimeout.voiceTimeout, const Duration(seconds: 5));
        expect(longTimeout.voiceTimeout, const Duration(seconds: 30));
      });
    });
  });
}
