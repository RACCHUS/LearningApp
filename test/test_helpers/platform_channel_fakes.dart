// Fakes for plugin method channels that have no implementation under
// `flutter test` (plan PR-4a, finding Q-07).
//
// Without them, code that touches a plugin logs MissingPluginException on
// every test and silently takes its error path, which hides real errors in
// the log and means the happy path is not what the test exercises.
//
// Install these ONLY in tests that are not about the plugin failing. A test
// of a plugin-failure path should leave the channel unmocked (or register a
// handler that throws) and assert on the resulting behavior.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _ttsChannel = MethodChannel('flutter_tts');

/// Registers a `flutter_tts` handler that behaves like a working engine:
/// commands (`speak`, `stop`, `pause`, `set*`) succeed with `1`, and
/// `getVoices` returns [voices]. Like a real engine, each `speak` is followed
/// by a `speak.onComplete` callback from the platform (disable with
/// [completeSpeech] to test code waiting on unfinished speech). Removed
/// automatically after the test.
///
/// Call from `setUp` (or inside a test).
void installFakeTtsChannel({
  List<Map<String, String>> voices = const [],
  bool completeSpeech = true,
}) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_ttsChannel, (call) async {
    switch (call.method) {
      case 'getVoices':
        return voices;
      case 'getLanguages':
        return <String>['en-US'];
      case 'speak':
        if (completeSpeech) {
          Future<void>.microtask(() => messenger.handlePlatformMessage(
                _ttsChannel.name,
                _ttsChannel.codec.encodeMethodCall(const MethodCall('speak.onComplete')),
                (_) {},
              ));
        }
        return 1;
      default:
        return 1;
    }
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_ttsChannel, null));
}
