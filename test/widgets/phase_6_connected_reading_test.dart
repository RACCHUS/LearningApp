import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/decodable_story_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/literacy/foundational_literacy_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/widgets/literacy/caseworker_setup_dialog.dart';
import 'package:learning_pwa/widgets/literacy/karaoke_story_reader_widget.dart';
import 'package:learning_pwa/widgets/literacy/oral_diagnostic_widget.dart';

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

  @override
  Future<void> enablePreReaderDefaults({
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {
    spoken.add('enabled_defaults');
  }
}

void main() {
  group('Phase 6: Decodable Story Catalog Models', () {
    test('Stories include Level 1 and Level 2 with StoryWeaver / CC-BY licensing', () {
      expect(officialDecodableStories.isNotEmpty, isTrue);

      final redHen = officialDecodableStories
          .firstWhere((s) => s.id == 'story_red_hen');
      expect(redHen.level, equals(1));
      expect(redHen.attribution, contains('StoryWeaver'));
      expect(redHen.attribution, contains('CC-BY 4.0'));
      expect(redHen.lines.length, greaterThanOrEqualTo(3));
      expect(redHen.lines.first.words.isNotEmpty, isTrue);

      final busStory = officialDecodableStories
          .firstWhere((s) => s.id == 'story_bus_ride');
      expect(busStory.level, equals(2));
      expect(busStory.title, contains('Bus'));
      expect(busStory.lines.any((l) => l.spokenText.contains('bus card')), isTrue);
    });
  });

  group('Phase 6: KaraokeStoryReaderWidget', () {
    testWidgets('Renders story, reads line aloud with highlighting, and pronounces tapped words',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: KaraokeStoryReaderWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'The Red Hen'), findsOneWidget);
      expect(find.text('Line 1 of 4'), findsOneWidget);

      // Tap first word "The" to pronounce individually
      final firstWord = find.byKey(const Key('karaoke-word-0'));
      expect(firstWord, findsOneWidget);
      await tester.tap(firstWord);
      await tester.pumpAndSettle();

      expect(fakeAudio.spoken, contains('The'));

      // Tap "Read Line Aloud" button to trigger synchronized progression
      final playLineBtn = find.byKey(const Key('story-play-line-button'));
      expect(playLineBtn, findsOneWidget);
      await tester.ensureVisible(playLineBtn);
      await tester.tap(playLineBtn);
      await tester.pump();

      expect(fakeAudio.spoken.any((s) => s.contains('The red hen sat')), isTrue);

      // Advance line using Next Line button
      final nextLineBtn = find.byKey(const Key('story-next-line-button'));
      expect(nextLineBtn, findsOneWidget);
      await tester.ensureVisible(nextLineBtn);
      await tester.tap(nextLineBtn);
      await tester.pumpAndSettle();

      expect(find.text('Line 2 of 4'), findsOneWidget);

      // Switch story to City Bus
      final busTab = find.byKey(const Key('story-tab-story_bus_ride'));
      expect(busTab, findsOneWidget);
      await tester.ensureVisible(busTab);
      await tester.tap(busTab);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Taking the City Bus'), findsOneWidget);
    });
  });

  group('Phase 6: Formative Oral Placement Diagnostic', () {
    testWidgets('3-step diagnostic flow scores answers and recommends starting point',
        (tester) async {
      final fakeAudio = _FakePreReaderAudioService();
      bool completeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(fakeAudio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OralDiagnosticWidget(
                onComplete: () => completeCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Letter sound /m/
      expect(find.text('Step 1 of 3: Letter Sound /m/'), findsOneWidget);
      expect(fakeAudio.spoken.any((s) => s.contains('Question 1')), isTrue);

      // Answer Step 1 correctly
      final step1Correct = find.byKey(const Key('diagnostic-choice-step-0'));
      expect(step1Correct, findsOneWidget);
      await tester.tap(step1Correct);
      await tester.pumpAndSettle();

      // Step 2: STOP sign
      expect(find.text('Step 2 of 3: Safety Sign STOP'), findsOneWidget);
      expect(fakeAudio.spoken.any((s) => s.contains('Question 2')), isTrue);

      // Answer Step 2 correctly
      final step2Correct = find.byKey(const Key('diagnostic-choice-step-1'));
      expect(step2Correct, findsOneWidget);
      await tester.tap(step2Correct);
      await tester.pumpAndSettle();

      // Step 3: Decodable word CAT
      expect(find.text('Step 3 of 3: Decodable Word CAT'), findsOneWidget);
      expect(fakeAudio.spoken.any((s) => s.contains('Question 3')), isTrue);

      // Answer Step 3 correctly
      final step3Correct = find.byKey(const Key('diagnostic-choice-step-2'));
      expect(step3Correct, findsOneWidget);
      await tester.tap(step3Correct);
      await tester.pumpAndSettle();

      // Results view
      expect(find.text('Diagnostic Placement Complete'), findsOneWidget);
      expect(find.text('Score: 3 out of 3 questions'), findsOneWidget);
      expect(find.text('High-Stakes Life Milestones'), findsOneWidget);

      final startLessonsBtn = find.byKey(const Key('diagnostic-start-learning-button'));
      expect(startLessonsBtn, findsOneWidget);
      await tester.tap(startLessonsBtn);
      await tester.pumpAndSettle();

      expect(completeCalled, isTrue);
    });
  });

  group('Phase 6: Caseworker / Tutor Setup Dialog for Shared Devices', () {
    testWidgets('PIN protection unlocks tutor controls, track changes, and student session reset',
        (tester) async {
      bool resetCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CaseworkerSetupDialog.show(
                    context,
                    onResetStudentState: () => resetCalled = true,
                  ),
                  child: const Text('Open Setup'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Caseworker / Tutor Setup'), findsOneWidget);

      // Enter incorrect PIN
      await tester.enterText(find.byKey(const Key('caseworker-pin-input')), '9999');
      await tester.tap(find.byKey(const Key('caseworker-unlock-button')));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect PIN. Default tutor PIN is 1234.'), findsOneWidget);

      // Enter correct PIN '1234'
      await tester.enterText(find.byKey(const Key('caseworker-pin-input')), '1234');
      await tester.tap(find.byKey(const Key('caseworker-unlock-button')));
      await tester.pumpAndSettle();

      expect(find.text('Shared Device Settings'), findsOneWidget);
      expect(find.byKey(const Key('caseworker-track-selector')), findsOneWidget);

      // Tap Reset Session for New Student button
      final resetBtn = find.byKey(const Key('caseworker-reset-student-button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(find.text('Session reset! Ready for incoming student.'), findsOneWidget);
    });
  });

  group('Phase 6: Hub Integration in FoundationalLiteracyScreen', () {
    testWidgets('FoundationalLiteracyScreen switches to Stories and Diagnostic tabs and opens caseworker modal',
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

      // Navigate to Stories tab
      final storiesChip = find.widgetWithText(ChoiceChip, '📖 Stories');
      expect(storiesChip, findsOneWidget);
      await tester.ensureVisible(storiesChip);
      await tester.tap(storiesChip);
      await tester.pumpAndSettle();

      expect(find.byType(KaraokeStoryReaderWidget), findsOneWidget);
      expect(fakeAudio.spoken.any((s) => s.contains('Connected Stories')), isTrue);

      // Navigate to Placement Check tab
      final diagChip = find.widgetWithText(ChoiceChip, '🎯 Placement Check');
      expect(diagChip, findsOneWidget);
      await tester.ensureVisible(diagChip);
      await tester.tap(diagChip);
      await tester.pumpAndSettle();

      expect(find.byType(OralDiagnosticWidget), findsOneWidget);
      expect(fakeAudio.spoken.any((s) => s.contains('Placement Check')), isTrue);

      // Tap caseworker action button in AppBar
      final caseworkerBtn = find.byKey(const Key('literacy-caseworker-btn'));
      expect(caseworkerBtn, findsOneWidget);
      await tester.tap(caseworkerBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CaseworkerSetupDialog), findsOneWidget);
    });
  });
}
