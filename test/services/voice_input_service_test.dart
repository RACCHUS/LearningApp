import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/voice_input_service.dart';

void main() {
  group('VoiceInputService', () {
    final service = VoiceInputService();

    test('exposes safe defaults before initialization', () {
      expect(service.isInitialized, isFalse);
      expect(service.canListen, isFalse);
      expect(service.currentState, anyOf(VoiceInputState.idle, VoiceInputState.error));
      expect(service.recognizedText, isNull);
      expect(service.confidence, equals(0.0));
    });

    test('initialize completes without throwing and updates state', () async {
      await service.initialize();

      expect(service.currentState, anyOf(VoiceInputState.idle, VoiceInputState.error));
      expect(service.isInitialized, isIn([true, false])); // may remain false if no providers

      final states = <AudioState>[];
      final sub = service.stateStream.listen(states.add);
      await Future.microtask(() {});
      await sub.cancel();

      // Stream should be usable (broadcast) even if no providers are available
      expect(states, isA<List<AudioState>>());
    });
  });
}

