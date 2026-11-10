import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';

class _ControlledAudioService extends Fake implements AudioService {
  final initializeStarted = Completer<void>();
  final initializeGate = Completer<void>();
  final settingsStarted = Completer<void>();
  final settingsGate = Completer<void>();
  final spoken = <String>[];
  int stopCount = 0;

  @override
  AudioSettings get currentSettings => const AudioSettings();

  @override
  Future<void> initialize() async {
    if (!initializeStarted.isCompleted) initializeStarted.complete();
    await initializeGate.future;
  }

  @override
  Future<void> updateSettings(AudioSettings settings) async {
    if (!settingsStarted.isCompleted) settingsStarted.complete();
    await settingsGate.future;
  }

  @override
  Future<bool> speak(String text, {bool interrupt = false}) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stopping during initialization cancels pending narration', () async {
    final audio = _ControlledAudioService();
    final reader = PreReaderAudioService(audioService: audio);
    final pending = reader.speak('Cancelled narration');
    await audio.initializeStarted.future;

    await reader.stop();
    audio.initializeGate.complete();
    audio.settingsGate.complete();
    await pending;

    expect(audio.stopCount, 2);
    expect(audio.spoken, isEmpty);
    await reader.speak('Manual guidance');
    expect(audio.spoken, ['Manual guidance']);
  });

  test(
    'stopping during voice configuration cancels pending narration',
    () async {
      final audio = _ControlledAudioService();
      audio.initializeGate.complete();
      final reader = PreReaderAudioService(audioService: audio);
      final pending = reader.speak('Cancelled narration');
      await audio.settingsStarted.future;

      await reader.stop();
      audio.settingsGate.complete();
      await pending;

      expect(audio.stopCount, 2);
      expect(audio.spoken, isEmpty);
      await reader.speak('Manual guidance');
      expect(audio.spoken, ['Manual guidance']);
    },
  );

  test('a newer narration replaces an older pending request', () async {
    final audio = _ControlledAudioService();
    final reader = PreReaderAudioService(audioService: audio);
    final first = reader.speak('Old');
    await audio.initializeStarted.future;
    final second = reader.speak('New');
    audio.initializeGate.complete();
    audio.settingsGate.complete();

    await Future.wait([first, second]);
    expect(audio.spoken, ['New']);
  });

  test('concurrent audio initialization shares voice discovery', () async {
    const channel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final discoveryStarted = Completer<void>();
    final discoveryGate = Completer<void>();
    var discoveryCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getVoices') {
        discoveryCalls++;
        if (discoveryCalls == 1) {
          discoveryStarted.complete();
          await discoveryGate.future;
        }
        return [
          {'name': 'Test voice', 'locale': 'en-US'},
        ];
      }
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final audio = AudioService();
    final first = audio.initialize();
    await discoveryStarted.future;
    final second = audio.initialize();
    await Future<void>.delayed(Duration.zero);
    final callsBeforeRelease = discoveryCalls;
    discoveryGate.complete();
    await Future.wait([first, second]);

    expect(callsBeforeRelease, 1);
  });

  test('audio stop cancels speech still applying its voice', () async {
    const channel = MethodChannel('flutter_tts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final voiceStarted = Completer<void>();
    final voiceGate = Completer<void>();
    final spoken = <String>[];
    var delayVoice = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getVoices':
          return [
            {'name': 'Test voice', 'locale': 'en-US'},
          ];
        case 'setVoice':
          if (delayVoice) {
            delayVoice = false;
            voiceStarted.complete();
            await voiceGate.future;
          }
          return 1;
        case 'speak':
          spoken.add(call.arguments as String);
          return 1;
        default:
          return 1;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final audio = AudioService();
    await audio.initialize();
    delayVoice = true;
    final pending = audio.speak('Cancelled narration');
    await voiceStarted.future;
    await audio.stop();
    voiceGate.complete();

    expect(await pending, isFalse);
    expect(spoken, isEmpty);
    expect(await audio.speak('Manual guidance'), isTrue);
    expect(spoken, ['Manual guidance']);
  });
}
