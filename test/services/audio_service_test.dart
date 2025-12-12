import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';

void main() {
  group('AudioService (platform-agnostic behavior)', () {
    late AudioService service;

    setUp(() {
      service = AudioService();
    });

    test('speak returns false when not initialized or disabled', () async {
      final result = await service.speak('Hello world');

      expect(result, isFalse);
      expect(service.currentState.playbackState, AudioPlaybackState.idle);
    });

    test('updateSettings stores preferences even without TTS backend', () async {
      const newSettings = AudioSettings(
        language: 'es-ES',
        isEnabled: false,
        speechRate: 1.1,
        volume: 0.8,
      );

      await service.updateSettings(newSettings);

      expect(service.currentSettings.language, 'es-ES');
      expect(service.currentSettings.isEnabled, isFalse);
      expect(service.currentSettings.speechRate, closeTo(1.1, 0.0001));
      expect(service.currentSettings.volume, closeTo(0.8, 0.0001));
    });
  });
}

