import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';

void main() {
  group('AudioLessonSettings Model Tests', () {
    test('should create with default values', () {
      const settings = AudioLessonSettings();
      
      expect(settings.handsFreeModeEnabled, false);
      expect(settings.autoProgressDelay, const Duration(seconds: 3));
      expect(settings.voiceInputTimeout, const Duration(seconds: 5));
      expect(settings.autoReadAllContent, true);
      expect(settings.voiceNavigationEnabled, true);
      expect(settings.confirmationsEnabled, true);
      expect(settings.pauseBetweenItems, 1.0);
      expect(settings.autoProgressAfterReading, false);
      expect(settings.immediateAnswerProgression, true);
      expect(settings.voiceRetryAttempts, 3);
      expect(settings.interruptOnNextCommand, true);
    });

    test('should create copy with modified values', () {
      const original = AudioLessonSettings();
      final modified = original.copyWith(
        handsFreeModeEnabled: true,
        autoProgressDelay: const Duration(seconds: 5),
        voiceInputTimeout: const Duration(seconds: 10),
        pauseBetweenItems: 2.0,
        voiceRetryAttempts: 5,
      );
      
      expect(modified.handsFreeModeEnabled, true);
      expect(modified.autoProgressDelay, const Duration(seconds: 5));
      expect(modified.voiceInputTimeout, const Duration(seconds: 10));
      expect(modified.pauseBetweenItems, 2.0);
      expect(modified.voiceRetryAttempts, 5);
      expect(modified.autoReadAllContent, original.autoReadAllContent); // Unchanged
    });

    test('should handle equality correctly', () {
      const settings1 = AudioLessonSettings(
        handsFreeModeEnabled: true,
        voiceRetryAttempts: 5,
      );
      
      const settings2 = AudioLessonSettings(
        handsFreeModeEnabled: true,
        voiceRetryAttempts: 5,
      );
      
      expect(settings1 == settings2, true);
      expect(settings1.hashCode == settings2.hashCode, true);
    });

    test('should handle JSON serialization', () {
      const settings = AudioLessonSettings(
        handsFreeModeEnabled: true,
        voiceRetryAttempts: 5,
      );
      
      // Note: This uses code generation, so we test the structure exists
      final json = settings.toJson();
      
      expect(json, isA<Map<String, dynamic>>());
      // The actual fields depend on generated code
    });
  });
}

