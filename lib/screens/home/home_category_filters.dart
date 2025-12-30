import 'package:flutter/material.dart';
import 'package:learning_pwa/components/category_chip.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class HomeCategoryFilters extends StatefulWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const HomeCategoryFilters({
    super.key,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  State<HomeCategoryFilters> createState() => _HomeCategoryFiltersState();
}

class _HomeCategoryFiltersState extends State<HomeCategoryFilters> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFadeVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateFadeVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFadeVisibility() {
    final showLeft = _scrollController.offset > 10;
    final showRight = _scrollController.offset < 
        _scrollController.position.maxScrollExtent - 10;

    if (showLeft != _showLeftFade || showRight != _showRightFade) {
      setState(() {
        _showLeftFade = showLeft;
        _showRightFade = showRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 48,
        child: Stack(
          children: [
            // Scrollable chips
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space4,
              ),
              child: Row(
                children: [
                  CategoryChip(
                    label: 'All',
                    icon: Icons.all_inclusive,
                    isSelected: widget.selectedTag == null,
                    onTap: () => widget.onTagSelected(null),
                  ),
                  CategoryChip(
                    label: 'Flutter',
                    icon: Icons.flutter_dash,
                    isSelected: widget.selectedTag == 'flutter',
                    onTap: () => widget.onTagSelected('flutter'),
                  ),
                  CategoryChip(
                    label: 'Dart',
                    icon: Icons.code,
                    isSelected: widget.selectedTag == 'dart',
                    onTap: () => widget.onTagSelected('dart'),
                  ),
                  CategoryChip(
                    label: 'JavaScript',
                    icon: Icons.javascript,
                    isSelected: widget.selectedTag == 'javascript',
                    onTap: () => widget.onTagSelected('javascript'),
                  ),
                  CategoryChip(
                    label: 'Python',
                    icon: Icons.code_outlined,
                    isSelected: widget.selectedTag == 'python',
                    onTap: () => widget.onTagSelected('python'),
                  ),
                  // Add extra padding at the end
                  const SizedBox(width: DesignTokens.space4),
                ],
              ),
            ),

            // Left fade indicator
            if (_showLeftFade)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          colorScheme.surface,
                          colorScheme.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Right fade indicator
            if (_showRightFade)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          colorScheme.surface,
                          colorScheme.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
