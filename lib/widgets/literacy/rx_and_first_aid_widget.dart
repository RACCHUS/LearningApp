import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/health_safety_item.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Healthcare and First Aid activity tabs.
enum HealthActivitySection {
  rxLabel,
  askPharmacist,
  burnsAndFirstAid,
  call911Practice,
}

/// Interactive widget for prescription medicine label literacy, pharmacist
/// guidance, and emergency first aid.
class RxAndFirstAidWidget extends ConsumerStatefulWidget {
  const RxAndFirstAidWidget({super.key});

  @override
  ConsumerState<RxAndFirstAidWidget> createState() =>
      _RxAndFirstAidWidgetState();
}

class _RxAndFirstAidWidgetState extends ConsumerState<RxAndFirstAidWidget> {
  HealthActivitySection _section = HealthActivitySection.rxLabel;
  int _activeRxComponentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentActivity();
    });
  }

  void _switchSection(HealthActivitySection newSection) {
    setState(() {
      _section = newSection;
    });
    _announceCurrentActivity();
  }

  void _announceCurrentActivity() {
    final audio = ref.read(preReaderAudioServiceProvider);
    switch (_section) {
      case HealthActivitySection.rxLabel:
        final comp = officialRxLabelComponents[_activeRxComponentIndex];
        audio.speak('${comp.fieldName}. ${comp.spokenGuidance}');
      case HealthActivitySection.askPharmacist:
        audio.speak(
            'Ask Your Pharmacist Rule. Whenever you are confused about how to take medicine, take the bottle directly to the pharmacist.');
      case HealthActivitySection.burnsAndFirstAid:
        final burn = officialFirstAidGuidelines
            .firstWhere((g) => g.id == 'first_aid_burns');
        audio.speak('${burn.title}. ${burn.spokenProtocol}');
      case HealthActivitySection.call911Practice:
        final aid911 = officialFirstAidGuidelines
            .firstWhere((g) => g.id == 'first_aid_911');
        audio.speak('${aid911.title}. ${aid911.spokenProtocol}');
    }
  }

  void _selectRxComponent(int index) {
    setState(() {
      _activeRxComponentIndex = index;
    });
    final comp = officialRxLabelComponents[index];
    ref
        .read(preReaderAudioServiceProvider)
        .speak('${comp.fieldName}. ${comp.spokenGuidance}');
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
                label: '💊 Prescription (Rx) Label',
                section: HealthActivitySection.rxLabel,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '👨‍⚕️ Ask Your Pharmacist',
                section: HealthActivitySection.askPharmacist,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🚰 Burn Care (Never Ice)',
                section: HealthActivitySection.burnsAndFirstAid,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: DesignTokens.space2),
              _buildSectionChip(
                label: '🚨 Calling 911 Drill',
                section: HealthActivitySection.call911Practice,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Section Content
        switch (_section) {
          HealthActivitySection.rxLabel =>
            _buildRxLabelContent(theme, colorScheme),
          HealthActivitySection.askPharmacist =>
            _buildAskPharmacistContent(theme, colorScheme),
          HealthActivitySection.burnsAndFirstAid =>
            _buildBurnsContent(theme, colorScheme),
          HealthActivitySection.call911Practice =>
            _buildCall911Content(theme, colorScheme),
        },

        const SizedBox(height: DesignTokens.space4),

        // Medical Advice Disclaimer Banner
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
                  const Icon(Icons.medical_services_outlined, size: 16),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    'Medical Advice Disclaimer',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                medicalAdviceDisclaimer,
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
    required HealthActivitySection section,
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

  Widget _buildRxLabelContent(ThemeData theme, ColorScheme colorScheme) {
    final activeComp = officialRxLabelComponents[_activeRxComponentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontal list of components
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: officialRxLabelComponents.asMap().entries.map((entry) {
              final idx = entry.key;
              final comp = entry.value;
              final isSelected = idx == _activeRxComponentIndex;

              return Padding(
                padding: const EdgeInsets.only(right: DesignTokens.space2),
                child: FilterChip(
                  selected: isSelected,
                  avatar: Text(comp.iconEmoji, style: const TextStyle(fontSize: 16)),
                  label: Text(
                    comp.fieldName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  selectedColor: colorScheme.primary,
                  onSelected: (_) => _selectRxComponent(idx),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // Simulated Prescription Bottle Label Card
        Card(
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
                    Text(activeComp.iconEmoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeComp.fieldName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Sample: "${activeComp.sampleValue}"',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space3),

                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Text(
                    activeComp.purposeExplanation,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                FilledButton.icon(
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Listen to Guidance'),
                  onPressed: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak(activeComp.spokenGuidance);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAskPharmacistContent(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Column(
          children: [
            const Text('👨‍⚕️', style: TextStyle(fontSize: 54)),
            const SizedBox(height: DesignTokens.space2),
            Text(
              'The "Ask Your Pharmacist" Rule',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space2),
            const Text(
              'If you cannot read the label, or if you are ever unsure how many pills to take or when to take them, NEVER guess.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.space3),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Column(
                children: [
                  Text(
                    'What to Say to the Pharmacist:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '"Hello, please explain how I should take this medicine."',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            FilledButton.icon(
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Hear What to Say to Pharmacist'),
              onPressed: () {
                ref.read(preReaderAudioServiceProvider).speak(
                    'Take this bottle to the pharmacist and say: "Please explain how to take this." Pharmacists are happy to help you for free.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurnsContent(ThemeData theme, ColorScheme colorScheme) {
    final burn = officialFirstAidGuidelines
        .firstWhere((g) => g.id == 'first_aid_burns');

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
                const Text('🚰', style: TextStyle(fontSize: 32)),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    'Burn Care: Cool Running Tap Water',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Read burn protocol',
                  onPressed: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak(burn.spokenProtocol);
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space2),

            // DANGEROUS MYTH ALERT
            Container(
              padding: const EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚫🧊', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: Text(
                      'NEVER USE ICE: Ice damages burned skin tissue and causes hypothermia. Never put butter, toothpaste, or grease on a burn.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space3),

            // Step-by-step actions
            ...burn.actionSteps.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: DesignTokens.space1),
                  child: Text(
                    step,
                    style: theme.textTheme.bodyMedium,
                  ),
                )),
            const SizedBox(height: DesignTokens.space3),

            FilledButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('Listen to Burn Steps'),
              onPressed: () {
                ref.read(preReaderAudioServiceProvider).speak(
                    'Cool the burn with cool, gentle running tap water for 10 to 20 minutes. Never use ice or butter. Cover loosely with clean wrap.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCall911Content(ThemeData theme, ColorScheme colorScheme) {
    final aid911 = officialFirstAidGuidelines
        .firstWhere((g) => g.id == 'first_aid_911');

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
                const Text('🚨', style: TextStyle(fontSize: 32)),
                const SizedBox(width: DesignTokens.space2),
                Expanded(
                  child: Text(
                    'Calling 911: Emergency Drill',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Listen to 911 protocol',
                  onPressed: () {
                    ref
                        .read(preReaderAudioServiceProvider)
                        .speak(aid911.spokenProtocol);
                  },
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space2),
            Container(
              padding: const EdgeInsets.all(DesignTokens.space3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The 3 Questions Every Operator Asks:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text('1. "What is your exact location?" (Address or street)'),
                  Text('2. "What happened?" (Car accident, fire, unconscious)'),
                  Text('3. "Is the person breathing and awake?"'),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space3),
            FilledButton.icon(
              icon: const Icon(Icons.phone_in_talk),
              label: const Text('Practice 911 Conversation'),
              onPressed: () {
                ref.read(preReaderAudioServiceProvider).speak(
                    'Calling 911. Stay calm. The operator will ask: "What is your emergency?" Say your address first: "I am at 100 Main Street. Someone is hurt and needs an ambulance." Do not hang up until they tell you to.');
              },
            ),
          ],
        ),
      ),
    );
  }
}
