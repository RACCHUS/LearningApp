import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/widgets/literacy/global_narration_controls.dart';

class _FakeAudioService extends Fake implements AudioService {
  final _events = StreamController<AudioState>.broadcast();
  AudioState _state = const AudioState();
  int pauses = 0;
  int resumes = 0;
  int restarts = 0;
  int stops = 0;

  @override
  AudioState get currentState => _state;

  @override
  Stream<AudioState> get stateStream => _events.stream;

  void emit(AudioPlaybackState playbackState) {
    _state = AudioState(
      playbackState: playbackState,
      currentText: 'Spoken help message.',
    );
    _events.add(_state);
  }

  @override
  Future<void> pause() async {
    pauses++;
    emit(AudioPlaybackState.paused);
  }

  @override
  Future<void> resume() async {
    resumes++;
    emit(AudioPlaybackState.playing);
  }

  @override
  Future<bool> restart() async {
    restarts++;
    emit(AudioPlaybackState.playing);
    return true;
  }

  @override
  Future<void> stop() async {
    stops++;
    emit(AudioPlaybackState.stopped);
  }

  Future<void> close() => _events.close();
}

void main() {
  testWidgets('spoken guidance has pause, resume, restart and stop everywhere',
      (tester) async {
    final fake = _FakeAudioService();
    addTearDown(fake.close);

    await tester.pumpWidget(MaterialApp(
      home: GlobalNarrationControls(
        audioService: fake,
        child: const Scaffold(body: Center(child: Text('Other home content'))),
      ),
    ));

    expect(find.byKey(const Key('narration-pause')), findsNothing);
    expect(find.text('Other home content'), findsOneWidget);

    fake.emit(AudioPlaybackState.playing);
    await tester.pump();
    expect(find.byKey(const Key('narration-pause')), findsOneWidget);
    expect(find.byKey(const Key('narration-resume')), findsOneWidget);
    expect(find.byKey(const Key('narration-restart')), findsOneWidget);
    expect(find.byKey(const Key('narration-stop')), findsOneWidget);

    await tester.tap(find.byKey(const Key('narration-pause')));
    await tester.pump();
    expect(fake.pauses, 1);

    await tester.tap(find.byKey(const Key('narration-resume')));
    await tester.pump();
    expect(fake.resumes, 1);

    await tester.tap(find.byKey(const Key('narration-restart')));
    await tester.pump();
    expect(fake.restarts, 1);

    await tester.tap(find.byKey(const Key('narration-stop')));
    await tester.pump();
    expect(fake.stops, 1);
    // Even after stopping, users can explicitly replay the instructions.
    expect(find.byKey(const Key('narration-restart')), findsOneWidget);
  });
}
