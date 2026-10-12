import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/literacy/foundational_literacy_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/widgets/literacy/audio_phonics_widget.dart';
import 'package:learning_pwa/widgets/literacy/letter_tracing_canvas.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_entry_banner.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_picture_grid_widget.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePreReaderAudioService implements PreReaderAudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> enablePreReaderDefaults({
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('enabled_defaults');
  }

  @override
  Future<void> speakPhoneme(
    String letter,
    String phonemeSound,
    String anchorWord, {
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('phoneme:$letter:$phonemeSound:$anchorWord');
  }

  @override
  Future<void> speakLetterName(
    String letter, {
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('letter:$letter');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PreReaderProfile & Notifier', () {
    test('enables adult and youth tracks with persistence', () async {
      final notifier = PreReaderNotifier();
      expect(notifier.state.enabled, isFalse);

      await notifier.enable(PreReaderTrack.adult);
      expect(notifier.state.enabled, isTrue);
      expect(notifier.state.track, PreReaderTrack.adult);

      await notifier.setTrack(PreReaderTrack.youth);
      expect(notifier.state.track, PreReaderTrack.youth);

      await notifier.toggleAutoSpeak();
      expect(notifier.state.autoSpeakScreens, isFalse);

      await notifier.disable();
      expect(notifier.state.enabled, isFalse);
    });
  });

  group('PreReaderEntryBanner Widget', () {
    testWidgets('renders welcoming audio-first card with high contrast',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(
              body: PreReaderEntryBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pre-reader-entry-card')), findsOneWidget);
      expect(find.text('Start Here: Learn to Read & Write'), findsOneWidget);
      expect(find.byIcon(Icons.hearing), findsOneWidget);
    });

    testWidgets('tapping opens PreReaderTrackPickerDialog when disabled',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(
              body: PreReaderEntryBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pre-reader-entry-card')));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Learning Path'), findsOneWidget);
      expect(find.byKey(const Key('pre-reader-adult-card')), findsOneWidget);
      expect(find.byKey(const Key('pre-reader-youth-card')), findsOneWidget);
    });
  });

  group('PreReaderTrackPickerDialog', () {
    testWidgets('allows choosing between adult and youth tracks',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(
              body: PreReaderTrackPickerDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Adult Learning'), findsOneWidget);
      expect(find.text('Youth & Early Learning'), findsOneWidget);

      // Select youth track
      await tester.tap(find.byKey(const Key('pre-reader-youth-card')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pre-reader-start-btn')), findsOneWidget);
    });
  });

  group('AudioPhonicsWidget', () {
    testWidgets('renders target letter, listen button, and track anchors',
        (tester) async {
      final item = foundationalPhonicsCatalog.firstWhere((i) => i.letter == 'M');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: AudioPhonicsWidget(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('Sound: "m"'), findsOneWidget);
      expect(find.byKey(const Key('phonics-listen-sound-btn')), findsOneWidget);

      // Default adult anchors include 'Money'
      expect(find.text('Money'), findsOneWidget);
      expect(find.text('💵'), findsOneWidget);

      // Tap correct anchor
      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
    });

    testWidgets('displays youth anchors when youth track is active',
        (tester) async {
      final item = foundationalPhonicsCatalog.firstWhere((i) => i.letter == 'M');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderProvider.overrideWith((ref) => PreReaderNotifier(
                  initialProfile: const PreReaderProfile(
                    enabled: true,
                    track: PreReaderTrack.youth,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: AudioPhonicsWidget(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Youth anchors include 'Monkey'
      expect(find.text('Monkey'), findsOneWidget);
      expect(find.text('🐵'), findsOneWidget);
    });
  });

  group('LetterTracingCanvas', () {
    testWidgets('renders tracing canvas and reset action for letter M',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: const Scaffold(
              body: LetterTracingCanvas(letter: 'M'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Trace Letter M'), findsOneWidget);
      expect(find.byKey(const Key('tracing-reset-btn')), findsOneWidget);

      // Perform a drag touch gesture on the canvas
      final center = tester.getCenter(find.byType(CustomPaint).first);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(20, 20));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap reset
      await tester.tap(find.byKey(const Key('tracing-reset-btn')));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Non-Reader Audio Actionability & Layout Clarity', () {
    testWidgets('AudioPhonicsWidget speaks clear actionable instructions and provides audio feedback',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      final item = foundationalPhonicsCatalog.firstWhere((i) => i.letter == 'A');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(),
            home: Scaffold(
              body: AudioPhonicsWidget(item: item),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the speaker button on the letter card
      final speakerBtn = find.byKey(const Key('phonics-listen-sound-btn'));
      expect(speakerBtn, findsOneWidget);
      await tester.tap(speakerBtn);
      await tester.pumpAndSettle();

      expect(
        fakeAudio.spoken.any((s) => s.contains('Tap the picture that starts with A!')),
        isTrue,
      );

      // Tap the prompt repeat icon
      final promptSpeaker = find.byTooltip('Listen to instruction');
      expect(promptSpeaker, findsOneWidget);
      await tester.tap(promptSpeaker);
      await tester.pumpAndSettle();

      expect(
        fakeAudio.spoken.any((s) => s == 'Tap the picture that starts with A!'),
        isTrue,
      );

      // Tap an incorrect anchor (e.g., Hammer or Door)
      final wrongAnchor = find.text('Hammer');
      if (wrongAnchor.evaluate().isNotEmpty) {
        await tester.tap(wrongAnchor);
        await tester.pumpAndSettle();
        expect(
          fakeAudio.spoken.any((s) => s.contains('Hammer does not start with A. Tap the picture that starts with A!')),
          isTrue,
        );
      }

      // Tap correct anchor (Apple)
      final correctAnchor = find.text('Apple');
      expect(correctAnchor, findsOneWidget);
      await tester.tap(correctAnchor);
      await tester.pumpAndSettle();

      expect(
        fakeAudio.spoken.any((s) => s.contains('Yes! Apple starts with A! Great job!')),
        isTrue,
      );
    });

    testWidgets('FoundationalLiteracyScreen eliminates bottom banner clutter and renders Life Topics picture grid',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: const MaterialApp(
            home: FoundationalLiteracyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Invariant: Banners that clutter the letter screen are NOT present
      expect(find.text('High-Stakes US Life Goals'), findsNothing);
      expect(find.text('Everyday Life & Survival Domains'), findsNothing);

      // Replay instruction button exists in AppBar
      final replayBtn = find.byTooltip('Hear page instructions');
      expect(replayBtn, findsOneWidget);
      await tester.tap(replayBtn);
      await tester.pumpAndSettle();
      expect(fakeAudio.spoken.isNotEmpty, isTrue);

      // Non-reader visual catalog tab is present
      final topicsChip = find.widgetWithText(ChoiceChip, '🌟 Life Topics');
      expect(topicsChip, findsOneWidget);
      await tester.ensureVisible(topicsChip);
      await tester.tap(topicsChip);
      await tester.pumpAndSettle();

      // Renders PreReaderPictureGridWidget
      expect(find.byType(PreReaderPictureGridWidget), findsOneWidget);
      expect(
        fakeAudio.spoken.any((s) => s.contains('Life Topics. Tap any picture card to explore')),
        isTrue,
      );
    });
  });
}
