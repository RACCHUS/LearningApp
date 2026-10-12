import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency_survival_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Currency activity section tabs.
enum CurrencyActivitySection {
  coinsAndBills,
  atmSimulator,
  verifyChange,
}

/// Interactive US currency recognition and ATM cash withdrawal simulator.
///
/// Fully compliant with 18 U.S.C. § 504 and 31 CFR Part 411 digital currency rules.
class CurrencyAtmWidget extends ConsumerStatefulWidget {
  const CurrencyAtmWidget({super.key});

  @override
  ConsumerState<CurrencyAtmWidget> createState() => _CurrencyAtmWidgetState();
}

class _CurrencyAtmWidgetState extends ConsumerState<CurrencyAtmWidget> {
  CurrencyActivitySection _section = CurrencyActivitySection.coinsAndBills;
  int _activeDenomIndex = 0;

  // ATM Simulator State
  int _atmStepIndex = 0;
  String _enteredPin = '';
  int? _selectedAtmAmount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  void _switchSection(CurrencyActivitySection sec) {
    setState(() {
      _section = sec;
      _atmStepIndex = 0;
      _enteredPin = '';
      _selectedAtmAmount = null;
    });
    _announceCurrentActivity();
  }

  void _announceCurrentActivity() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_section) {
      case CurrencyActivitySection.coinsAndBills:
        final item = officialCurrencyCatalog[_activeDenomIndex];
        audio.speak('${item.name}. ${item.spokenDescription}');
      case CurrencyActivitySection.atmSimulator:
        final step = officialAtmSteps[_atmStepIndex];
        audio.speak('${step.actionTitle}. ${step.spokenGuidance}');
      case CurrencyActivitySection.verifyChange:
        audio.speak(
            'Verify Change Drill. Always check your change before walking away from the register.');
    }
  }

  void _selectDenomination(int index) {
    setState(() {
      _activeDenomIndex = index;
    });
    final item = officialCurrencyCatalog[index];
    ref
        .read(preReaderAudioServiceProvider)
        .speak('${item.name}. ${item.spokenDescription} Tip: ${item.practicalTip}');
  }

  void _pressPinDigit(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });
      ref.read(preReaderAudioServiceProvider).speak('Digit entered.');
    }
  }

  void _clearPin() {
    setState(() {
      _enteredPin = '';
    });
  }

  void _advanceAtmStep() {
    if (_atmStepIndex + 1 < officialAtmSteps.length) {
      setState(() {
        _atmStepIndex++;
      });
      final nextStep = officialAtmSteps[_atmStepIndex];
      ref
          .read(preReaderAudioServiceProvider)
          .speak('${nextStep.actionTitle}. ${nextStep.spokenGuidance}');
    } else {
      // Completed withdrawal
      ref.read(preReaderAudioServiceProvider).speak(
          'Withdrawal complete! You safely took your cash and your debit card.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ATM cash withdrawal simulated successfully!'),
        ),
      );
    }
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
                label: '💵 Coins & Paper Bills',
                section: CurrencyActivitySection.coinsAndBills,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🏧 ATM Cash Simulator',
                section: CurrencyActivitySection.atmSimulator,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🧾 Verify Change Practice',
                section: CurrencyActivitySection.verifyChange,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Section Content
        switch (_section) {
          CurrencyActivitySection.coinsAndBills =>
            _buildCoinsAndBillsContent(theme, colorScheme),
          CurrencyActivitySection.atmSimulator =>
            _buildAtmContent(theme, colorScheme),
          CurrencyActivitySection.verifyChange =>
            _buildVerifyChangeContent(theme, colorScheme),
        },

        const SizedBox(height: DesignTokens.space4),

        // 18 U.S.C. § 504 Statutory Compliance Card
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
                  const Icon(Icons.account_balance_outlined, size: 16),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    '18 U.S.C. § 504 Currency Compliance',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Digital illustrations of US currency conform to 18 U.S.C. § 504 and 31 CFR Part 411: '
                'rendered as one-sided educational vector representations.',
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
    required CurrencyActivitySection section,
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

  Widget _buildCoinsAndBillsContent(ThemeData theme, ColorScheme colorScheme) {
    final activeItem = officialCurrencyCatalog[_activeDenomIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal list of all coins and bills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: officialCurrencyCatalog.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = idx == _activeDenomIndex;

              return Padding(
                padding: const EdgeInsets.only(right: DesignTokens.space2),
                child: FilterChip(
                  selected: isSelected,
                  avatar: Text(item.visualEmoji, style: const TextStyle(fontSize: 16)),
                  label: Text(
                    item.displayValue,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  selectedColor: colorScheme.primary,
                  onSelected: (_) => _selectDenomination(idx),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Active Denomination Display Card
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
                  activeItem.visualEmoji,
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  activeItem.displayValue,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                Text(
                  activeItem.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  activeItem.portraitOrSymbol,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Text(
                    activeItem.spokenDescription,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),

                Container(
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 18),
                      const SizedBox(width: DesignTokens.space1),
                      Expanded(
                        child: Text(
                          'Tip: ${activeItem.practicalTip}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                FilledButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Hear Currency Details'),
                  onPressed: _announceCurrentActivity,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAtmContent(ThemeData theme, ColorScheme colorScheme) {
    final step = officialAtmSteps[_atmStepIndex];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: Text('${step.stepNumber}'),
                ),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    step.actionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Hear step guidance',
                  onPressed: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak(step.spokenGuidance);
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),

            // Step interactive simulator surface
            Container(
              padding: const EdgeInsets.all(DesignTokens.space4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: Column(
                children: [
                  Text(
                    step.iconEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  Text(
                    step.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.space3),

                  // PIN Pad interactive simulation on step 2
                  if (step.stepNumber == 2) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final filled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? Colors.amber : Colors.white24,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: DesignTokens.space3),

                    // Numeric keypad 1-9 & 0
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (int i = 1; i <= 9; i++)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              fixedSize: const Size(60, 48),
                              backgroundColor: Colors.blueGrey.shade800,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _pressPinDigit('$i'),
                            child: Text('$i', style: const TextStyle(fontSize: 18)),
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(60, 48),
                            backgroundColor: Colors.red.shade900,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _clearPin,
                          child: const Text('Clear', style: TextStyle(fontSize: 11)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(60, 48),
                            backgroundColor: Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _pressPinDigit('0'),
                          child: const Text('0', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  ],

                  // Cash amount selection on step 4
                  if (step.stepNumber == 4) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [20, 40, 60, 100].map((amount) {
                        final isSel = _selectedAtmAmount == amount;
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSel ? Colors.green : Colors.blueGrey.shade800,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedAtmAmount = amount;
                            });
                            ref
                                .read(preReaderAudioServiceProvider)
                                .speak('Selected $amount dollars.');
                          },
                          child: Text('\$$amount', style: const TextStyle(fontSize: 18)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space3),

            // Security tip
            Container(
              padding: const EdgeInsets.all(DesignTokens.space2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16),
                  const SizedBox(width: DesignTokens.space1),
                  Expanded(
                    child: Text(
                      'Security: ${step.securityTip}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _atmStepIndex + 1 < officialAtmSteps.length
                    ? 'Next ATM Action'
                    : 'Complete Withdrawal',
              ),
              onPressed: _advanceAtmStep,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyChangeContent(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('🧾', style: TextStyle(fontSize: 32)),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    'Verify Change: Practice Scenario',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Read scenario aloud',
                  onPressed: () {
                    ref.read(preReaderAudioServiceProvider).speak(
                        'Practice problem: You buy groceries for 14 dollars. You hand the cashier a 20 dollar bill. How much change should you get back? The answer is 6 dollars.');
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),

            Container(
              padding: const EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: const Column(
                children: [
                  Text('Item Cost: \$14.00', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('You Pay: \$20.00 bill (💵)', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Divider(),
                  SizedBox(height: 8),
                  Text('Your Correct Change: \$6.00',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  SizedBox(height: 4),
                  Text('One \$5 bill + One \$1 bill', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space4),

            FilledButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('Listen to Change Calculation'),
              onPressed: () {
                ref.read(preReaderAudioServiceProvider).speak(
                    'Start at 14 dollars. Count up: One dollar makes 15. Five dollars makes 20. Your change is 6 dollars.');
              },
            ),
          ],
        ),
      ),
    );
  }
}
