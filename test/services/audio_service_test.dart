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

    test('findBestNaturalVoice prioritizes warm Zira over robotic David on Windows', () {
      const windowsVoices = [
        VoiceInfo(name: 'Microsoft David - English (United States)', locale: 'en-US'),
        VoiceInfo(name: 'Microsoft Mark - English (United States)', locale: 'en-US'),
        VoiceInfo(name: 'Microsoft Zira - English (United States)', locale: 'en-US'),
      ];

      final selected = AudioService.findBestNaturalVoice(windowsVoices, 'en-US');
      expect(selected, 'Microsoft Zira - English (United States)');
    });

    test('findBestNaturalVoice prioritizes Google US English when available', () {
      const mixedVoices = [
        VoiceInfo(name: 'Microsoft David - English (United States)', locale: 'en-US'),
        VoiceInfo(name: 'Microsoft Zira - English (United States)', locale: 'en-US'),
        VoiceInfo(name: 'Google US English', locale: 'en-US'),
      ];

      final selected = AudioService.findBestNaturalVoice(mixedVoices, 'en-US');
      expect(selected, 'Google US English');
    });

    test('findBestNaturalVoice prioritizes Microsoft Natural / Neural voices in Edge', () {
      const edgeVoices = [
        VoiceInfo(name: 'Microsoft David - English (United States)', locale: 'en-US'),
        VoiceInfo(name: 'Microsoft Jenny Online (Natural) - English (United States)', locale: 'en-US'),
      ];

      final selected = AudioService.findBestNaturalVoice(edgeVoices, 'en-US');
      expect(selected, 'Microsoft Jenny Online (Natural) - English (United States)');
    });

    test('findBestNaturalVoice selects Samantha / Apple warm voices', () {
      const macVoices = [
        VoiceInfo(name: 'Fred', locale: 'en-US'),
        VoiceInfo(name: 'Samantha', locale: 'en-US'),
      ];

      final selected = AudioService.findBestNaturalVoice(macVoices, 'en-US');
      expect(selected, 'Samantha');
    });

    test('findBestNaturalVoice returns null for empty list', () {
      final selected = AudioService.findBestNaturalVoice([], 'en-US');
      expect(selected, isNull);
    });
  });
}

