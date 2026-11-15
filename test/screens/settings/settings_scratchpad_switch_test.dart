import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/scratchpad_provider.dart';
import 'package:learning_pwa/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pump(WidgetTester tester, bool featureOn) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      scratchpadFeatureEnabledProvider.overrideWithValue(featureOn),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('gate OFF hides the scratchpad switch', (tester) async {
    await pump(tester, false);
    expect(find.byKey(const Key('settings-scratchpad')), findsNothing);
  });

  testWidgets('gate ON offers it, off by default, and turning it on sticks',
      (tester) async {
    final container = await pump(tester, true);
    final tile = find.byKey(const Key('settings-scratchpad'));
    expect(tile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(container.read(showQuestionScratchpadProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ScratchpadPreferenceNotifier.storageKey), isTrue);
  });
}
