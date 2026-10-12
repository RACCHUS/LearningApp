import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/literacy/dmv_exam_simulator_widget.dart';
import '../../widgets/literacy/ged_bridge_widget.dart';
import '../../widgets/literacy/pre_reader_track_picker_dialog.dart';
import '../../widgets/literacy/uscis_civics_simulator_widget.dart';

/// Categories of life milestones on this hub.
enum LifeMilestoneCategory {
  /// 2025 USCIS Naturalization test & N-400 interview.
  citizenship,

  /// Florida FLHSMV Class E driver's license exam & MUTCD road signs.
  driverLicense,

  /// Adult Basic Education reading bridge for GED readiness.
  gedBridge,
}

/// Dedicated hub screen for high-stakes US life milestones designed for
/// oral-first and foundational learners.
class LifeMilestonesScreen extends ConsumerStatefulWidget {
  final LifeMilestoneCategory initialCategory;

  const LifeMilestonesScreen({
    super.key,
    this.initialCategory = LifeMilestoneCategory.citizenship,
  });

  @override
  ConsumerState<LifeMilestonesScreen> createState() =>
      _LifeMilestonesScreenState();
}

class _LifeMilestonesScreenState extends ConsumerState<LifeMilestonesScreen> {
  late LifeMilestoneCategory _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.initialCategory;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCategory();
    });
  }

  void _switchCategory(LifeMilestoneCategory newCategory) {
    setState(() {
      _activeCategory = newCategory;
    });
    _announceCategory();
  }

  void _announceCategory() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_activeCategory) {
      case LifeMilestoneCategory.citizenship:
        audio.speak(
            'High Stakes Milestones. United States Citizenship. Prepare for the 2025 Civics Test and oral Form N 400 interview.');
      case LifeMilestoneCategory.driverLicense:
        audio.speak(
            'High Stakes Milestones. Driver\'s License. Practice Florida road signs, intersection right of way, and the Class E exam.');
      case LifeMilestoneCategory.gedBridge:
        audio.speak(
            'High Stakes Milestones. GED Reading Bridge. Build reading skills step by step across adult basic education levels 1 through 3.');
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
            const Text('🏛️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: DesignTokens.space2),
            Text(
              'US Life Milestones',
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
              // Milestone Category Switcher Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip(
                      label: '🇺🇸 US Citizenship (2025)',
                      category: LifeMilestoneCategory.citizenship,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildCategoryChip(
                      label: '🚗 Florida Driver\'s License',
                      category: LifeMilestoneCategory.driverLicense,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    _buildCategoryChip(
                      label: '🎓 GED® Reading Bridge',
                      category: LifeMilestoneCategory.gedBridge,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.space4),

              // Active Milestone Content
              switch (_activeCategory) {
                LifeMilestoneCategory.citizenship =>
                  const UscisCivicsSimulatorWidget(),
                LifeMilestoneCategory.driverLicense =>
                  const DmvExamSimulatorWidget(),
                LifeMilestoneCategory.gedBridge =>
                  const GedBridgeWidget(),
              },

              const SizedBox(height: DesignTokens.space5),

              // Return to Foundational Literacy Hub
              InkWell(
                onTap: () => context.go('/literacy'),
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Text('🔤', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: DesignTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Foundational Literacy Hub',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.space1),
                            Text(
                              'Practice ABCs, finger tracing, CVC word blending, and survival signs.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required LifeMilestoneCategory category,
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
