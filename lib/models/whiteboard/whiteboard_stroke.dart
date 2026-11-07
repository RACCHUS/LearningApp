import 'package:flutter/material.dart';

enum WhiteboardTool {
  pen,
  highlighter,
  eraser;

  String get label {
    switch (this) {
      case WhiteboardTool.pen:
        return 'Pen';
      case WhiteboardTool.highlighter:
        return 'Highlighter';
      case WhiteboardTool.eraser:
        return 'Eraser';
    }
  }

  IconData get icon {
    switch (this) {
      case WhiteboardTool.pen:
        return Icons.edit;
      case WhiteboardTool.highlighter:
        return Icons.highlight;
      case WhiteboardTool.eraser:
        return Icons.auto_fix_normal;
    }
  }
}

/// A 2D point on the whiteboard canvas.
class WhiteboardPoint {
  final double x;
  final double y;

  const WhiteboardPoint(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  factory WhiteboardPoint.fromOffset(Offset offset) =>
      WhiteboardPoint(offset.dx, offset.dy);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory WhiteboardPoint.fromJson(Map<String, dynamic> json) =>
      WhiteboardPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );
}

/// A continuous vector stroke on the whiteboard canvas (P8-2).
class WhiteboardStroke {
  final WhiteboardTool tool;
  final int colorValue;
  final double strokeWidth;
  final List<WhiteboardPoint> points;

  const WhiteboardStroke({
    required this.tool,
    required this.colorValue,
    required this.strokeWidth,
    required this.points,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color_value': colorValue,
        'stroke_width': strokeWidth,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) =>
      WhiteboardStroke(
        tool: WhiteboardTool.values.firstWhere(
          (t) => t.name == json['tool'],
          orElse: () => WhiteboardTool.pen,
        ),
        colorValue: json['color_value'] as int? ?? 0xFF000000,
        strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 3.0,
        points: (json['points'] as List<dynamic>?)
                ?.map((p) => WhiteboardPoint.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

