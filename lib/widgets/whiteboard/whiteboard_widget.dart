import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../models/whiteboard/whiteboard_stroke.dart';
import '../../services/whiteboard/whiteboard_storage_service.dart';

/// Interactive scratchpad whiteboard with freehand drawing, tool selection,
/// undo/redo, and local PNG saving and reload (P8-2).
class WhiteboardWidget extends StatefulWidget {
  final WhiteboardStorageService storageService;
  final double height;
  final Color backgroundColor;

  const WhiteboardWidget({
    super.key,
    required this.storageService,
    this.height = 420.0,
    this.backgroundColor = Colors.white,
  });

  @override
  State<WhiteboardWidget> createState() => _WhiteboardWidgetState();
}

class _WhiteboardWidgetState extends State<WhiteboardWidget> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<WhiteboardStroke> _strokes = [];
  final List<WhiteboardStroke> _redoStack = [];

  WhiteboardTool _activeTool = WhiteboardTool.pen;
  Color _activeColor = Colors.black;
  double _strokeWidth = 3.0;

  List<WhiteboardPoint>? _currentPoints;
  bool _isLoading = false;

  static const List<Color> _palette = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.amber,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialStrokes();
  }

  Future<void> _loadInitialStrokes() async {
    setState(() => _isLoading = true);
    final loaded = await widget.storageService.loadStrokes();
    if (mounted) {
      setState(() {
        _strokes.clear();
        _strokes.addAll(loaded);
        _isLoading = false;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    final localPos = details.localPosition;
    setState(() {
      _currentPoints = [WhiteboardPoint.fromOffset(localPos)];
      _redoStack.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final localPos = details.localPosition;
    setState(() {
      _currentPoints?.add(WhiteboardPoint.fromOffset(localPos));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints != null && _currentPoints!.isNotEmpty) {
      final stroke = WhiteboardStroke(
        tool: _activeTool,
        colorValue: _activeColor.value,
        strokeWidth: _strokeWidth,
        points: List.from(_currentPoints!),
      );
      setState(() {
        _strokes.add(stroke);
        _currentPoints = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes.removeLast());
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStack.removeLast());
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
      _redoStack.clear();
    });
  }

  Future<void> _saveWhiteboard({bool exportPng = true}) async {
    Uint8List? pngBytes;
    if (exportPng) {
      try {
        final boundary = _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          pngBytes = byteData?.buffer.asUint8List();
        }
      } catch (e) {
        debugPrint('Error capturing whiteboard PNG: $e');
      }
    }

    await widget.storageService.saveStrokes(_strokes, pngBytes: pngBytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Whiteboard saved locally! Vector strokes and PNG stored.'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Tools (Pen, Highlighter, Eraser)
                SegmentedButton<WhiteboardTool>(
                  segments: WhiteboardTool.values.map((tool) {
                    return ButtonSegment(
                      value: tool,
                      icon: Icon(tool.icon, size: 16),
                      label: Text(tool.label, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                  selected: {_activeTool},
                  onSelectionChanged: (val) {
                    setState(() => _activeTool = val.first);
                  },
                ),

                // Palette
                if (_activeTool != WhiteboardTool.eraser) ...[
                  const SizedBox(width: 4),
                  ..._palette.map((color) {
                    final isSelected = _activeColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _activeColor = color),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade400,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                // Stroke width selector
                DropdownButton<double>(
                  value: _strokeWidth,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 2.0, child: Text('Fine (2px)')),
                    DropdownMenuItem(value: 4.0, child: Text('Medium (4px)')),
                    DropdownMenuItem(value: 8.0, child: Text('Thick (8px)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _strokeWidth = val);
                  },
                ),

                // Undo / Redo
                IconButton(
                  icon: const Icon(Icons.undo, size: 20),
                  tooltip: 'Undo',
                  onPressed: _strokes.isNotEmpty ? _undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo, size: 20),
                  tooltip: 'Redo',
                  onPressed: _redoStack.isNotEmpty ? _redo : null,
                ),
                IconButton(
                  key: const Key('clear_whiteboard_button'),
                  icon: const Icon(Icons.delete_sweep, size: 20),
                  tooltip: 'Clear Canvas',
                  onPressed: _strokes.isNotEmpty ? _clearCanvas : null,
                ),

                // Save & Reload
                FilledButton.icon(
                  key: const Key('save_whiteboard_button'),
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save PNG', style: TextStyle(fontSize: 12)),
                  onPressed: _saveWhiteboard,
                ),
                OutlinedButton.icon(
                  key: const Key('reload_whiteboard_button'),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reload', style: TextStyle(fontSize: 12)),
                  onPressed: _loadInitialStrokes,
                ),
              ],
            ),
          ),

          // Interactive Drawing Surface
          SizedBox(
            height: widget.height,
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RepaintBoundary(
                    key: _boundaryKey,
                    child: Container(
                      color: widget.backgroundColor,
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _WhiteboardPainter(
                            strokes: _strokes,
                            currentPoints: _currentPoints,
                            activeTool: _activeTool,
                            activeColor: _activeColor,
                            strokeWidth: _strokeWidth,
                            backgroundColor: widget.backgroundColor,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final List<WhiteboardPoint>? currentPoints;
  final WhiteboardTool activeTool;
  final Color activeColor;
  final double strokeWidth;
  final Color backgroundColor;

  const _WhiteboardPainter({
    required this.strokes,
    this.currentPoints,
    required this.activeTool,
    required this.activeColor,
    required this.strokeWidth,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render completed strokes
    for (final stroke in strokes) {
      _drawPoints(
        canvas,
        points: stroke.points,
        tool: stroke.tool,
        color: stroke.color,
        strokeWidth: stroke.strokeWidth,
      );
    }

    // Render in-progress stroke
    if (currentPoints != null && currentPoints!.isNotEmpty) {
      _drawPoints(
        canvas,
        points: currentPoints!,
        tool: activeTool,
        color: activeColor,
        strokeWidth: strokeWidth,
      );
    }
  }

  void _drawPoints(
    Canvas canvas, {
    required List<WhiteboardPoint> points,
    required WhiteboardTool tool,
    required Color color,
    required double strokeWidth,
  }) {
    if (points.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.stroke;

    switch (tool) {
      case WhiteboardTool.pen:
        paint
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        break;
      case WhiteboardTool.highlighter:
        paint
          ..color = color.withOpacity(0.35)
          ..strokeWidth = strokeWidth * 2.5
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter;
        break;
      case WhiteboardTool.eraser:
        paint
          ..color = backgroundColor
          ..strokeWidth = strokeWidth * 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        break;
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first.toOffset(), strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].x, points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}

