import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/ai/byok_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Disabled BYOK shows no credential editor and permits local erase',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'learningapp_byok_config':
          '{"provider":"openai","apiKey":"previous-test-key","model":"gpt-4o-mini"}',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => ElevatedButton(
          onPressed: () => ByokSettingsDialog.show(context),
          child: const Text('Open settings'),
        )),
      ),
    ));

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('byok-unavailable-dialog')), findsOneWidget);
    expect(find.text('Save & Apply'), findsNothing);
    expect(find.text('Test Connection'), findsNothing);
    expect(find.text('previous-test-key'), findsNothing);
    expect(prefs.getString('learningapp_byok_config'), isNotNull);

    await tester.tap(find.text('Clear saved local key'));
    await tester.pumpAndSettle();
    expect(prefs.getString('learningapp_byok_config'), isNull);
  });
}
