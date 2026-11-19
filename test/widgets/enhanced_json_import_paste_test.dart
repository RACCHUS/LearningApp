import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/enhanced_json_import_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JSON Import accepts a reply the way AI chats send it (sentence + code
/// fence) and passes the exact lesson object on to the importer.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<List<String>> pasteAndImport(WidgetTester tester, String text) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final imported = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EnhancedJsonImportWidget(onImport: imported.add)),
      ),
    );
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    return imported;
  }

  testWidgets('a fenced reply with commentary is accepted and noted', (
    tester,
  ) async {
    final reply = File(
      'test/fixtures/ai_replies/quick_chatgpt_fenced.txt',
    ).readAsStringSync();
    final imported = await pasteAndImport(tester, reply);
    expect(find.textContaining('Took the lesson JSON out'), findsOneWidget);

    final importButton = find.widgetWithText(FilledButton, 'Import Lesson');
    expect(importButton, findsOneWidget);
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    final sent = jsonDecode(imported.single) as Map<String, dynamic>;
    expect((sent['lesson'] as Map)['title'], 'Excel VLOOKUP Basics');
  });

  testWidgets('a cut-off reply explains itself and cannot be imported', (
    tester,
  ) async {
    final reply = File(
      'test/fixtures/ai_replies/quick_truncated.txt',
    ).readAsStringSync();
    await pasteAndImport(tester, reply);
    expect(find.textContaining('cut off'), findsWidgets);
  });
}
