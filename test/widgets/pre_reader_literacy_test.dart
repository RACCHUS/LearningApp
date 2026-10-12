import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/widgets/literacy/audio_phonics_widget.dart';
import 'package:learning_pwa/widgets/literacy/letter_tracing_canvas.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_entry_banner.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      expect(find.text('Sound: /m/'), findsOneWidget);
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
}
