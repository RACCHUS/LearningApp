import 'package:flutter/material.dart';

/// Enum for predefined empty state illustrations
enum EmptyStateIllustration {
  noLessons,
  noCourses,
  noStudySets,
  noResults,
  startLearning,
  error,
}

class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final Widget? action;
  final double iconSize;
  final double spacing;
  final EmptyStateIllustration? illustration;

  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.action,
    this.iconSize = 64,
    this.spacing = 16,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (illustration != null)
                _EmptyStateIllustration(
                  type: illustration!,
                  colorScheme: colorScheme,
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: iconSize,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
              SizedBox(height: spacing),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (message.isNotEmpty) ...{
                SizedBox(height: spacing / 2),
                Text(
                  message,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              },
              if (action != null) ...{
                SizedBox(height: spacing * 1.5),
                action!,
              },
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom illustration widget for empty states
class _EmptyStateIllustration extends StatelessWidget {
  final EmptyStateIllustration type;
  final ColorScheme colorScheme;

  const _EmptyStateIllustration({
    required this.type,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 160,
      child: CustomPaint(
        painter: _IllustrationPainter(
          type: type,
          primaryColor: colorScheme.primary,
          secondaryColor: colorScheme.secondary,
          surfaceColor: colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Custom painter for empty state illustrations
class _IllustrationPainter extends CustomPainter {
  final EmptyStateIllustration type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  _IllustrationPainter({
    required this.type,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case EmptyStateIllustration.noLessons:
        _drawNoLessons(canvas, size);
        break;
      case EmptyStateIllustration.noCourses:
        _drawNoCourses(canvas, size);
        break;
      case EmptyStateIllustration.noStudySets:
        _drawNoStudySets(canvas, size);
        break;
      case EmptyStateIllustration.noResults:
        _drawNoResults(canvas, size);
        break;
      case EmptyStateIllustration.startLearning:
        _drawStartLearning(canvas, size);
        break;
      case EmptyStateIllustration.error:
        _drawError(canvas, size);
        break;
    }
  }

  void _drawNoLessons(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    // Book shape
    paint.color = primaryColor.withValues(alpha: 0.3);
    final bookRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 70, height: 50),
      const Radius.circular(4),
    );
    canvas.drawRRect(bookRect, paint);

    // Book spine
    paint.color = primaryColor.withValues(alpha: 0.5);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 4, height: 50),
      paint,
    );

    // Plus icon (add new)
    paint.color = secondaryColor;
    canvas.drawCircle(
      Offset(center.dx + 40, center.dy + 30),
      15,
      paint,
    );
    paint.color = Colors.white;
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx + 35, center.dy + 30),
      Offset(center.dx + 45, center.dy + 30),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + 40, center.dy + 25),
      Offset(center.dx + 40, center.dy + 35),
      paint,
    );
  }

  void _drawNoCourses(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    // Stacked layers (course structure)
    for (int i = 0; i < 3; i++) {
      paint.color = primaryColor.withValues(alpha: 0.2 + (i * 0.15));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + (i * 12) - 12),
          width: 60 - (i * 8),
          height: 35,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
    }

    // Graduation cap
    paint.color = secondaryColor;
    final capPath = Path()
      ..moveTo(center.dx - 25, center.dy - 30)
      ..lineTo(center.dx, center.dy - 50)
      ..lineTo(center.dx + 25, center.dy - 30)
      ..close();
    canvas.drawPath(capPath, paint);
  }

  void _drawNoStudySets(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    // Flashcard stack
    for (int i = 2; i >= 0; i--) {
      paint.color = i == 0 
          ? primaryColor.withValues(alpha: 0.5)
          : primaryColor.withValues(alpha: 0.2);
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx + (i * 5), center.dy + (i * 5)),
          width: 60,
          height: 40,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
    }

    // Lines on front card
    paint.color = primaryColor.withValues(alpha: 0.3);
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 2; i++) {
      canvas.drawLine(
        Offset(center.dx - 20, center.dy - 8 + (i * 12)),
        Offset(center.dx + 20, center.dy - 8 + (i * 12)),
        paint,
      );
    }
  }

  void _drawNoResults(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    // Magnifying glass
    paint.color = primaryColor.withValues(alpha: 0.3);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 6;
    canvas.drawCircle(Offset(center.dx - 10, center.dy - 10), 25, paint);
    
    // Handle
    paint.strokeWidth = 8;
    paint.strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx + 10, center.dy + 10),
      Offset(center.dx + 30, center.dy + 30),
      paint,
    );

    // X mark in circle
    paint.color = secondaryColor.withValues(alpha: 0.6);
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(center.dx - 20, center.dy - 20),
      Offset(center.dx, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx - 20, center.dy),
      paint,
    );
  }

  void _drawStartLearning(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle
    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    // Lightbulb
    paint.color = Colors.amber.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(center.dx, center.dy - 10), 25, paint);
    
    // Bulb base
    paint.color = primaryColor.withValues(alpha: 0.4);
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 20),
        width: 20,
        height: 15,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(baseRect, paint);

    // Light rays
    paint.color = Colors.amber.withValues(alpha: 0.3);
    paint.strokeWidth = 3;
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    
    final rays = [
      [Offset(center.dx - 35, center.dy - 35), Offset(center.dx - 45, center.dy - 45)],
      [Offset(center.dx + 35, center.dy - 35), Offset(center.dx + 45, center.dy - 45)],
      [Offset(center.dx - 40, center.dy - 5), Offset(center.dx - 50, center.dy - 5)],
      [Offset(center.dx + 40, center.dy - 5), Offset(center.dx + 50, center.dy - 5)],
    ];
    
    for (final ray in rays) {
      canvas.drawLine(ray[0], ray[1], paint);
    }
  }

  void _drawError(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);

    // Background circle (red tinted)
    paint.color = Colors.red.withValues(alpha: 0.1);
    canvas.drawCircle(center, 60, paint);

    // Warning triangle
    paint.color = Colors.orange.withValues(alpha: 0.7);
    final trianglePath = Path()
      ..moveTo(center.dx, center.dy - 40)
      ..lineTo(center.dx - 35, center.dy + 25)
      ..lineTo(center.dx + 35, center.dy + 25)
      ..close();
    canvas.drawPath(trianglePath, paint);

    // Exclamation mark
    paint.color = Colors.white;
    canvas.drawCircle(Offset(center.dx, center.dy + 12), 4, paint);
    
    final exclamationRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 8),
        width: 6,
        height: 25,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(exclamationRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
