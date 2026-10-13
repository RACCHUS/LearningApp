import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_safety_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Tab sections for food safety education.
enum FoodSafetySection {
  temperature,
  cuttingBoards,
  allergens,
  handwashingTimer,
}

/// Interactive food safety widget aligned with public-domain FDA Food Code.
class FoodSafetyWidget extends ConsumerStatefulWidget {
  const FoodSafetyWidget({super.key});

  @override
  ConsumerState<FoodSafetyWidget> createState() => _FoodSafetyWidgetState();
}

class _FoodSafetyWidgetState extends ConsumerState<FoodSafetyWidget> {
  FoodSafetySection _section = FoodSafetySection.temperature;
  int _activeItemIndex = 0;

  // Handwashing timer state
  Timer? _timer;
  int _secondsRemaining = 20;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _switchSection(FoodSafetySection newSection) {
    _timer?.cancel();
    setState(() {
      _section = newSection;
      _activeItemIndex = 0;
      _isTimerRunning = false;
      _secondsRemaining = 20;
    });
    _announceCurrentActivity();
  }

  void _announceCurrentActivity() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_section) {
      case FoodSafetySection.temperature:
        final item = officialFoodSafetyCatalog[_activeItemIndex];
        audio.speak(
            '${item.title}. ${item.spokenExplanation} Standard: ${item.criticalStandard}');
      case FoodSafetySection.cuttingBoards:
        final item = officialFoodSafetyCatalog
            .firstWhere((i) => i.category == FoodSafetyCategory.crossContamination);
        audio.speak('${item.title}. ${item.spokenExplanation}');
      case FoodSafetySection.allergens:
        final item = officialFoodSafetyCatalog
            .firstWhere((i) => i.category == FoodSafetyCategory.allergens);
        audio.speak('${item.title}. ${item.spokenExplanation}');
      case FoodSafetySection.handwashingTimer:
        audio.speak(
            'Handwashing Practice. FDA 6-step hygiene sequence with active 20-second scrub timer. Tap start to begin washing.');
    }
  }

  void _startHandwashingTimer() {
    if (_isTimerRunning) return;

    setState(() {
      _isTimerRunning = true;
      _secondsRemaining = 20;
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    audio.speak(
        'Start scrubbing! Scrub palms, backs of hands, and under nails for 20 seconds.');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
        if (_secondsRemaining == 10) {
          audio.speak('10 seconds left. Keep scrubbing between fingers!');
        } else if (_secondsRemaining == 5) {
          audio.speak('5 seconds left. Clean your fingernails!');
        }
      } else {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _isTimerRunning = false;
        });
        audio.speak(
            'Time is up! Great job. Rinse thoroughly and dry with a single-use paper towel.');
      }
    });
  }

  void _resetHandwashingTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _secondsRemaining = 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSectionChip(
                label: '🌡️ Temperature & Cooking',
                section: FoodSafetySection.temperature,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🔪 Cutting Boards (Cross-Contamination)',
                section: FoodSafetySection.cuttingBoards,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🥜 Big 9 Allergens',
                section: FoodSafetySection.allergens,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🧼 20-Sec Handwash Timer',
                section: FoodSafetySection.handwashingTimer,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Section Content
        switch (_section) {
          FoodSafetySection.temperature =>
            _buildTemperatureContent(theme, colorScheme),
          FoodSafetySection.cuttingBoards =>
            _buildCuttingBoardsContent(theme, colorScheme),
          FoodSafetySection.allergens =>
            _buildAllergensContent(theme, colorScheme),
          FoodSafetySection.handwashingTimer =>
            _buildHandwashingContent(theme, colorScheme),
        },

        const SizedBox(height: DesignTokens.space4),

        // FDA Food Code Disclosure Card
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
                  const Icon(Icons.restaurant_outlined, size: 16),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    'FDA Food Code 2022 Compliance',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Educational guidelines aligned with the public-domain FDA Food Code (2022 edition). Independent of commercial credentials such as ServSafe®.',
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

  Widget _buildSectionChip({
    required String label,
    required FoodSafetySection section,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _section == section;
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
      onSelected: (_) => _switchSection(section),
    );
  }

  Widget _buildTemperatureContent(ThemeData theme, ColorScheme colorScheme) {
    final tempItems = officialFoodSafetyCatalog
        .where((i) => i.category == FoodSafetyCategory.temperatureControl)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Temperature Danger Zone Highlight Banner
        Container(
          padding: const EdgeInsets.all(DesignTokens.space3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withValues(alpha: 0.15),
                Colors.red.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🌡️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: Text(
                      'Danger Zone: 41°F to 135°F',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Bacteria multiply rapidly in this range. Keep cold food at or below 41°F. Keep hot food at or above 135°F.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Cooking Temperatures List
        ...tempItems.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: DesignTokens.space3),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space3),
              child: Row(
                children: [
                  Text(item.iconEmoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.space1),
                        Text(
                          item.ruleSummary,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Hear cooking temperature rule',
                    onPressed: () {
                      ref
                          .read(preReaderAudioServiceProvider)
                          .speak('${item.title}. ${item.spokenExplanation}');
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCuttingBoardsContent(ThemeData theme, ColorScheme colorScheme) {
    final boards = [
      (
        colorName: 'RED BOARD',
        color: Colors.red,
        icon: '🥩',
        usage: 'Raw Beef, Pork & Red Meat',
        spoken: 'Red cutting board: Raw beef and pork.',
      ),
      (
        colorName: 'YELLOW BOARD',
        color: Colors.amber,
        icon: '🍗',
        usage: 'Raw Poultry (Chicken & Turkey)',
        spoken: 'Yellow cutting board: Raw chicken and poultry.',
      ),
      (
        colorName: 'GREEN BOARD',
        color: Colors.green,
        icon: '🥗',
        usage: 'Fresh Produce, Salad & Fruits',
        spoken: 'Green cutting board: Fresh fruits and vegetables.',
      ),
      (
        colorName: 'BLUE BOARD',
        color: Colors.blue,
        icon: '🐟',
        usage: 'Raw Seafood & Fish',
        spoken: 'Blue cutting board: Raw fish and seafood.',
      ),
    ];

    return Column(
      children: boards.map((b) {
        return Card(
          margin: const EdgeInsets.only(bottom: DesignTokens.space3),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
            side: BorderSide(color: b.color, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space3),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: b.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Center(
                    child: Text(b.icon, style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.colorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: b.color.shade900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        b.usage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to board color',
                  onPressed: () {
                    ref.read(preReaderAudioServiceProvider).speak(b.spoken);
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAllergensContent(ThemeData theme, ColorScheme colorScheme) {
    final allergens = [
      ('🥛', 'Milk'),
      ('🥚', 'Eggs'),
      ('🥜', 'Peanuts'),
      ('🌰', 'Tree Nuts'),
      ('🌾', 'Wheat'),
      ('🫘', 'Soybeans'),
      ('🐟', 'Fish'),
      ('🦐', 'Shellfish'),
      ('🌱', 'Sesame'),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          children: [
            Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 24)),
                const SizedBox(width: DesignTokens.space2),
                Text(
                  'The Big 9 FDA Allergens',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Read all allergens',
                  onPressed: () {
                    ref.read(preReaderAudioServiceProvider).speak(
                        'The Big 9 allergens are: Milk, Eggs, Peanuts, Tree Nuts, Wheat, Soy, Fish, Shellfish, and Sesame. Even trace crumbs can be fatal.');
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allergens.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, idx) {
                final a = allergens[idx];
                return InkWell(
                  onTap: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak('Allergen: ${a.$2}.');
                  },
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(a.$1, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          a.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandwashingContent(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 20-Second Active Scrub Timer Card
        Card(
          color: _isTimerRunning
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              children: [
                Text(
                  '${_secondsRemaining}s',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isTimerRunning
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                Text(
                  _isTimerRunning
                    ? '🧼 Keep Scrubbing! (Palms, Fingers, Nails)'
                    : '20-Second Active Scrub Standard',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isTimerRunning ? 'Scrubbing...' : 'Start 20s Timer'),
                      onPressed: _isTimerRunning ? null : _startHandwashingTimer,
                    ),
                    if (_isTimerRunning) ...[
                      const SizedBox(width: DesignTokens.space2),
                      OutlinedButton(
                        onPressed: _resetHandwashingTimer,
                        child: const Text('Reset'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // 6 FDA Handwashing Steps
        ...officialHandwashingSteps.map((step) {
          return Card(
            margin: const EdgeInsets.only(bottom: DesignTokens.space2),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${step.stepNumber}'),
              ),
              title: Text(
                '${step.iconEmoji} ${step.actionTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(step.instructions),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Listen to step instructions',
                onPressed: () {
                  ref.read(preReaderAudioServiceProvider).speak(
                      'Step ${step.stepNumber}: ${step.actionTitle}. ${step.instructions}');
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
