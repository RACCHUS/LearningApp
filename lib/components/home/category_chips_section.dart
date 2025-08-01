import 'package:flutter/material.dart';
import 'package:learning_pwa/components/home/category_chip.dart';

class CategoryChipsSection extends StatelessWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const CategoryChipsSection({
    super.key,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            CategoryChip(
              label: 'All',
              icon: Icons.all_inclusive,
              isSelected: selectedTag == null,
              onTap: () => onTagSelected(null),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'Favorites',
              icon: Icons.favorite,
              isSelected: selectedTag == 'favorites',
              onTap: () => onTagSelected('favorites'),
            ),
            const SizedBox(width: 8),
            CategoryChip(
              label: 'Recent',
              icon: Icons.history,
              isSelected: selectedTag == 'recent',
              onTap: () => onTagSelected('recent'),
            ),
          ],
        ),
      ),
    );
  }
}
