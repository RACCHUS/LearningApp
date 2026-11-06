import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/screens/settings/audio_settings_screen.dart';
import 'package:learning_pwa/widgets/audio/audio_preferences_sheet.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';

// Reproduces the learner report "it has the mic but I didn't see option for
// it to be read": with read-aloud switched off but the microphone permitted,
// question modes showed the mic and no speaker at all.
void main() {
  late Directory hiveDir;
  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('reader_consistency');
    Hive.init(hiveDir.path);
    if (!Hive.isAdapterRegistered(AudioSettingsAdapter().typeId)) {
      Hive.registerAdapter(AudioSettingsAdapter());
    }
  });
  tearDownAll(() async {
    await Hive.close();
    hiveDir.deleteSync(recursive: true);
  });

  Widget host(Widget child, {required bool canSpeak, required bool canListen}) {
    return ProviderScope(
      overrides: [
        canSpeakProvider.overrideWithValue(canSpeak),
        canListenProvider.overrideWithValue(canListen),
        readAloudOffProvider.overrideWithValue(!canSpeak),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  const header = AudioQuestionHeader(
    questionText: 'What is 2 + 2?',
    onVoiceInput: _noop,
  );

  testWidgets('question header keeps a speaker when read-aloud is off',
      (tester) async {
    await tester.pumpWidget(host(header, canSpeak: false, canListen: true));
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byKey(const Key('audio-reader-control')), findsOneWidget);
  });

  testWidgets('question header shows speaker and mic when both are on',
      (tester) async {
    await tester.pumpWidget(host(header, canSpeak: true, canListen: true));
    await tester.pump();

    expect(find.byKey(const Key('audio-reader-control')), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('text blocks keep a speaker when read-aloud is off',
      (tester) async {
    await tester.pumpWidget(host(
      const AudioTextWidget(text: 'Photosynthesis makes sugar.'),
      canSpeak: false,
      canListen: false,
    ));
    await tester.pump();

    expect(find.byKey(const Key('audio-reader-control')), findsOneWidget);
  });

  testWidgets('read-aloud switch can be turned back on after turning it off',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [canSpeakProvider.overrideWithValue(false)],
      child: const MaterialApp(home: AudioSettingsScreen()),
    ));
    await tester.pump();

    final readAloud = tester.widget<Switch>(
      find.byKey(const Key('audio-read-aloud-switch')),
    );
    expect(readAloud.onChanged, isNotNull);
  });

  testWidgets('lesson app bar action opens read-aloud preferences',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: const [AudioPreferencesAction()]),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('audio-preferences-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('audio-preferences-read-aloud')), findsOneWidget);
    expect(find.text('Microphone and all audio settings'), findsOneWidget);
  });
}

void _noop(String _) {}
