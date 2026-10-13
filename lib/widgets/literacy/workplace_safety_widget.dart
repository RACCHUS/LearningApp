import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/workplace_safety_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Interactive workplace safety & OSHA hazard awareness widget.
class WorkplaceSafetyWidget extends ConsumerStatefulWidget {
  const WorkplaceSafetyWidget({super.key});

  @override
  ConsumerState<WorkplaceSafetyWidget> createState() =>
      _WorkplaceSafetyWidgetState();
}

class _WorkplaceSafetyWidgetState extends ConsumerState<WorkplaceSafetyWidget> {
  WorkplaceSafetyCategory _selectedCategory = WorkplaceSafetyCategory.ppe;
  int _activeItemIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentItem();
    });
  }

  List<WorkplaceSafetyItem> get _categoryItems {
    return officialWorkplaceSafetyCatalog
        .where((i) => i.category == _selectedCategory)
        .toList();
  }

  WorkplaceSafetyItem get _activeItem {
    final list = _categoryItems;
    if (_activeItemIndex < list.length) {
      return list[_activeItemIndex];
    }
    return list.isNotEmpty
        ? list.first
        : officialWorkplaceSafetyCatalog.first;
  }

  void _switchCategory(WorkplaceSafetyCategory cat) {
    setState(() {
      _selectedCategory = cat;
      _activeItemIndex = 0;
    });
    _announceCurrentItem();
  }

  void _announceCurrentItem() {
    final item = _activeItem;
    ref.read(preReaderAudioServiceProvider).speak(
        '${item.title}. ${item.spokenExplanation} Warning: ${item.hazardWarning}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeItem = _activeItem;
    final items = _categoryItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip(
                label: '🪖 Personal Protective Gear (PPE)',
                category: WorkplaceSafetyCategory.ppe,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildCategoryChip(
                label: '☠️ GHS Chemical Symbols',
                category: WorkplaceSafetyCategory.ghsPictogram,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildCategoryChip(
                label: '🔒 Lockout / Tagout (LOTO)',
                category: WorkplaceSafetyCategory.lockoutTagout,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildCategoryChip(
                label: '🪜 Ladder Safety Rules',
                category: WorkplaceSafetyCategory.fallProtection,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Carousel of items in this category
        if (items.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isSelected = idx == _activeItemIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: DesignTokens.space2),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Text(item.iconEmoji, style: const TextStyle(fontSize: 16)),
                    label: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                    selectedColor: colorScheme.primary,
                    onSelected: (_) {
                      setState(() {
                        _activeItemIndex = idx;
                      });
                      _announceCurrentItem();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
        ],

        // Active Safety Item Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              children: [
                Text(
                  activeItem.iconEmoji,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  activeItem.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  activeItem.description,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DesignTokens.space3),

                // Spoken explanation container
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: DesignTokens.space2),
                      Expanded(
                        child: Text(
                          activeItem.spokenExplanation,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                // Warning Banner
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: DesignTokens.space2),
                      Expanded(
                        child: Text(
                          'Hazard Warning: ${activeItem.hazardWarning}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),

                FilledButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Listen to Safety Rule'),
                  onPressed: _announceCurrentItem,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space4),

        // OSHA Statutory Card Disclaimer
        Container(
          padding: const EdgeInsets.all(DesignTokens.space3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    'OSHA Training Disclosure',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                oshaCardDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required WorkplaceSafetyCategory category,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
        ),
      ),
      selectedColor: colorScheme.primary,
      onSelected: (_) => _switchCategory(category),
    );
  }
}
