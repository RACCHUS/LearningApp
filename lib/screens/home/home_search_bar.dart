import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class HomeSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const HomeSearchBar({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Synchronize controller with external state changes
    if (widget.searchQuery != widget.controller.text) {
      widget.controller.text = widget.searchQuery;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: AnimatedContainer(
        duration: DesignTokens.durationNormal,
        curve: DesignTokens.curveDefault,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          boxShadow: _isFocused
              ? DesignTokens.glowEffect(colorScheme.primary)
              : null,
        ),
        child: Focus(
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
          },
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: 'Search lessons...',
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              prefixIcon: AnimatedContainer(
                duration: DesignTokens.durationFast,
                child: Icon(
                  Icons.search,
                  color: _isFocused 
                      ? colorScheme.primary 
                      : colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                borderSide: BorderSide(
                  color: colorScheme.outline,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: DesignTokens.space3,
                horizontal: DesignTokens.space4,
              ),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onClear();
                      },
                      tooltip: 'Clear search',
                    )
                  : null,
            ),
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
