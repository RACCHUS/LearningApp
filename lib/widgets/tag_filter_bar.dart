import 'package:flutter/material.dart';

class TagFilterBar extends StatelessWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const TagFilterBar({
    Key? key,
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selectedTag == null,
            onSelected: (_) => onTagSelected(null),
          ),
          ...tags.map((tag) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(tag),
                  selected: selectedTag == tag,
                  onSelected: (_) => onTagSelected(tag),
                ),
              )),
        ],
      ),
    );
  }
}
