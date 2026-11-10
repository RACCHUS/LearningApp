import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_entry_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSpeech extends PreReaderAudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text, {
    PreReaderTrack track = PreReaderTrack.adult,
    double? customRate,
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> enablePreReaderDefaults({
    PreReaderTrack track = PreReaderTrack.adult,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('only the explicit picture button opens the non-reader setup',
      (tester) async {
    final audio = _RecordingSpeech();
    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Regular home section'),
                  TextButton(
                    key: const Key('regular-library-link'),
                    onPressed: () => context.go('/library'),
                    child: const Text('Library'),
                  ),
                  const PreReaderEntryBanner(),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Library destination'))),
        ),
        GoRoute(
          path: '/literacy',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Literacy destination'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [preReaderAudioServiceProvider.overrideWithValue(audio)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('pre-reader-entry-card'));
    final corner = tester.getTopLeft(entry) + const Offset(5, 5);
    await tester.tapAt(corner); // Background is not a navigation target.
    await tester.pumpAndSettle();
    expect(find.text('Regular home section'), findsOneWidget);
    expect(find.text('Choose Your Learning Path'), findsNothing);

    await tester.tap(find.byKey(const Key('pre-reader-listen-button')));
    await tester.pumpAndSettle();
    expect(find.text('Regular home section'), findsOneWidget);
    expect(find.text('Choose Your Learning Path'), findsNothing);
    expect(audio.spoken.last, contains('First tap'));
    expect(audio.spoken.last, contains('Adult or Kids'));

    await tester.tap(find.byKey(const Key('pre-reader-open-button')));
    await tester.pumpAndSettle();
    expect(find.text('Choose Your Learning Path'), findsOneWidget);

    final start = tester.widget<FilledButton>(
      find.byKey(const Key('pre-reader-start-btn')),
    );
    expect(start.onPressed, isNull); // Must choose Adult or Kids explicitly.

    await tester.tap(find.byKey(const Key('pre-reader-youth-card')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('pre-reader-start-btn')),
      ).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('pre-reader-start-btn')));
    await tester.pumpAndSettle();
    expect(find.text('Literacy destination'), findsOneWidget);
  });

  testWidgets('regular homepage navigation does not open literacy',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const Key('library-action'),
                  onPressed: () => context.go('/library'),
                  child: const Text('Explore library'),
                ),
                const PreReaderEntryBanner(),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) =>
              const Scaffold(body: Text('Library destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-action')));
    await tester.pumpAndSettle();
    expect(find.text('Library destination'), findsOneWidget);
  });
}
