import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class CategoryChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip> 
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CategoryChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: DesignTokens.durationNormal,
            curve: DesignTokens.curveDefault,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space4,
              vertical: DesignTokens.space2,
            ),
            margin: const EdgeInsets.only(right: DesignTokens.space2),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primary
                  : _isHovered
                      ? (isDark ? colorScheme.surfaceContainerHigh : Colors.grey.shade200)
                      : (isDark ? colorScheme.surfaceContainerLow : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
              border: Border.all(
                color: widget.isSelected
                    ? colorScheme.primary
                    : _isHovered
                        ? colorScheme.outline
                        : colorScheme.outline.withValues(alpha: 0.5),
                width: widget.isSelected ? 1.5 : 1,
              ),
              boxShadow: widget.isSelected
                  ? DesignTokens.shadowSm(colorScheme.primary)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: DesignTokens.durationFast,
                  child: Icon(
                    widget.icon,
                    size: 16,
                    color: widget.isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
