import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/hands_free_settings.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:learning_pwa/screens/study/lesson_content_pager.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeStudyNotifier extends StateNotifier<StudyState> implements StudyNotifier {
  FakeStudyNotifier() : super(StudyState.initial());

  @override
  void markTermAsKnown(String termId) {}

  @override
  void markTermAsDifficult(String termId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioSettingsNotifier extends StateNotifier<AudioSettings> implements AudioSettingsNotifier {
  FakeAudioSettingsNotifier() : super(const AudioSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioLessonSettingsNotifier extends StateNotifier<AudioLessonSettings> implements AudioLessonSettingsNotifier {
  FakeAudioLessonSettingsNotifier() : super(const AudioLessonSettings(handsFreeModeEnabled: false));

  @override
  void toggleHandsFreeMode() {
    state = state.copyWith(handsFreeModeEnabled: !state.handsFreeModeEnabled);
  }

  @override
  AudioLessonSettings getDefaultSettings() => const AudioLessonSettings();

  @override
  Future<void> updateSettings(AudioLessonSettings newSettings) async {
    state = newSettings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHandsFreeSettingsNotifier extends StateNotifier<HandsFreeSettings> implements HandsFreeSettingsNotifier {
  FakeHandsFreeSettingsNotifier() : super(const HandsFreeSettings(autoLessonHandsFree: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGlobalVoiceNotifier extends StateNotifier<GlobalVoiceState> implements GlobalVoiceNotifier {
  FakeGlobalVoiceNotifier() : super(const GlobalVoiceState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records microphone permission calls without touching browser audio.
class FakeAudioPlaybackNotifier extends StateNotifier<AudioState>
    implements AudioPlaybackNotifier {
  FakeAudioPlaybackNotifier({this.alreadyAllowed = false}) : super(const AudioState());

  final bool alreadyAllowed;
  int permissionRequests = 0;

  @override
  Future<bool> checkMicrophonePermissions() async => alreadyAllowed;

  @override
  Future<bool> requestMicrophonePermissions() async {
    permissionRequests++;
    return false; // stop before the orchestrator starts
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentPreReaderAudio extends PreReaderAudioService {
  @override
  Future<void> speak(String text,
          {PreReaderTrack track = PreReaderTrack.adult, double? customRate}) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();
  final List<LessonContent> testContents = [
    TermContent(
      id: 'tc-1',
      lessonId: 'lesson-1',
      order: 1,
      term: 'Chloroplast',
      definition: 'Organelle where photosynthesis takes place in plant cells.',
      createdAt: now,
      updatedAt: now,
    ),
    TermContent(
      id: 'tc-2',
      lessonId: 'lesson-1',
      order: 2,
      term: 'Ribosome',
      definition: 'Cellular machinery for protein synthesis.',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  List<Override> commonOverrides() => [
        globalVoiceProvider.overrideWith((ref) => FakeGlobalVoiceNotifier()),
        handsFreeSettingsProvider.overrideWith((ref) => FakeHandsFreeSettingsNotifier()),
        audioLessonSettingsProvider.overrideWith((ref) => FakeAudioLessonSettingsNotifier()),
        audioSettingsProvider.overrideWith((ref) => FakeAudioSettingsNotifier()),
        canSpeakProvider.overrideWithValue(false),
        canListenProvider.overrideWithValue(false),
        studyProvider.overrideWith((ref) => FakeStudyNotifier()),
      ];

  group('LessonContentPager Focus Mode & Pomodoro Break Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'settings': '{"studyBatchSize":0,"recallBeforeReveal":false,"notificationsEnabled":true,"darkMode":true}',
      });
    });

    testWidgets('toggles focus mode in LessonContentPager', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: commonOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: LessonContentPager(contentList: testContents),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(find.byTooltip('Focus mode'), findsOneWidget);

      // Tap focus mode toggle
      await tester.tap(find.byTooltip('Focus mode'));
      await tester.pumpAndSettle();

      // Normal page title is hidden, minimal exit button is visible
      expect(find.text('Page 1 of 2'), findsNothing);
      expect(find.byTooltip('Exit focus mode'), findsOneWidget);

      // Tap exit focus mode
      await tester.tap(find.byTooltip('Exit focus mode'));
      await tester.pumpAndSettle();

      expect(find.text('Page 1 of 2'), findsOneWidget);
    });

    testWidgets('displays BreakOverlay over lesson when Pomodoro break triggers and resumes on tap', (tester) async {
      final container = ProviderContainer(
        overrides: commonOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: LessonContentPager(contentList: testContents),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No break overlay initially
      expect(find.text('Nice work!'), findsNothing);
      expect(find.text('Chloroplast'), findsOneWidget);

      // Trigger break on timer notifier
      final timerNotifier = container.read(timerProvider.notifier);
      timerNotifier.toggleEnabled(true);
      timerNotifier.setBreak(enabled: true, durationSeconds: 300);
      timerNotifier.setDuration(1);
      timerNotifier.start();

      timerNotifier.tick(); // Work block ends -> break starts
      timerNotifier.pause(); // Pause live ticker for test determinism

      await tester.pumpAndSettle();

      // Break overlay appears over lesson
      expect(find.text('Nice work!'), findsOneWidget);
      expect(find.text('Resume now'), findsOneWidget);

      // Tap "Resume now"
      await tester.tap(find.text('Resume now'));
      await tester.pumpAndSettle();

      // Break overlay dismisses, lesson content visible again
      expect(find.text('Nice work!'), findsNothing);
      expect(container.read(timerProvider).isOnBreak, isFalse);
    });
  });
  group('Pre-reader microphone pre-permission (literacy plan §5.2)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<FakeAudioPlaybackNotifier> pump(WidgetTester tester,
        {required bool preReader, bool alreadyAllowed = false}) async {
      final audio = FakeAudioPlaybackNotifier(alreadyAllowed: alreadyAllowed);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...commonOverrides(),
          audioPlaybackProvider.overrideWith((ref) => audio),
          preReaderAudioServiceProvider.overrideWithValue(_SilentPreReaderAudio()),
          preReaderProvider.overrideWith((ref) => PreReaderNotifier(
                audioService: _SilentPreReaderAudio(),
                initialProfile: PreReaderProfile(enabled: preReader),
              )),
        ],
        child: MaterialApp(
          home: Scaffold(body: LessonContentPager(contentList: testContents)),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Enable Hands-Free'));
      await tester.pumpAndSettle();
      return audio;
    }

    testWidgets('tap-only never shows the browser prompt', (tester) async {
      final audio = await pump(tester, preReader: true);
      expect(find.byKey(const Key('pre-permission-tap-only')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pre-permission-tap-only')));
      await tester.pumpAndSettle();
      expect(audio.permissionRequests, 0);
      expect(find.byTooltip('Enable Hands-Free'), findsOneWidget,
          reason: 'hands-free stays off');
    });

    testWidgets('choosing the microphone then asks the browser', (tester) async {
      final audio = await pump(tester, preReader: true);
      await tester.tap(find.byKey(const Key('pre-permission-enable-mic')));
      await tester.pumpAndSettle();
      expect(audio.permissionRequests, 1);
    });

    testWidgets('not shown once the microphone is already allowed', (tester) async {
      final audio = await pump(tester, preReader: true, alreadyAllowed: true);
      expect(find.byKey(const Key('pre-permission-tap-only')), findsNothing);
      expect(audio.permissionRequests, 1);
    });

    testWidgets('other learners go straight to the browser prompt', (tester) async {
      final audio = await pump(tester, preReader: false);
      expect(find.byKey(const Key('pre-permission-tap-only')), findsNothing);
      expect(audio.permissionRequests, 1);
    });
  });
}
