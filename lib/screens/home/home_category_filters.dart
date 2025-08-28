import 'package:flutter/material.dart';
import 'package:learning_pwa/components/category_chip.dart';

class HomeCategoryFilters extends StatelessWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const HomeCategoryFilters({
    super.key,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            CategoryChip(
              label: 'All',
              icon: Icons.all_inclusive,
              isSelected: selectedTag == null,
              onTap: () => onTagSelected(null),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'Flutter',
              icon: Icons.flutter_dash,
              isSelected: selectedTag == 'flutter',
              onTap: () => onTagSelected('flutter'),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'Dart',
              icon: Icons.code,
              isSelected: selectedTag == 'dart',
              onTap: () => onTagSelected('dart'),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'JavaScript',
              icon: Icons.javascript,
              isSelected: selectedTag == 'javascript',
              onTap: () => onTagSelected('javascript'),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'Python',
              icon: Icons.code_outlined,
              isSelected: selectedTag == 'python',
              onTap: () => onTagSelected('python'),
            ),
          ],
        ),
      ),
    );
  }
}
