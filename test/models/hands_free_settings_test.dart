import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';

void main() {
  group('HandsFreeSettings Model Tests', () {
    test('should create with default values', () {
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

    test('should serialize to JSON', () {
      const settings = HandsFreeSettings(
        defaultHandsFreeMode: true,
        confidenceThreshold: 0.8,
        voiceTimeout: Duration(seconds: 10),
      );
      
      final json = settings.toJson();
      
      expect(json['defaultHandsFreeMode'], true);
      expect(json['globalVoiceCommands'], true);
      expect(json['confidenceThreshold'], 0.8);
      expect(json['voiceTimeoutMs'], 10000);
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
        'wakeWord': 'custom wake',
        'persistAcrossSessions': false,
      };
      
      final settings = HandsFreeSettings.fromJson(json);
      
      expect(settings.defaultHandsFreeMode, true);
      expect(settings.globalVoiceCommands, false);
      expect(settings.voiceTimeout, const Duration(seconds: 8));
      expect(settings.confidenceThreshold, 0.85);
      expect(settings.wakeWord, 'custom wake');
    });

    test('should create copy with modified values', () {
      const original = HandsFreeSettings();
      final modified = original.copyWith(
        defaultHandsFreeMode: true,
        confidenceThreshold: 0.9,
        voiceTimeout: const Duration(seconds: 15),
      );
      
      expect(modified.defaultHandsFreeMode, true);
      expect(modified.confidenceThreshold, 0.9);
      expect(modified.voiceTimeout, const Duration(seconds: 15));
      expect(modified.globalVoiceCommands, original.globalVoiceCommands); // Unchanged
    });

    test('should handle equality correctly', () {
      const settings1 = HandsFreeSettings(
        defaultHandsFreeMode: true,
        confidenceThreshold: 0.8,
      );
      
      const settings2 = HandsFreeSettings(
        defaultHandsFreeMode: true,
        confidenceThreshold: 0.8,
      );
      
      expect(settings1 == settings2, true);
      expect(settings1.hashCode == settings2.hashCode, true);
    });
  });
}

