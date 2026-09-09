import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/global_voice_service.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'global_voice_service_test.mocks.dart';

@GenerateMocks([VoiceInputService])
void main() {
  group('GlobalVoiceService', () {
    test('enable returns false when permissions are missing', () async {
      final mockVoice = MockVoiceInputService();
      when(mockVoice.isAvailable).thenReturn(true);
      when(mockVoice.hasPermissions).thenReturn(false);
      
      final service = GlobalVoiceService();

      await service.initialize(voiceService: mockVoice);
      final enabled = await service.enable();

      expect(enabled, isFalse);
      expect(service.isEnabled, isFalse);
    });
  });
}

