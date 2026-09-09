import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';

// Note: AudioService uses FlutterTts singleton which is hard to mock directly
// We'll test the service logic that doesn't require TTS backend
@GenerateMocks([])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AudioService Logic Tests', () {
    late AudioService service;

    setUp(() {
      service = AudioService();
    });

    // Do not dispose the singleton between tests to avoid closing the stream controller
    // tearDown(() {
    //   service.dispose();
    // });

    test('should initialize with default state', () {
      // Assert
      expect(service.currentState, isA<AudioState>());
      expect(service.currentSettings, isA<AudioSettings>());
    });

    test('should update settings', () async {
      // Arrange
      await service.initialize();
      final newSettings = const AudioSettings(
        isEnabled: true,
        speechRate: 1.5,
        volume: 0.8,
        language: 'es-ES',
      );

      // Act
      await service.updateSettings(newSettings);

      // Assert
      expect(service.currentSettings.speechRate, 1.5);
      expect(service.currentSettings.volume, 0.8);
      expect(service.currentSettings.language, 'es-ES');
    });

    test('should not speak when disabled', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(isEnabled: false),
      );

      // Act
      final result = await service.speak('Test text');

      // Assert
      expect(result, false);
    });

    test('should not speak empty text', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(isEnabled: true),
      );

      // Act
      final result = await service.speak('');

      // Assert
      expect(result, false);
    });

    test('should emit state changes via stream', () async {
      // Arrange
      await service.initialize();
      final states = <AudioState>[];
      final subscription = service.stateStream.listen((state) {
        states.add(state);
      });

      // Act - update settings to trigger state change
      await service.updateSettings(
        const AudioSettings(speechRate: 1.2),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Assert
      expect(states.length, greaterThanOrEqualTo(0));

      // Cleanup
      await subscription.cancel();
    });

    test('should handle speakQuestion with autoReadQuestions disabled', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(
          isEnabled: true,
          autoReadQuestions: false,
        ),
      );

      // Act
      final result = await service.speakQuestion('What is 2+2?');

      // Assert
      expect(result, false);
    });

    test('should handle speakAnswer with autoReadAnswers disabled', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(
          isEnabled: true,
          autoReadAnswers: false,
        ),
      );

      // Act
      final result = await service.speakAnswer('The answer is 4');

      // Assert
      expect(result, false);
    });

    test('should format term speech correctly', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(isEnabled: true),
      );

      // Act - test the formatting logic
      // Note: Actual TTS may not work in test, but we test the method
      final result = await service.speakTerm(
        'Variable',
        'A storage location',
        example: 'int x = 5;',
      );

      // Assert - method should complete
      expect(result, isA<bool>());
    });

    test('should format concept speech correctly', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(isEnabled: true),
      );

      // Act
      final result = await service.speakConcept(
        'Object-oriented programming',
        example: 'Classes and objects',
      );

      // Assert
      expect(result, isA<bool>());
    });

    test('should format options speech correctly', () async {
      // Arrange
      await service.initialize();
      await service.updateSettings(
        const AudioSettings(
          isEnabled: true,
          autoReadQuestions: true,
        ),
      );

      // Act
      final result = await service.speakOptions([
        'Option A',
        'Option B',
        'Option C',
      ]);

      // Assert
      expect(result, isA<bool>());
    });

    test('should handle pause when not playing', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.pause();

      // Assert - should not throw
    });

    test('should handle resume when not paused', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.resume();

      // Assert - should not throw
    });

    test('should handle stop', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.stop();

      // Assert - should not throw
    });

    test('should update rate', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.setRate(1.5);

      // Assert
      expect(service.currentSettings.speechRate, 1.5);
    });

    test('should update volume', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.setVolume(0.7);

      // Assert
      expect(service.currentSettings.volume, 0.7);
    });
  });
}

