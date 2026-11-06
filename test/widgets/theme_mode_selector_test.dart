import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/settings/theme_mode_selector.dart';

void main() {
  Widget host(ThemeMode mode, ValueChanged<ThemeMode> onChanged,
          {double scale = 1}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ThemeModeSelector(value: mode, onChanged: onChanged),
            ),
          ),
        ),
      );

  testWidgets('offers Light, Dark and System and reports the choice',
      (tester) async {
    ThemeMode? chosen;
    await tester.pumpWidget(host(ThemeMode.dark, (m) => chosen = m));
    for (final label in ['Light', 'Dark', 'System']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('System'));
    expect(chosen, ThemeMode.system);
  });

  testWidgets('fits a 320px phone at 200% text size', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(ThemeMode.light, (_) {}, scale: 2));
    expect(tester.takeException(), isNull);
  });
}
