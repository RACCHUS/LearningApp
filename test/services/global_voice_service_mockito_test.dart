import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/global_voice_service.dart';
import 'package:learning_pwa/services/enhanced_voice_input_service.dart';
import 'package:mockito/mockito.dart';

class MockVoiceService extends Mock implements EnhancedVoiceInputService {
  @override
  bool get isAvailable => super.noSuchMethod(Invocation.getter(#isAvailable), returnValue: false);
  
  @override
  bool get hasPermissions => super.noSuchMethod(Invocation.getter(#hasPermissions), returnValue: false);
  
  @override
  Stream<AudioState> get stateStream => super.noSuchMethod(Invocation.getter(#stateStream), returnValue: const Stream.empty());
  
  @override
  Future<bool> startListening({String? localeId, Duration? listenFor, Duration? pauseFor}) => 
    super.noSuchMethod(Invocation.method(#startListening, [], {#localeId: localeId, #listenFor: listenFor, #pauseFor: pauseFor}), returnValue: Future.value(false));
}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('GlobalVoiceService with mockito', () {
    late GlobalVoiceService service;
    late MockVoiceService mockVoice;
    late MockGoRouter mockRouter;
    late StreamController<AudioState> stateController;

    setUp(() {
      service = GlobalVoiceService();
      mockVoice = MockVoiceService();
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
      await stateController.close();
    });

    test('enable succeeds when permissions and availability are true', () async {
      await service.initialize(voiceService: mockVoice, router: mockRouter);

      final enabled = await service.enable();

      expect(enabled, isTrue);
      expect(service.isEnabled, isTrue);
      expect(service.isListening, isTrue);

      // Emit idle to complete listening loop
      stateController.add(const AudioState(voiceInputState: VoiceInputState.idle));
      await Future.delayed(const Duration(milliseconds: 20));
    });

    test('enable fails when permissions are missing', () async {
      when(mockVoice.hasPermissions).thenReturn(false);
      await service.initialize(voiceService: mockVoice, router: mockRouter);

      final enabled = await service.enable();

      expect(enabled, isFalse);
      expect(service.isEnabled, isFalse);
    });
  });
}

