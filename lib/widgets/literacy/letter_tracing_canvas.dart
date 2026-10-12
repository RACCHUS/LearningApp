import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// A template stroke defined in normalized coordinates (0.0 to 1.0).
class NormalizedStroke {
  final List<Offset> points;
  const NormalizedStroke(this.points);
}

/// Vector paths for foundational letters.
class LetterStrokeTemplates {
  static final Map<String, List<NormalizedStroke>> templates = {
    'M': [
      // Left vertical: bottom to top
      const NormalizedStroke([Offset(0.2, 0.85), Offset(0.2, 0.15)]),
      // Down to center
      const NormalizedStroke([Offset(0.2, 0.15), Offset(0.5, 0.55)]),
      // Up to right
      const NormalizedStroke([Offset(0.5, 0.55), Offset(0.8, 0.15)]),
      // Right vertical down
      const NormalizedStroke([Offset(0.8, 0.15), Offset(0.8, 0.85)]),
    ],
    'A': [
      // Left diagonal down
      const NormalizedStroke([Offset(0.5, 0.15), Offset(0.2, 0.85)]),
      // Right diagonal down
      const NormalizedStroke([Offset(0.5, 0.15), Offset(0.8, 0.85)]),
      // Crossbar left to right
      const NormalizedStroke([Offset(0.32, 0.55), Offset(0.68, 0.55)]),
    ],
    'S': [
      // Curving S shape
      const NormalizedStroke([
        Offset(0.75, 0.25),
        Offset(0.5, 0.15),
        Offset(0.3, 0.28),
        Offset(0.5, 0.5),
        Offset(0.7, 0.72),
        Offset(0.45, 0.85),
        Offset(0.25, 0.75),
      ]),
    ],
    'T': [
      // Top bar left to right
      const NormalizedStroke([Offset(0.2, 0.18), Offset(0.8, 0.18)]),
      // Stem top to bottom
      const NormalizedStroke([Offset(0.5, 0.18), Offset(0.5, 0.85)]),
    ],
    'B': [
      // Left vertical stem
      const NormalizedStroke([Offset(0.25, 0.15), Offset(0.25, 0.85)]),
      // Top curve
      const NormalizedStroke([
        Offset(0.25, 0.15),
        Offset(0.65, 0.15),
        Offset(0.75, 0.32),
        Offset(0.65, 0.5),
        Offset(0.25, 0.5),
      ]),
      // Bottom curve
      const NormalizedStroke([
        Offset(0.25, 0.5),
        Offset(0.7, 0.5),
        Offset(0.8, 0.68),
        Offset(0.7, 0.85),
        Offset(0.25, 0.85),
      ]),
    ],
  };
}

class LetterTracingCanvas extends ConsumerStatefulWidget {
  final String letter;
  final VoidCallback? onCompleted;

  const LetterTracingCanvas({
    super.key,
    required this.letter,
    this.onCompleted,
  });

  @override
  ConsumerState<LetterTracingCanvas> createState() =>
      _LetterTracingCanvasState();
}

