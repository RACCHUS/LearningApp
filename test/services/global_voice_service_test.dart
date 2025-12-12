import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/global_voice_service.dart';

class _FakeVoiceService {
  bool isAvailable;
  bool hasPermissions;
  bool isListening = false;

  _FakeVoiceService({
    required this.isAvailable,
    required this.hasPermissions,
  });

  Stream<AudioState> get stateStream => const Stream.empty();

  Future<bool> startListening({
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    isListening = true;
    return false;
  }
}

void main() {
  group('GlobalVoiceService', () {
    test('enable returns false when permissions are missing', () async {
      final fakeVoice = _FakeVoiceService(isAvailable: true, hasPermissions: false);
      final service = GlobalVoiceService();

      await service.initialize(voiceService: fakeVoice as dynamic);
      final enabled = await service.enable();

      expect(enabled, isFalse);
      expect(service.isEnabled, isFalse);
    });
  });
}

