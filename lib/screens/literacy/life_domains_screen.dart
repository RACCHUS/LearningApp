import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/literacy/currency_atm_widget.dart';
import '../../widgets/literacy/food_safety_widget.dart';
import '../../widgets/literacy/pre_reader_track_picker_dialog.dart';
import '../../widgets/literacy/rx_and_first_aid_widget.dart';
import '../../widgets/literacy/workplace_safety_widget.dart';

/// Categories of life survival domains.
enum LifeDomainCategory {
  workplaceSafety,
  foodSafety,
  healthcareFirstAid,
  financialAtm,
}

/// Dedicated hub screen for practical workplace, food safety, healthcare,
/// and financial survival literacy.
class LifeDomainsScreen extends ConsumerStatefulWidget {
  final LifeDomainCategory initialCategory;

  const LifeDomainsScreen({
    super.key,
    this.initialCategory = LifeDomainCategory.workplaceSafety,
  });

  @override
  ConsumerState<LifeDomainsScreen> createState() => _LifeDomainsScreenState();
}

class _LifeDomainsScreenState extends ConsumerState<LifeDomainsScreen> {
  late LifeDomainCategory _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCategory();
    });
  }

  void _switchCategory(LifeDomainCategory newCategory) {
    setState(() {
      _activeCategory = newCategory;
    });
    _announceCategory();
  }

  void _announceCategory() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_activeCategory) {
      case LifeDomainCategory.workplaceSafety:
        audio.speak(
            'Workplace Safety. Personal protective equipment, chemical hazard pictograms, and lockout tagout rules.');
      case LifeDomainCategory.foodSafety:
        audio.speak(
            'Food Safety. FDA temperature danger zone, color-coded cutting boards, allergens, and 20-second handwashing.');
      case LifeDomainCategory.healthcareFirstAid:
        audio.speak(
            'Healthcare and First Aid. Read prescription bottle labels, pharmacist guidance, and cool running water burn care.');
      case LifeDomainCategory.financialAtm:
        audio.speak(
            'Cash and ATM Survival. US coins, paper bills, and step-by-step cash machine practice.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: DesignTokens.space2),
            Text(
              'Life Survival Skills',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch track',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => PreReaderTrackPickerDialog.show(context),
          ),
          IconButton(
            tooltip:
                profile.autoSpeakScreens ? 'Auto-speak ON' : 'Auto-speak OFF',
            icon: Icon(
              profile.autoSpeakScreens ? Icons.volume_up : Icons.volume_off,
            ),
            onPressed: () {
              ref.read(preReaderProvider.notifier).toggleAutoSpeak();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(DesignTokens.space4),
            children: [
              // Domain Category Switcher Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: '🦺 Workplace Safety (OSHA)',
                      category: LifeDomainCategory.workplaceSafety,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildCategoryChip(
                      label: '🍳 Food Safety (FDA)',
                      category: LifeDomainCategory.foodSafety,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildCategoryChip(
                      label: '💊 Health & First Aid',
                      category: LifeDomainCategory.healthcareFirstAid,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildCategoryChip(
                      label: '💵 Cash & ATM Practice',
                      category: LifeDomainCategory.financialAtm,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space4),

              // Active Domain Content
              switch (_activeCategory) {
                LifeDomainCategory.workplaceSafety =>
                  const WorkplaceSafetyWidget(),
                LifeDomainCategory.foodSafety =>
                  const FoodSafetyWidget(),
                LifeDomainCategory.healthcareFirstAid =>
                  const RxAndFirstAidWidget(),
                LifeDomainCategory.financialAtm =>
                  const CurrencyAtmWidget(),
              },

              const SizedBox(height: DesignTokens.space5),

              // Navigation Links to Milestones & Literacy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('US Milestones'),
                      onPressed: () => context.go('/milestones'),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.menu_book),
                      label: const Text('ABC Literacy Hub'),
                      onPressed: () => context.go('/literacy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required LifeDomainCategory category,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _activeCategory == category;
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
