import 'package:flutter/material.dart';

class CategoryFilters extends StatelessWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const CategoryFilters({
    super.key,
    required this.selectedTag,
    required this.onTagSelected,
  });

  Widget _buildCategoryChip(String label, IconData icon, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _buildCategoryChip(
            'All',
            Icons.all_inclusive,
            isSelected: selectedTag == null,
            onTap: () => onTagSelected(null),
          ),
          _buildCategoryChip(
            'Flutter',
            Icons.flutter_dash,
            isSelected: selectedTag == 'flutter',
            onTap: () => onTagSelected('flutter'),
          ),
          _buildCategoryChip(
            'Dart',
            Icons.code,
            isSelected: selectedTag == 'dart',
            onTap: () => onTagSelected('dart'),
          ),
        ],
      ),
    );
  }
}
