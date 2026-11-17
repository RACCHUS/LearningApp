import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/generation_session.dart';
import 'package:learning_pwa/widgets/lesson/guided_generation_complete_view.dart';

/// The "complete" step of guided generation, extracted from
/// GuidedGenerationScreen. The screen owns the import; this view calls
/// onImport with the assembled lesson JSON.
void main() {
  GenerationSession session() => GenerationSession(
        id: 's1',
        createdAt: DateTime(2026, 11, 17),
        subject: 'Photosynthesis',
        targetAudience: 'beginner',
        durationMinutes: 20,
        difficulty: 'beginner',
        contentFocus: 'balanced',
        lessonPlan: const {'title': 'Photosynthesis basics'},
        terms: const [
          {'term': 'Chlorophyll', 'definition': 'Green pigment that absorbs light.'},
        ],
        currentPhase: GenerationPhase.complete,
      );

  Future<void> pump(WidgetTester tester,
      {required bool importing, required List<String> imported}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GuidedGenerationCompleteView(
            session: session(),
            isImporting: importing,
            onImport: (json) async => imported.add(json),
          ),
        ),
      ),
    ));
    // The importing state shows an endless spinner, so do not settle.
    await tester.pump();
  }

  testWidgets('imports the assembled lesson JSON', (tester) async {
    final imported = <String>[];
    await pump(tester, importing: false, imported: imported);
    final button = find.widgetWithText(FilledButton, 'Import Lesson');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(imported, hasLength(1));
    final lesson = jsonDecode(imported.single);
    expect(jsonEncode(lesson), contains('Chlorophyll'));
  });

  testWidgets('the button is disabled while importing', (tester) async {
    final imported = <String>[];
    await pump(tester, importing: true, imported: imported);
    final button = find.widgetWithText(FilledButton, 'Importing…');
    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });
}
