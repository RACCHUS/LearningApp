import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/empty_state.dart';

/// A shimmer loading effect widget for skeleton screens.
/// Creates an animated gradient that moves across the widget.
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? colorScheme.surfaceContainerHigh
        : Colors.grey.shade300;
    final highlightColor = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)
        : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                0.5 + (_animation.value * 0.25),
                1.0,
              ],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// A simple shimmer box placeholder
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius ?? BorderRadius.circular(DesignTokens.radiusSm),
      ),
    );
  }
}

/// Skeleton loader for a lesson card - matches the real card layout
class LessonCardSkeleton extends StatelessWidget {
  const LessonCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: DesignTokens.space2,
          horizontal: DesignTokens.space4,
        ),
        padding: const EdgeInsets.all(DesignTokens.space4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title placeholder
            const ShimmerBox(
              width: 220,
              height: 22,
            ),
            const SizedBox(height: DesignTokens.space3),
            
            // Description placeholder (2 lines)
            const ShimmerBox(
              width: double.infinity,
              height: 16,
            ),
            const SizedBox(height: DesignTokens.space2),
            const ShimmerBox(
              width: 180,
              height: 16,
            ),
            const SizedBox(height: DesignTokens.space4),
            
            // Bottom row: date and tags
            Row(
              children: [
                // Date placeholder
                const ShimmerBox(
                  width: 80,
                  height: 14,
                ),
                const SizedBox(width: DesignTokens.space3),
                
                // Tag placeholders
                ShimmerBox(
                  width: 60,
                  height: 24,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                ),
                const SizedBox(width: DesignTokens.space2),
                ShimmerBox(
                  width: 50,
                  height: 24,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of skeleton cards for loading state
class LessonListSkeleton extends StatelessWidget {
  final int itemCount;

  const LessonListSkeleton({
    super.key,
    this.itemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? DesignTokens.space2 : 0,
            ),
            child: const LessonCardSkeleton(),
          );
        },
        childCount: itemCount,
      ),
    );
  }
}

/// Empty state widget with illustration and call-to-action
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final Widget? illustration;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonPressed,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon/illustration container
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: DesignTokens.durationSlow,
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: illustration ?? Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.space5),
            
            // Title
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space2),
            
            // Subtitle
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            
            // Optional button
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: DesignTokens.space5),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add),
                label: Text(buttonLabel!),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space5,
                    vertical: DesignTokens.space3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// No search results state
class NoResultsWidget extends StatelessWidget {
  final String searchQuery;
  final VoidCallback? onClearSearch;

  const NoResultsWidget({
    super.key,
    required this.searchQuery,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: DesignTokens.space4),
            Text(
              'No results for "$searchQuery"',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'Try adjusting your search or filters',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onClearSearch != null) ...[
              const SizedBox(height: DesignTokens.space4),
              TextButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A widget that displays an empty state illustration
/// Use this with EmptyStateWidget's illustration parameter
class EmptyStateIllustrationWidget extends StatelessWidget {
  final EmptyStateIllustration type;
  final double size;

  const EmptyStateIllustrationWidget({
    super.key,
    required this.type,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: size * 1.25,
      height: size,
      child: CustomPaint(
        painter: _EmptyStateIllustrationPainter(
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
class _EmptyStateIllustrationPainter extends CustomPainter {
  final EmptyStateIllustration type;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;

  _EmptyStateIllustrationPainter({
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

    // Plus icon
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

    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

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

    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

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

    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    paint.color = primaryColor.withValues(alpha: 0.3);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 6;
    canvas.drawCircle(Offset(center.dx - 10, center.dy - 10), 25, paint);
    
    paint.strokeWidth = 8;
    paint.strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx + 10, center.dy + 10),
      Offset(center.dx + 30, center.dy + 30),
      paint,
    );

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

    paint.color = surfaceColor;
    canvas.drawCircle(center, 60, paint);

    paint.color = Colors.amber.withValues(alpha: 0.6);
    canvas.drawCircle(Offset(center.dx, center.dy - 10), 25, paint);
    
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

    paint.color = Colors.red.withValues(alpha: 0.1);
    canvas.drawCircle(center, 60, paint);

    paint.color = Colors.orange.withValues(alpha: 0.7);
    final trianglePath = Path()
      ..moveTo(center.dx, center.dy - 40)
      ..lineTo(center.dx - 35, center.dy + 25)
      ..lineTo(center.dx + 35, center.dy + 25)
      ..close();
    canvas.drawPath(trianglePath, paint);

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
