import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/data/help_topics.dart';
import 'package:learning_pwa/data/help_visual_guides.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingHelpSpeech extends PreReaderAudioService {
  final List<String> lines = <String>[];

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    lines.add(text);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('every help topic has an offline picture and spoken guidance', () {
    for (final topic in helpTopics) {
      final guide = helpVisualGuideFor(topic);
      expect(guide.steps, isNotEmpty, reason: topic.id);
      expect(guide.narration.trim(), isNotEmpty, reason: topic.id);
      for (final step in guide.steps) {
        expect(step.label.trim(), isNotEmpty, reason: topic.id);
        expect(step.spokenInstruction.trim(), isNotEmpty, reason: topic.id);
      }
    }
  });

  testWidgets('pictures work before typing and Listen does not navigate',
      (tester) async {
    final speech = _RecordingHelpSpeech();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preReaderAudioServiceProvider.overrideWithValue(speech),
        ],
        child: const MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [HelpAction()],
            ),
            body: Center(child: Text('LEARN PAGE')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('help-visual-directory')), findsOneWidget);
    expect(find.byKey(const Key('help-search')), findsOneWidget);
    expect(speech.lines, isEmpty);

    await tester.tap(find.byKey(const Key('help-picture-listen-find-learning')));
    await tester.pumpAndSettle();

    expect(speech.lines.last, contains('First, open Library'));
    expect(
      find.byKey(const Key('help-topic-view-find-learning')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('help-picture-open-find-learning')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('help-topic-view-find-learning')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('help-topic-listen')), findsOneWidget);
    expect(speech.lines.length, 1,
        reason: 'Regular readers should not hear automatic narration.');

    await tester.tap(find.byKey(const Key('help-topic-listen')));
    await tester.pumpAndSettle();
    expect(speech.lines.last, contains('Then select the available'));

    await tester.tap(find.byKey(const Key('help-topic-step-listen-1')));
    await tester.pumpAndSettle();
    expect(speech.lines.last, contains('Next, choose'));

    await tester.tap(find.byKey(const Key('help-topic-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-visual-directory')), findsOneWidget);

    await tester.tap(find.byKey(const Key('help-picture-mode-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('help-category-results')), findsOneWidget);

    await tester.tap(find.byKey(const Key('help-close')));
    await tester.pumpAndSettle();
    expect(find.text('LEARN PAGE'), findsOneWidget);
  });

  testWidgets('typing a search immediately opens the original written index',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [HelpAction()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Help'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('help-search')), 'timer');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('help-search-results')), findsOneWidget);
    expect(find.text('Study timer & breaks'), findsOneWidget);
    expect(find.byKey(const Key('help-visual-directory')), findsNothing);
  });
}
