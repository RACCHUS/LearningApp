import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/global_voice_service.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'global_voice_service_mockito_test.mocks.dart';

@GenerateMocks([VoiceInputService, GoRouter])
void main() {
  group('GlobalVoiceService with mockito', () {
    late GlobalVoiceService service;
    late MockVoiceInputService mockVoice;
    late MockGoRouter mockRouter;
    late StreamController<AudioState> stateController;

    setUp(() {
      service = GlobalVoiceService();
      mockVoice = MockVoiceInputService();
      mockRouter = MockGoRouter();
      stateController = StreamController<AudioState>.broadcast();

      when(mockVoice.isAvailable).thenReturn(true);
      when(mockVoice.hasPermissions).thenReturn(true);
      when(mockVoice.stateStream).thenAnswer((_) => stateController.stream);
      when(mockVoice.startListening(
        localeId: anyNamed('localeId'),
        listenFor: anyNamed('listenFor'),
        pauseFor: anyNamed('pauseFor'),
      )).thenAnswer((_) async => true);
    });

    tearDown(() async {
      service.disable();
      await stateController.close();
    });

    test('enable succeeds when permissions and availability are true', () async {
      await service.initialize(voiceService: mockVoice, router: mockRouter);

      // Don't await enable() as it starts a background listening loop
      // Instead, wait for the service state to update
      unawaited(service.enable());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(service.isEnabled, isTrue);
      expect(service.isListening, isTrue);
      
      // Emit idle state to complete the listening loop
      stateController.add(const AudioState(voiceInputState: VoiceInputState.idle));
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('enable fails when permissions are missing', () async {
      // Create a new mock with different permissions
      final mockVoiceNoPerm = MockVoiceInputService();
      when(mockVoiceNoPerm.isAvailable).thenReturn(true);
      when(mockVoiceNoPerm.hasPermissions).thenReturn(false);
      
      final testService = GlobalVoiceService();
      await testService.initialize(voiceService: mockVoiceNoPerm, router: mockRouter);

      final enabled = await testService.enable();

      expect(enabled, isFalse);
      expect(testService.isEnabled, isFalse);
    });
  });
}