class _LetterTracingCanvasState extends ConsumerState<LetterTracingCanvas>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _guideAnimController;

  final List<List<Offset>> _drawnStrokes = [];
  List<Offset> _currentStroke = [];
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _guideAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(preReaderProvider.notifier).speak(
            'Trace the letter ${widget.letter} with your finger.',
          );
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _guideAnimController.dispose();
    super.dispose();
  }

  void _clearCanvas() {
    setState(() {
      _drawnStrokes.clear();
      _currentStroke.clear();
      _isComplete = false;
    });
  }

  void _evaluateCompletion(Size size) {
    final template = LetterStrokeTemplates.templates[widget.letter];
    if (template == null || _drawnStrokes.isEmpty) return;

    // Sample all points along template strokes in screen space
    final samplePoints = <Offset>[];
    for (final stroke in template) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = Offset(
          stroke.points[i].dx * size.width,
          stroke.points[i].dy * size.height,
        );
        final p2 = Offset(
          stroke.points[i + 1].dx * size.width,
          stroke.points[i + 1].dy * size.height,
        );
        final dist = (p2 - p1).distance;
        final steps = (dist / 12).clamp(1, 30).toInt();
        for (int s = 0; s <= steps; s++) {
          samplePoints.add(Offset.lerp(p1, p2, s / steps)!);
        }
      }
    }

    if (samplePoints.isEmpty) return;

    // Check how many sample points were reached within tolerance (36dp)
    int coveredCount = 0;
    const tolerance = 36.0;

    for (final target in samplePoints) {
      bool covered = false;
      for (final stroke in _drawnStrokes) {
        for (final drawn in stroke) {
          if ((drawn - target).distance <= tolerance) {
            covered = true;
            break;
          }
        }
        if (covered) break;
      }
      if (covered) coveredCount++;
    }

    final ratio = coveredCount / samplePoints.length;
    if (ratio >= 0.75 && !_isComplete) {
      setState(() {
        _isComplete = true;
      });
      _confettiController.play();
      ref.read(preReaderProvider.notifier).speak(
            'Great tracing! That is the letter ${widget.letter}!',
          );
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final template = LetterStrokeTemplates.templates[widget.letter] ?? [];

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            side: BorderSide(
              color: _isComplete ? Colors.green : colorScheme.outline,
              width: _isComplete ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit, size: 24),
                        const SizedBox(width: DesignTokens.space2),
                        Text(
                          'Trace Letter ${widget.letter}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      key: const Key('tracing-reset-btn'),
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Clear and try again',
                      onPressed: _clearCanvas,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                // Tracing drawing canvas
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasSize =
                          Size(constraints.maxWidth, constraints.maxHeight);

                      return GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            _currentStroke = [details.localPosition];
                            _drawnStrokes.add(_currentStroke);
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            _currentStroke.add(details.localPosition);
                          });
                        },
                        onPanEnd: (_) {
                          _evaluateCompletion(canvasSize);
                        },
                        child: AnimatedBuilder(
                          animation: _guideAnimController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: canvasSize,
                              painter: _TracingPainter(
                                template: template,
                                drawnStrokes: _drawnStrokes,
                                animValue: _guideAnimController.value,
                                primaryColor: colorScheme.primary,
                                guideColor: colorScheme.primary
                                    .withValues(alpha: 0.25),
                                isComplete: _isComplete,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),

                Text(
                  _isComplete
                      ? '⭐ Beautiful! Tracing complete!'
                      : 'Follow the glowing guide dot with your finger',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isComplete
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.orange,
            Colors.blue,
            Colors.amber
          ],
        ),
      ],
    );
  }
}

class _TracingPainter extends CustomPainter {
  final List<NormalizedStroke> template;
  final List<List<Offset>> drawnStrokes;
  final double animValue;
  final Color primaryColor;
  final Color guideColor;
  final bool isComplete;

  _TracingPainter({
    required this.template,
    required this.drawnStrokes,
    required this.animValue,
    required this.primaryColor,
    required this.guideColor,
    required this.isComplete,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw dashed/faint template outline
    final templatePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in template) {
      if (stroke.points.isEmpty) continue;
      final path = Path();
      path.moveTo(
        stroke.points.first.dx * size.width,
        stroke.points.first.dy * size.height,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx * size.width,
          stroke.points[i].dy * size.height,
        );
      }
      canvas.drawPath(path, templatePaint);
    }

    // 2. Draw user's drawn strokes
    final drawnPaint = Paint()
      ..color = isComplete ? Colors.green : primaryColor
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in drawnStrokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, drawnPaint);
    }

    // 3. Draw animated guide dot along the first uncompleted stroke
    if (!isComplete && template.isNotEmpty) {
      final firstStroke = template.first;
      if (firstStroke.points.length >= 2) {
        final p1 = Offset(
          firstStroke.points.first.dx * size.width,
          firstStroke.points.first.dy * size.height,
        );
        final p2 = Offset(
          firstStroke.points[1].dx * size.width,
          firstStroke.points[1].dy * size.height,
        );
        final guidePos = Offset.lerp(p1, p2, animValue) ?? p1;

        final guideDotPaint = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(guidePos, 9, guideDotPaint);

        final glowPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(guidePos, 16, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) => true;
}
