import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_picture_grid_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Library picture grid must narrate with the learner's chosen voice
/// track and speech rate, like every other pre-reader screen. It previously
/// called the audio service directly and always used the adult default.
class _RecordingAudioService extends PreReaderAudioService {
  final calls = <({String text, PreReaderTrack track, double? rate})>[];

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    calls.add((text: text, track: track, rate: customRate));
  }

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_RecordingAudioService> pumpGrid(
    WidgetTester tester,
    PreReaderProfile profile,
  ) async {
    final audio = _RecordingAudioService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preReaderAudioServiceProvider.overrideWithValue(audio),
          preReaderProvider.overrideWith(
            (ref) => PreReaderNotifier(audioService: audio, initialProfile: profile),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PreReaderPictureGridWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return audio;
  }

  testWidgets('directory and tile speakers use the youth track and rate',
      (tester) async {
    final audio = await pumpGrid(
      tester,
      const PreReaderProfile(
        enabled: true,
        track: PreReaderTrack.youth,
        speechRate: 0.7,
      ),
    );

    await tester.tap(find.byTooltip('Hear visual directory instructions'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byKey(const Key('picture-tile-tile_citizenship')),
      matching: find.byTooltip('Listen to US Citizenship'),
    ));
    await tester.pumpAndSettle();

    expect(audio.calls, hasLength(2));
    for (final call in audio.calls) {
      expect(call.track, PreReaderTrack.youth);
      expect(call.rate, 0.7);
    }
  });

  testWidgets('adult track keeps the adult voice', (tester) async {
    final audio = await pumpGrid(
      tester,
      const PreReaderProfile(enabled: true, track: PreReaderTrack.adult),
    );

    await tester.tap(find.byTooltip('Hear visual directory instructions'));
    await tester.pumpAndSettle();

    expect(audio.calls.single.track, PreReaderTrack.adult);
  });
}
