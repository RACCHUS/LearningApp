import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/whiteboard/whiteboard_stroke.dart';

void main() {
  group('WhiteboardStroke Model Tests', () {
    test('point serialization preserves x and y', () {
      const pt = WhiteboardPoint(12.5, 44.8);
      final json = pt.toJson();
      final restored = WhiteboardPoint.fromJson(json);

      expect(restored.x, equals(12.5));
      expect(restored.y, equals(44.8));
    });

    test('stroke serialization preserves tool, color, width, and points', () {
      const stroke = WhiteboardStroke(
        tool: WhiteboardTool.highlighter,
        colorValue: 0xFFFFEB3B,
        strokeWidth: 16.0,
        points: [
          WhiteboardPoint(0, 0),
          WhiteboardPoint(10, 15),
        ],
      );

      final json = stroke.toJson();
      final restored = WhiteboardStroke.fromJson(json);

      expect(restored.tool, equals(WhiteboardTool.highlighter));
      expect(restored.colorValue, equals(0xFFFFEB3B));
      expect(restored.strokeWidth, equals(16.0));
      expect(restored.points.length, equals(2));
      expect(restored.points.first.x, equals(0));
    });
  });
}
