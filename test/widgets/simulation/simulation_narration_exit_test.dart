import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/screens/simulation/simulation_screen.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';

class _RecordingAudio extends PreReaderAudioService {
  final spoken = <String>[];
  final events = <String>[];
  String? currentSpeech;
  int stopCount = 0;

  @override
  Future<void> speak(
    String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    spoken.add(text);
    currentSpeech = text;
    events.add('speak:$text');
  }

  @override
  Future<void> stop() async {
    stopCount++;
    currentSpeech = null;
    events.add('stop');
  }
}

class _NarratingDestination extends ConsumerStatefulWidget {
  const _NarratingDestination();

  @override
  ConsumerState<_NarratingDestination> createState() =>
      _NarratingDestinationState();
}

class _NarratingDestinationState extends ConsumerState<_NarratingDestination> {
  @override
  void initState() {
    super.initState();
    ref.read(preReaderAudioServiceProvider).speak('Destination narration');
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Learn'));
}

GoRouter _router(String initialLocation, {bool narrateLearn = false}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => narrateLearn
              ? const _NarratingDestination()
              : const Scaffold(body: Text('Learn')),
        ),
        GoRoute(
          path: '/lesson',
          builder: (context, state) => const Scaffold(body: Text('Lesson')),
        ),
        GoRoute(
          path: '/simulation/:simulationId/:version',
          builder: (context, state) => SimulationScreen(
            simulationId: state.pathParameters['simulationId']!,
            version: state.pathParameters['version']!,
            previewEnabled: true,
          ),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  GoRouter router,
  _RecordingAudio audio,
) async {
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(1000, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preReaderAudioServiceProvider.overrideWithValue(audio)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exiting an ATM preview stops narration before Learn', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final router = _router('/simulation/atm-withdrawal/1.0.0');
    await _pump(tester, router, audio);
    expect(audio.spoken, isNotEmpty);

    await tester.tap(find.byKey(const Key('exit-simulation')));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(audio.stopCount, 1);
  });

  testWidgets('back navigation stops narration before the lesson', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final router = _router('/lesson');
    await _pump(tester, router, audio);
    router.push('/simulation/atm-withdrawal/1.0.0');
    await tester.pumpAndSettle();
    expect(audio.spoken, isNotEmpty);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Lesson'), findsOneWidget);
    expect(audio.stopCount, 1);
  });

  testWidgets('route replacement stops narration before Learn', (tester) async {
    final audio = _RecordingAudio();
    final router = _router('/simulation/atm-withdrawal/1.0.0');
    await _pump(tester, router, audio);
    expect(audio.spoken, isNotEmpty);

    router.go('/learn');
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(audio.stopCount, 1);
  });

  testWidgets('route replacement preserves new destination narration', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final router = _router(
      '/simulation/atm-withdrawal/1.0.0',
      narrateLearn: true,
    );
    await _pump(tester, router, audio);

    router.go('/learn');
    await tester.pumpAndSettle();

    expect(find.text('Learn'), findsOneWidget);
    expect(audio.events, contains('speak:Destination narration'));
    expect(
      audio.events.indexOf('stop'),
      lessThan(audio.events.indexOf('speak:Destination narration')),
    );
    expect(audio.stopCount, 1);
    expect(audio.currentSpeech, 'Destination narration');
  });

  testWidgets('returning to a covered simulation rearms narration cleanup', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final router = _router('/simulation/atm-withdrawal/1.0.0');
    await _pump(tester, router, audio);

    router.push('/lesson');
    await tester.pumpAndSettle();
    expect(audio.stopCount, 1);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hear step guidance'));
    await tester.pumpAndSettle();
    expect(audio.currentSpeech, isNotNull);

    await tester.tap(find.byKey(const Key('exit-simulation')));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(audio.stopCount, 2);
    expect(audio.currentSpeech, isNull);
  });

  testWidgets('finishing networking practice stops its narration', (
    tester,
  ) async {
    final audio = _RecordingAudio();
    final router = _router('/simulation/networking-basics/1.0.0');
    await _pump(tester, router, audio);

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
    expect(audio.spoken, hasLength(1));

    await tester.ensureVisible(find.text('Finish practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish practice'));
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsOneWidget);
    expect(audio.stopCount, 1);
  });
}
