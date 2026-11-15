import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/scratchpad_provider.dart';
import 'package:learning_pwa/widgets/whiteboard/question_scratchpad.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in scratchpad under questions (learning.scratchpad). UI spec §5.6:
/// the study screen must be unchanged unless the learner asked for it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    required bool featureOn,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scratchpadFeatureEnabledProvider.overrideWithValue(featureOn),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            key: const Key('page-scroll'),
            child: Column(
              children: [
                const SizedBox(height: 300, child: Text('Question text')),
                const QuestionScratchpad(),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  const optedIn = {ScratchpadPreferenceNotifier.storageKey: true};

  testWidgets('gate OFF: nothing renders even if the learner opted in',
      (tester) async {
    await pump(tester, featureOn: false, prefs: optedIn);
    expect(find.text('Scratchpad'), findsNothing);
  });

  testWidgets('gate ON but not opted in: nothing renders', (tester) async {
    await pump(tester, featureOn: true);
    expect(find.text('Scratchpad'), findsNothing);
  });

  testWidgets('opted in: a collapsed section, no canvas until opened',
      (tester) async {
    await pump(tester, featureOn: true, prefs: optedIn);
    expect(find.text('Scratchpad'), findsOneWidget);
    expect(find.text('For working things out. Not saved.'), findsOneWidget);
    expect(find.byKey(const Key('whiteboard-canvas')), findsNothing);

    await tester.tap(find.text('Scratchpad'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('whiteboard-canvas')), findsOneWidget);
    expect(find.byKey(const Key('save_whiteboard_button')), findsNothing,
        reason: 'temporary pad: no save or reload');
  });

  testWidgets('a vertical stroke draws instead of scrolling the page',
      (tester) async {
    await pump(tester, featureOn: true, prefs: optedIn);
    await tester.tap(find.text('Scratchpad'));
    await tester.pumpAndSettle();

    final scroll = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const Key('page-scroll')),
        matching: find.byType(Scrollable)));
    final before = scroll.position.pixels;
    final undo = find.widgetWithIcon(IconButton, Icons.undo);
    expect(tester.widget<IconButton>(undo).onPressed, isNull);

    final canvas = find.byKey(const Key('whiteboard-canvas'));
    final gesture =
        await tester.startGesture(tester.getCenter(canvas), kind: PointerDeviceKind.touch);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(scroll.position.pixels, before, reason: 'page did not scroll');
    expect(tester.widget<IconButton>(undo).onPressed, isNotNull,
        reason: 'a stroke was drawn');
  });

  testWidgets('the opt-in is remembered on this device', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(scratchpadPreferenceProvider.notifier).set(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ScratchpadPreferenceNotifier.storageKey), isTrue);
  });
}
