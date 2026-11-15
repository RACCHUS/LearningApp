import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/whiteboard/whiteboard_widget.dart';

/// A temporary scratchpad stores nothing, but the learner can keep the
/// drawing as it is now by downloading it as a PNG file.
void main() {
  Future<void> pump(WidgetTester tester,
      Future<bool> Function(Uint8List, String) downloader) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WhiteboardWidget(height: 300, pngDownloader: downloader),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> drawStroke(WidgetTester tester) async {
    final canvas = find.byKey(const Key('whiteboard-canvas'));
    final g = await tester.startGesture(tester.getCenter(canvas),
        kind: PointerDeviceKind.touch);
    await g.moveBy(const Offset(40, 30));
    await g.moveBy(const Offset(40, -10));
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('Download is disabled until something is drawn',
      (tester) async {
    await pump(tester, (_, __) async => true);
    final button = find.byKey(const Key('download_whiteboard_button'));
    expect(button, findsOneWidget);
    expect(find.byKey(const Key('save_whiteboard_button')), findsNothing);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
  });

  testWidgets('downloads the current drawing as a dated PNG file',
      (tester) async {
    Uint8List? bytes;
    String? name;
    await pump(tester, (png, fileName) async {
      bytes = png;
      name = fileName;
      return true;
    });
    await drawStroke(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_whiteboard_button')));
      // Let the real toImage/toByteData capture finish.
      for (var i = 0; i < 20 && bytes == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();

    expect(bytes, isNotNull);
    expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: 'PNG');
    expect(name, matches(RegExp(r'^scratchpad-\d{8}-\d{4}\.png$')));
    expect(find.textContaining('Drawing downloaded'), findsOneWidget);
  });

  testWidgets('a failed download suggests a screenshot', (tester) async {
    await pump(tester, (_, __) async => false);
    await drawStroke(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('download_whiteboard_button')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('take a screenshot'), findsOneWidget);
  });
}
