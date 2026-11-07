import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/whiteboard/whiteboard_stroke.dart';
import 'package:learning_pwa/services/whiteboard/whiteboard_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhiteboardStorageService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadStrokes returns empty list on initial load', () async {
      final service = WhiteboardStorageService();
      final strokes = await service.loadStrokes();
      expect(strokes, isEmpty);
    });

    test('saveStrokes and loadStrokes persists whiteboard strokes', () async {
      final service = WhiteboardStorageService();
      final strokes = [
        const WhiteboardStroke(
          tool: WhiteboardTool.pen,
          colorValue: 0xFF000000,
          strokeWidth: 4.0,
          points: [
            WhiteboardPoint(10, 10),
            WhiteboardPoint(20, 20),
          ],
        ),
      ];

      await service.saveStrokes(strokes);
      final loaded = await service.loadStrokes();

      expect(loaded.length, equals(1));
      expect(loaded.first.points.length, equals(2));
      expect(loaded.first.tool, equals(WhiteboardTool.pen));
    });

    test('saveStrokes with pngBytes persists PNG snapshot', () async {
      final service = WhiteboardStorageService();
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);

      await service.saveStrokes([], pngBytes: testBytes);
      final loadedBytes = await service.loadSavedPng();

      expect(loadedBytes, isNotNull);
      expect(loadedBytes, equals(testBytes));
    });

    test('clearBoard wipes stored strokes and snapshot', () async {
      final service = WhiteboardStorageService();
      await service.saveStrokes([
        const WhiteboardStroke(
          tool: WhiteboardTool.pen,
          colorValue: 0,
          strokeWidth: 2,
          points: [],
        ),
      ], pngBytes: Uint8List.fromList([1, 2]));

      await service.clearWhiteboard();
      expect(await service.loadStrokes(), isEmpty);
      expect(await service.loadSavedPng(), isNull);
    });
  });
}
