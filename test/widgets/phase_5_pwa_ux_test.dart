import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/next_action_engine.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/services/taxonomy/taxonomy_crosswalk_service.dart';
import 'package:learning_pwa/widgets/help/help_center_sheet.dart';
import 'package:learning_pwa/widgets/learn/continue_card.dart';
import 'package:learning_pwa/widgets/literacy/pre_permission_dialog.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_picture_grid_widget.dart';
import 'package:learning_pwa/widgets/literacy/pwa_audio_unlock_banner.dart';

class _FakePreReaderAudioService extends PreReaderAudioService {
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

  Future<void> playPhonemeSound(String letter) async {
    spoken.add('sound:$letter');
  }

  @override
  Future<void> speakLetterName(
    String letter, {
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('letter:$letter');
  }

  @override
  Future<void> enablePreReaderDefaults({
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('enabled_defaults');
  }
}

void main() {
  group('Phase 5: Catalog Findability & Seeded Cluster', () {
    test('TaxonomyCrosswalkService includes cluster_life_milestones', () async {
      final service = TaxonomyCrosswalkService();
      final clusters = await service.getCatalogClusters();
      final milestoneCluster = clusters.firstWhere(
        (c) => c.slug == 'cluster_life_milestones',
        orElse: () => throw Exception('cluster_life_milestones not found'),
      );

      expect(milestoneCluster.title, contains('Life Milestones'));
      expect(milestoneCluster.emoji, equals('🏛️'));
    });

    testWidgets('PreReaderPictureGridWidget renders all 8 picture tiles and handles taps',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PreReaderPictureGridWidget(
                  onAnyTileTapped: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Visual Picture Directory'), findsOneWidget);

      // Verify all 8 core picture tiles
      expect(find.byKey(const Key('picture-tile-tile_citizenship')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_driver')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_ged')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_workplace')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_food')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_health')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_cash')), findsOneWidget);
      expect(find.byKey(const Key('picture-tile-tile_phonics')), findsOneWidget);

      // Tap header speaker button to hear all instructions
      final headerSpeaker = find.byTooltip('Hear visual directory instructions');
      expect(headerSpeaker, findsOneWidget);
      await tester.tap(headerSpeaker);
      await tester.pumpAndSettle();

      expect(fakeAudio.spoken.any((s) => s.contains('Visual Picture Directory')), isTrue);

      // Tap speaker on citizenship card
      final citizenshipTileSpeaker = find.descendant(
        of: find.byKey(const Key('picture-tile-tile_citizenship')),
        matching: find.byTooltip('Listen to US Citizenship'),
      );
      expect(citizenshipTileSpeaker, findsOneWidget);
      await tester.tap(citizenshipTileSpeaker);
      await tester.pumpAndSettle();

      expect(fakeAudio.spoken.any((s) => s.contains('US Citizenship')), isTrue);

      // Tap card body itself to trigger navigation callback
      await tester.tap(find.byKey(const Key('picture-tile-tile_citizenship')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('Phase 5: Spoken Pre-Permissions & 100% Tap-Only Fallback', () {
    testWidgets('PrePermissionAudioDialog speaks prompt and handles tap-only fallback',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      bool tapOnlyChosen = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PrePermissionAudioDialog(
                onAcceptMic: () {},
                onContinueTapOnly: () => tapOnlyChosen = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PostFrameCallback should speak prompt
      expect(fakeAudio.spoken.any((s) => s.contains('microphone')), isTrue);

      // Replay audio via big center speaker
      final replayButton = find.byIcon(Icons.volume_up_rounded);
      expect(replayButton, findsOneWidget);
      await tester.tap(replayButton);
      await tester.pumpAndSettle();
      expect(fakeAudio.spoken.length, greaterThanOrEqualTo(2));

      // Tap-only fallback button exists and can be tapped without mic
      final tapOnlyButton = find.byKey(const Key('pre-permission-tap-only'));
      expect(tapOnlyButton, findsOneWidget);
      await tester.tap(tapOnlyButton);
      await tester.pumpAndSettle();

      expect(tapOnlyChosen, isTrue);
    });

    testWidgets('PrePermissionAudioDialog handles mic accept choice',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      bool micAccepted = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PrePermissionAudioDialog(
                onAcceptMic: () => micAccepted = true,
                onContinueTapOnly: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mic button exists and can be tapped
      final micButton = find.byKey(const Key('pre-permission-enable-mic'));
      expect(micButton, findsOneWidget);
      await tester.tap(micButton);
      await tester.pumpAndSettle();

      expect(micAccepted, isTrue);
    });
  });

  group('Phase 5: PWA Web Audio Autoplay Unlock Banner', () {
    testWidgets('PwaAudioUnlockBanner does not render when pre-reader is disabled',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PwaAudioUnlockBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pwa-audio-unlock-button')), findsNothing);
    });

    testWidgets('PwaAudioUnlockBanner renders when enabled and unlocks audio upon user gesture',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
            preReaderProvider.overrideWith((ref) => PreReaderNotifier(
                  initialProfile: const PreReaderProfile(
                    enabled: true,
                    track: PreReaderTrack.adult,
                    autoSpeakScreens: true,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PwaAudioUnlockBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unlockButton = find.byKey(const Key('pwa-audio-unlock-button'));
      expect(unlockButton, findsOneWidget);

      await tester.tap(unlockButton);
      await tester.pumpAndSettle();

      // Banner should disappear after unlocking
      expect(find.byKey(const Key('pwa-audio-unlock-button')), findsNothing);
      expect(fakeAudio.spoken, contains('enabled_defaults'));
      expect(fakeAudio.spoken.any((s) => s.contains('Voice guidance is now active')), isTrue);
    });
  });

  group('Phase 5: Audio Help Button & Continue Card Audio Readout', () {
    testWidgets('HelpCenterSheet includes audio guide button that pronounces help instructions',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HelpCenterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final helpAudioBtn = find.byKey(const Key('help-audio-guide'));
      expect(helpAudioBtn, findsOneWidget);

      await tester.tap(helpAudioBtn);
      await tester.pumpAndSettle();

      expect(fakeAudio.spoken.any((s) => s.contains('Need help?')), isTrue);
    });

    testWidgets('ContinueCard displays audio readout button when pre-reader mode is active',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      const testAction = StartActivity(
        activity: LessonActivity(
          lessonId: 'lesson-101',
          title: 'Workplace Safety Basics',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
            preReaderProvider.overrideWith((ref) => PreReaderNotifier(
                  initialProfile: const PreReaderProfile(
                    enabled: true,
                    track: PreReaderTrack.adult,
                    autoSpeakScreens: true,
                  ),
                )),
            learningContextsProvider.overrideWith((ref) => LearningContextsNotifier.stub(
                  const LearningContextsState(
                    contexts: [],
                    isLoading: false,
                  ),
                )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ContinueCard(action: testAction),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final audioReadoutBtn = find.byKey(const Key('learn-action-audio-readout'));
      expect(audioReadoutBtn, findsOneWidget);

      await tester.tap(audioReadoutBtn);
      await tester.pumpAndSettle();

      expect(fakeAudio.spoken.any((s) => s.contains('Workplace Safety Basics')), isTrue);
      expect(fakeAudio.spoken.any((s) => s.contains('Tap Start to begin')), isTrue);
    });
  });
}
