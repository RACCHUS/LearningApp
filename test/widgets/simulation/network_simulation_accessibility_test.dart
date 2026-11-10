import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/l10n/app_localizations.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';

class _FakeAudioService extends PreReaderAudioService {
  final spoken = <String>[];
  int stopCount = 0;

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

void _expectSingleHelpButton(WidgetTester tester, String label) {
  final help = tester.getSemantics(find.byKey(const Key('help-action')));
  expect(
    help,
    isSemantics(label: label, tooltip: '', isButton: true, hasTapAction: true),
  );
  var parent = help.parent;
  while (parent != null) {
    expect(
      parent.flagsCollection.isButton && parent.label == label,
      isFalse,
      reason: 'Help must not have a duplicate ancestor button',
    );
    parent = parent.parent;
  }
}

void main() {
  testWidgets('Help has one labelled, actionable button in a simulation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preReaderAudioServiceProvider.overrideWithValue(
              _FakeAudioService(),
            ),
          ],
          child: const MaterialApp(
            home: SimulationScreen(
              simulationId: 'networking-basics',
              version: '1.0.0',
              previewEnabled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectSingleHelpButton(tester, 'Help');
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Help retains its localized accessible name', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: HelpAction()),
        ),
      );
      await tester.pumpAndSettle();
      _expectSingleHelpButton(tester, 'Ayuda');
    } finally {
      handle.dispose();
    }
  });

  testWidgets('network practice reflows with enlarged text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preReaderAudioServiceProvider.overrideWithValue(_FakeAudioService()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SimulationScreen(
            simulationId: 'networking-basics',
            version: '1.0.0',
            previewEnabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.renderObject<RenderParagraph>(
      find.text('Network troubleshooting practice'),
    );
    expect(title.didExceedMaxLines, isFalse);
    expect(
      title.size.height,
      greaterThanOrEqualTo(title.getMaxIntrinsicHeight(title.size.width) - 0.5),
    );
    for (final choice in [
      'Between the router and the laptop',
      'Reconnect the Ethernet cable between router and laptop',
      'The cable carries network traffic from the router to the laptop.',
    ]) {
      await tester.ensureVisible(find.text(choice));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(choice));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
        ),
        reason: '$choice must not be clipped at 200 percent text',
      );
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Review the scenario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review the scenario'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('The router is online, but the Ethernet link'),
      findsOneWidget,
    );
  });

  testWidgets('disabled simulation title remains readable at 200 percent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SimulationScreen(
            simulationId: 'networking-basics',
            version: '1.0.0',
            previewEnabled: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.renderObject<RenderParagraph>(
      find.text('Network troubleshooting practice'),
    );
    expect(title.didExceedMaxLines, isFalse);
    expect(
      title.size.height,
      greaterThanOrEqualTo(title.getMaxIntrinsicHeight(title.size.width) - 0.5),
    );
    expect(find.text('Return to lesson'), findsOneWidget);
    expect(find.byTooltip('Help'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('network narration can be muted and stopped', (tester) async {
    final audio = _FakeAudioService();
    final handle = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [preReaderAudioServiceProvider.overrideWithValue(audio)],
          child: const MaterialApp(
            home: SimulationScreen(
              simulationId: 'networking-basics',
              version: '1.0.0',
              previewEnabled: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speak hints and explanations'));
      await tester.pumpAndSettle();
      expect(audio.stopCount, 1);

      await tester.ensureVisible(find.text('Get a hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get a hint'));
      await tester.pumpAndSettle();
      expect(audio.spoken, isEmpty);
      expect(
        tester.getSemantics(
          find.textContaining('Follow the connection from the router'),
        ),
        isSemantics(
          label:
              'Follow the connection from the router to the laptop. '
              'A screen or password cannot repair a loose cable.',
          isLiveRegion: true,
        ),
      );

      for (final choice in [
        'Between the router and the laptop',
        'Reconnect the Ethernet cable between router and laptop',
        'The cable carries network traffic from the router to the laptop.',
      ]) {
        await tester.ensureVisible(find.text(choice));
        await tester.pumpAndSettle();
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Review the scenario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review the scenario'));
      await tester.pumpAndSettle();
      expect(audio.spoken, isEmpty);

      await tester.ensureVisible(find.text('Speak hints and explanations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speak hints and explanations'));
      await tester.ensureVisible(find.text('Review the scenario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review the scenario'));
      await tester.pumpAndSettle();
      expect(audio.spoken, hasLength(1));
      await tester.ensureVisible(find.text('Stop narration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop narration'));
      await tester.pump();
      expect(audio.stopCount, 2);
    } finally {
      handle.dispose();
    }
  });
}
