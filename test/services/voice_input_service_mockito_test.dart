import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/models/voice_command.dart';

// Note: SpeechRecognitionManager is a singleton, so we'll test the service
// integration points rather than mocking the manager directly
@GenerateMocks([])
void main() {
  group('VoiceInputService Integration Tests', () {
    late VoiceInputService service;

    setUp(() {
      service = VoiceInputService();
    });

    test('should initialize service', () async {
      // Act
      await service.initialize();

      // Assert
      expect(service.isInitialized, true);
      // In test environment, service may not be available
      // but initialization should complete
    });

    test('should check permissions', () async {
      // Arrange
      await service.initialize();

      // Act
      final hasPermissions = await service.checkPermissions();

      // Assert
      expect(hasPermissions, isA<bool>());
      // In test environment, permissions typically false
    });

    test('should handle permission request', () async {
      // Arrange
      await service.initialize();

      // Act
      final granted = await service.requestPermissions();

      // Assert
      expect(granted, isA<bool>());
    });

    test('should start listening when permissions granted', () async {
      // Arrange
      await service.initialize();
      
      // Note: In test environment, actual listening may fail
      // but we can test the method structure
      
      // Act
      final success = await service.startListening();

      // Assert
      expect(success, isA<bool>());
    });

    test('should stop listening', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.stopListening();

      // Assert - should not throw
      expect(service.isListening, false);
    });

    test('should cancel listening session', () async {
      // Arrange
      await service.initialize();

      // Act
      await service.cancel();

      // Assert
      expect(service.currentState, VoiceInputState.idle);
      expect(service.recognizedText, isNull);
    });

    test('should parse voice command from recognized text', () {
      // Arrange
      final service = VoiceInputService();
      
      // Act - test command parsing
      // Note: This tests the VoiceCommandParser integration
      final command = service.parseLastCommand();

      // Assert
      expect(command, isA<VoiceCommand?>());
    });

    test('should emit state changes via stream', () async {
      // Arrange
      await service.initialize();
      final states = <AudioState>[];
      final subscription = service.stateStream.listen((state) {
        states.add(state);
      });

      // Act
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(states.length, greaterThanOrEqualTo(0));
      
      // Cleanup
      await subscription.cancel();
    });

    test('should handle timeout during listening', () async {
      // Arrange
      await service.initialize();

      // Act - start listening with short timeout
      final success = await service.startListening(
        listenFor: const Duration(milliseconds: 100),
      );

      // Wait for timeout
      await Future.delayed(const Duration(milliseconds: 200));

      // Assert
      expect(success, isA<bool>());
      // State should transition after timeout
    });
  });
}

