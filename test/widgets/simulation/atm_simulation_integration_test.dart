import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/currency_survival_item.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';
import 'package:learning_pwa/widgets/literacy/currency_atm_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioService extends PreReaderAudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    spoken.add(text);
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
