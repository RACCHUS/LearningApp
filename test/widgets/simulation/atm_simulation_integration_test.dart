import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/currency_survival_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/theme/contrast.dart';
import 'package:learning_pwa/widgets/literacy/currency_atm_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioService extends PreReaderAudioService {
  final List<String> spoken = [];
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

Future<void> _pumpAtmPreview(
  WidgetTester tester,
  _FakeAudioService audio, {
  ThemeData? theme,
  Size size = const Size(1000, 1400),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preReaderAudioServiceProvider.overrideWithValue(audio)],
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SimulationScreen(
          simulationId: 'atm-withdrawal',
          version: '1.0.0',
          previewEnabled: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _advanceAtm(WidgetTester tester, int count) async {
  for (var index = 0; index < count; index++) {
    final next = find.text('Next ATM Action');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('atm-withdrawal activity opens directly in the ATM simulator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preReaderAudioServiceProvider.overrideWithValue(_FakeAudioService()),
        ],
        child: const MaterialApp(
          home: SimulationScreen(
            simulationId: 'atm-withdrawal',
            version: '1.0.0',
            previewEnabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next ATM Action'), findsOneWidget);
  });

  testWidgets('ATM amounts reflow at 320 pixels and 200 percent text', (
    tester,
  ) async {
    await _pumpAtmPreview(
      tester,
      _FakeAudioService(),
      size: const Size(320, 800),
      textScale: 2,
    );
    await _advanceAtm(tester, 3);
    final amount = find.widgetWithText(RadioListTile<int>, '\$100');
    await tester.ensureVisible(amount);
    await tester.pumpAndSettle();
    await tester.tap(amount);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final text in [
      'ATM withdrawal practice',
      '18 U.S.C. § 504 Currency Compliance',
      '\$100',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
        ),
        reason: '$text must not be clipped at 200 percent text',
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$text must not be ellipsized at 200 percent text',
      );
    }
  });

  testWidgets('currency denominations reflow with enlarged text', (
    tester,
  ) async {
    await _pumpAtmPreview(
      tester,
      _FakeAudioService(),
      size: const Size(320, 800),
      textScale: 2,
    );
    final coins = find.text('💵 Coins & Paper Bills');
    await tester.ensureVisible(coins);
    await tester.pumpAndSettle();
    await tester.tap(coins);
    await tester.pumpAndSettle();

    for (final label in ['🪙 25¢ / \$0.25', '💵 \$100']) {
      final choice = find.text(label);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(choice);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.5,
        ),
        reason: '$label must not be clipped at 200 percent text',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency values have sufficient contrast in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.lightTheme(), AppTheme.darkTheme()]) {
      await _pumpAtmPreview(tester, _FakeAudioService(), theme: theme);
      final cardBackground =
          theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;

      await tester.tap(find.text('💵 Coins & Paper Bills'));
      await tester.pumpAndSettle();
      final denomination = tester.widget<Text>(
        find.text(officialCurrencyCatalog.first.displayValue).last,
      );
      expect(
        contrastRatio(denomination.style!.color!, cardBackground),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.brightness} denomination contrast',
      );

      await tester.tap(find.text('🧾 Verify Change Practice'));
      await tester.pumpAndSettle();
      final change = tester.widget<Text>(
        find.text('Your Correct Change: \$6.00'),
      );
      final changeBackground = Color.alphaBlend(
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        cardBackground,
      );
      expect(
        contrastRatio(change.style!.color!, changeBackground),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.brightness} change amount contrast',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('CurrencyAtmWidget keeps coins and bills as its default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preReaderAudioServiceProvider.overrideWithValue(_FakeAudioService()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CurrencyAtmWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next ATM Action'), findsNothing);
    expect(find.text('Automatic narration'), findsNothing);
  });

  testWidgets('currency activity sections are exclusive keyboard radios', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpAtmPreview(tester, _FakeAudioService());
      final atm = find.widgetWithText(
        RadioListTile<CurrencyActivitySection>,
        '🏧 ATM Cash Simulator',
      );
      final coins = find.widgetWithText(
        RadioListTile<CurrencyActivitySection>,
        '💵 Coins & Paper Bills',
      );
      expect(
        tester.getSemantics(atm),
        isSemantics(
          label: '🏧 ATM Cash Simulator',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      final focusNode = tester
          .widget<ListTile>(
            find.descendant(of: atm, matching: find.byType(ListTile)),
          )
          .focusNode!;
      for (var index = 0; index < 30 && !focusNode.hasFocus; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(coins),
        isSemantics(
          label: '💵 Coins & Paper Bills',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(find.text('Next ATM Action'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Next ATM Action'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('currency denominations are exclusive keyboard radios', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpAtmPreview(tester, _FakeAudioService());
      await tester.tap(find.text('💵 Coins & Paper Bills'));
      await tester.pumpAndSettle();

      final penny = find.widgetWithText(RadioListTile<int>, '🪙 1¢ / \$0.01');
      final nickel = find.widgetWithText(RadioListTile<int>, '🪙 5¢ / \$0.05');
      expect(find.bySemanticsLabel('Currency denomination'), findsOneWidget);
      expect(
        tester.getSemantics(penny),
        isSemantics(
          label: '🪙 1¢ / \$0.01',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      expect(
        tester.getSemantics(nickel),
        isSemantics(
          label: '🪙 5¢ / \$0.05',
          hasCheckedState: true,
          isChecked: false,
          isInMutuallyExclusiveGroup: true,
        ),
      );

      final focusNode = tester
          .widget<ListTile>(
            find.descendant(of: penny, matching: find.byType(ListTile)),
          )
          .focusNode!;
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(nickel),
        isSemantics(
          label: '🪙 5¢ / \$0.05',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('ATM step and PIN progress have live, non-sensitive semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpAtmPreview(tester, _FakeAudioService());
      await _advanceAtm(tester, 1);

      expect(
        tester.getSemantics(find.text('Enter 4-Digit PIN')),
        isSemantics(
          label:
              'Step 2 of 6. Enter 4-Digit PIN. '
              'Type your 4-digit secret PIN on the keypad. '
              'Cover your hand while typing.',
          isLiveRegion: true,
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Type your 4-digit secret PIN')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(
          find.text(
            'Security: Never share your PIN with anyone, not even someone '
            'offering to help.',
          ),
        ),
        isSemantics(
          label:
              'Security: Never share your PIN with anyone, not even someone '
              'offering to help.',
        ),
      );

      void expectProgress(int count) {
        final label = '$count of 4 practice PIN digits entered';
        expect(
          tester.getSemantics(find.text(label)),
          isSemantics(label: label, isLiveRegion: true),
        );
      }

      expectProgress(0);
      for (final digit in ['1', '2']) {
        await tester.tap(find.widgetWithText(ElevatedButton, digit));
        await tester.pump();
      }
      expectProgress(2);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear'));
      await tester.pump();
      expectProgress(0);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('ATM amounts are exclusive, keyboard-operable radios', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      for (final scheme in [
        AppTheme.lightTheme().colorScheme,
        AppTheme.darkTheme().colorScheme,
      ]) {
        await _pumpAtmPreview(
          tester,
          _FakeAudioService(),
          theme: ThemeData(colorScheme: scheme),
        );
        await _advanceAtm(tester, 3);
        final forty = find.widgetWithText(RadioListTile<int>, '\$40');
        final sixty = find.widgetWithText(RadioListTile<int>, '\$60');

        void expectChecked(Finder choice, String label, bool checked) {
          expect(
            tester.getSemantics(choice),
            isSemantics(
              label: label,
              hasCheckedState: true,
              isChecked: checked,
              isInMutuallyExclusiveGroup: true,
            ),
          );
        }

        expectChecked(forty, '\$40', false);
        expectChecked(sixty, '\$60', false);
        await tester.tap(forty);
        await tester.pumpAndSettle();
        expectChecked(forty, '\$40', true);
        expectChecked(sixty, '\$60', false);
        final focusNode = tester
            .widget<ListTile>(
              find.descendant(of: forty, matching: find.byType(ListTile)),
            )
            .focusNode!;
        for (var index = 0; index < 30 && !focusNode.hasFocus; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expectChecked(forty, '\$40', false);
        expectChecked(sixty, '\$60', true);

        final title = tester.widget<Text>(find.text('\$60'));
        expect(
          contrastRatio(title.style!.color!, Colors.blueGrey.shade900),
          greaterThanOrEqualTo(4.5),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets('ATM compliance notice does not label the activity controls', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpAtmPreview(tester, _FakeAudioService());
      final notice = tester.getSemantics(
        find.text('18 U.S.C. § 504 Currency Compliance'),
      );
      expect(notice.label, contains('18 U.S.C. § 504 Currency Compliance'));
      var control = tester.getSemantics(find.text('Automatic narration'));
      while (control.parent != null) {
        expect(control.label, isNot(contains('Currency Compliance')));
        control = control.parent!;
      }
    } finally {
      handle.dispose();
    }
  });

  testWidgets(
    'ATM narration can be stopped without disabling manual guidance',
    (tester) async {
      final audio = _FakeAudioService();
      await _pumpAtmPreview(tester, audio);
      expect(audio.spoken, isNotEmpty);

      await tester.tap(find.text('Automatic narration'));
      await tester.pumpAndSettle();
      expect(audio.stopCount, 1);
      final spokenBefore = audio.spoken.length;
      await _advanceAtm(tester, 1);
      expect(audio.spoken.length, spokenBefore);

      await tester.tap(find.byTooltip('Hear step guidance'));
      await tester.pump();
      expect(audio.spoken.length, spokenBefore + 1);
      await tester.ensureVisible(find.text('Stop narration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop narration'));
      await tester.pump();
      expect(audio.stopCount, 2);
    },
  );

  testWidgets('narration can be stopped in every currency section', (
    tester,
  ) async {
    final audio = _FakeAudioService();
    await _pumpAtmPreview(tester, audio);
    await tester.tap(find.text('Automatic narration'));
    await tester.pumpAndSettle();

    for (final section in [
      '🏧 ATM Cash Simulator',
      '💵 Coins & Paper Bills',
      '🧾 Verify Change Practice',
    ]) {
      final choice = find.text(section);
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(find.text('Stop narration'), findsOneWidget, reason: section);
    }

    final spokenBefore = audio.spoken.length;
    await tester.ensureVisible(find.byTooltip('Read scenario aloud'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Read scenario aloud'));
    await tester.pump();
    expect(audio.spoken.length, spokenBefore + 1);
    await tester.ensureVisible(find.text('Stop narration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop narration'));
    await tester.pump();
    expect(audio.stopCount, 2);
  });

  testWidgets('ATM completion is local, unscored, and emitted at most once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final audio = _FakeAudioService();
    final session = SimulationSession(
      activity: SimulationActivityConfig(id: 'atm-withdrawal', version: '1'),
      enabled: true,
    )..start();

    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [preReaderAudioServiceProvider.overrideWithValue(audio)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CurrencyAtmWidget(
                onAtmCompleted: () => session.complete(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('🏧 ATM Cash Simulator'));
    await tester.pumpAndSettle();

    for (var index = 0; index < officialAtmSteps.length - 1; index++) {
      final next = find.text('Next ATM Action');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();

      if (index == 0) {
        for (final digit in ['1', '2', '3', '4']) {
          await tester.tap(find.widgetWithText(ElevatedButton, digit));
          await tester.pump();
        }
      }
      expect(session.state, SimulationLifecycleState.running);
    }

    final complete = find.text('Complete Withdrawal');
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(session.state, SimulationLifecycleState.completed);
    expect(session.events.map((event) => event.type), [
      SimulationEventType.launched,
      SimulationEventType.completed,
    ]);
    expect(audio.spoken.join(' '), isNot(contains('1234')));
    expect(preferences.getKeys(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(session.events, isEmpty);
    expect(preferences.getKeys(), isEmpty);
  });
}
