import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Interactive Personal Identification Form Practice Widget
///
/// Empowers non-literate learners to recognize, type, and orally spell
/// their own essential personal data:
/// - First Name (and letter-by-letter verbal spelling)
/// - Last Name
/// - Street Address
/// - Phone Number
class PersonalIdFormWidget extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  const PersonalIdFormWidget({super.key, this.onSaved});

  @override
  ConsumerState<PersonalIdFormWidget> createState() =>
      _PersonalIdFormWidgetState();
}

class _PersonalIdFormWidgetState extends ConsumerState<PersonalIdFormWidget> {
  late ConfettiController _confettiController;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _speakFieldPrompt(String fieldName, String explanation) async {
    final notifier = ref.read(preReaderProvider.notifier);
    await notifier.speak('$fieldName. $explanation');
  }

  Future<void> _spellNameAloud(String name) async {
    if (name.trim().isEmpty) {
      await ref.read(preReaderProvider.notifier).speak(
            'Type your first name in the box, then tap the speaker to hear it spelled.',
          );
      return;
    }

    final trimmed = name.trim().toUpperCase();
    final letters = trimmed.split('').join(' ... ');
    await ref.read(preReaderProvider.notifier).speak(
          'Your name is $name. Spelled: $letters. $name.',
        );
  }

  void _finishPractice() {
    _confettiController.play();
    ref.read(preReaderProvider.notifier).speak(
          'Great job practicing your personal form! You are ready to identify yourself on official papers.',
        );
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 28),
                        const SizedBox(width: DesignTokens.space2),
                        Text(
                          'My Name & Info',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Read form instructions aloud',
                      onPressed: () => ref.read(preReaderProvider.notifier).speak(
                            'Practice filling out your personal information form. Tap the speaker next to any box to hear instructions.',
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),

                // First Name Field
                _buildFieldRow(
                  context: context,
                  label: 'First Name',
                  hint: 'e.g., Maria, John',
                  controller: _firstNameCtrl,
                  icon: Icons.person_outline,
                  audioPrompt: 'Your first name. Like Maria or John.',
                  extraAction: IconButton(
                    icon: const Icon(Icons.spellcheck),
                    tooltip: 'Hear name spelled letter-by-letter',
                    onPressed: () => _spellNameAloud(_firstNameCtrl.text),
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                // Last Name Field
                _buildFieldRow(
                  context: context,
                  label: 'Last Name (Family Name)',
                  hint: 'e.g., Rodriguez, Smith',
                  controller: _lastNameCtrl,
                  icon: Icons.family_restroom_outlined,
                  audioPrompt: 'Your family name or last name.',
                ),
                const SizedBox(height: DesignTokens.space3),

                // Street Address Field
                _buildFieldRow(
                  context: context,
                  label: 'Street Address',
                  hint: 'e.g., 123 Main Street',
                  controller: _addressCtrl,
                  icon: Icons.home_outlined,
                  audioPrompt: 'Where you live. House number and street name.',
                ),
                const SizedBox(height: DesignTokens.space3),

                // Phone Number Field
                _buildFieldRow(
                  context: context,
                  label: 'Phone Number',
                  hint: 'e.g., (555) 123-4567',
                  controller: _phoneCtrl,
                  icon: Icons.phone_outlined,
                  audioPrompt: 'Your telephone number with area code.',
                ),
                const SizedBox(height: DesignTokens.space5),

                // Complete Action
                Center(
                  child: FilledButton.icon(
                    key: const Key('personal-id-submit-btn'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.space6,
                        vertical: DesignTokens.space3,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'I Finished My Form',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _finishPractice,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Confetti celebration
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 20,
          gravity: 0.3,
        ),
      ],
    );
  }

  Widget _buildFieldRow({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required String audioPrompt,
    Widget? extraAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space3,
        vertical: DesignTokens.space2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(icon, color: colorScheme.primary),
            tooltip: 'Listen to $label prompt',
            onPressed: () => _speakFieldPrompt(label, audioPrompt),
          ),
          const SizedBox(width: DesignTokens.space2),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: label,
                hintText: hint,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (extraAction != null) extraAction,
        ],
      ),
    );
  }
}
