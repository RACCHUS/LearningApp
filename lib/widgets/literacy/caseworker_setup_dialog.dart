import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pre_reader_profile.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Tutor & Caseworker assisted setup modal for shared devices and community labs.
///
/// Adheres to Section 5.5 of the Literacy Accessibility Plan:
/// - Allows caseworkers and adult literacy tutors in community centers, libraries,
///   and refugee resettlement programs to configure student settings on shared tablets:
///   - Learner track selection (Adult Life Skills vs Young Learner)
///   - Speech cadence and rate adjustment (0.75x to 1.1x)
///   - Automatic speech toggle
///   - One-tap session reset for a new incoming student
/// - Protected by simple tutor passcode PIN (default: '1234') or direct administrator access.
class CaseworkerSetupDialog extends ConsumerStatefulWidget {
  final VoidCallback? onResetStudentState;

  const CaseworkerSetupDialog({super.key, this.onResetStudentState});

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onResetStudentState,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CaseworkerSetupDialog(
        onResetStudentState: onResetStudentState,
      ),
    );
  }

  @override
  ConsumerState<CaseworkerSetupDialog> createState() =>
      _CaseworkerSetupDialogState();
}

class _CaseworkerSetupDialogState extends ConsumerState<CaseworkerSetupDialog> {
  final _pinController = TextEditingController();
  bool _isUnlocked = false;
  String? _errorMessage;

  static const String _defaultPasscode = '1234';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    if (_pinController.text.trim() == _defaultPasscode) {
      setState(() {
        _isUnlocked = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Default tutor PIN is 1234.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);
    final notifier = ref.read(preReaderProvider.notifier);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space5),
          child: _isUnlocked
              ? _buildUnlockedContent(theme, colorScheme, profile, notifier)
              : _buildPinLockView(theme, colorScheme),
        ),
      ),
    );
  }

  Widget _buildPinLockView(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 28),
            const SizedBox(width: DesignTokens.space2),
            Expanded(
              child: Text(
                'Caseworker / Tutor Setup',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space2),
        Text(
          'Enter tutor PIN to configure shared device settings for community labs and adult education.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),

        TextField(
          key: const Key('caseworker-pin-input'),
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Tutor PIN (Default: 1234)',
            errorText: _errorMessage,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.pin),
          ),
          onSubmitted: (_) => _verifyPin(),
        ),
        const SizedBox(height: DesignTokens.space4),

        FilledButton(
          key: const Key('caseworker-unlock-button'),
          onPressed: _verifyPin,
          child: const Text('Unlock Settings'),
        ),
      ],
    );
  }

  Widget _buildUnlockedContent(
    ThemeData theme,
    ColorScheme colorScheme,
    PreReaderProfile profile,
    PreReaderNotifier notifier,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.indigo, size: 28),
            const SizedBox(width: DesignTokens.space2),
            Expanded(
              child: Text(
                'Shared Device Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(height: DesignTokens.space4),

        // Pre-Reader Mode Enable / Disable Switch
        SwitchListTile(
          key: const Key('caseworker-pre-reader-toggle'),
          title: const Text('Pre-Reader Accessibility Mode'),
          subtitle: const Text('Enables audio-first guidance and visual tiles'),
          value: profile.enabled,
          onChanged: (val) {
            if (val) {
              notifier.enable(profile.track);
            } else {
              notifier.disable();
            }
          },
        ),
        const SizedBox(height: DesignTokens.space2),

        // Learner Track Selector
        Text(
          'Learner Track',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: DesignTokens.space1),
        SegmentedButton<PreReaderTrack>(
          key: const Key('caseworker-track-selector'),
          segments: const [
            ButtonSegment(
              value: PreReaderTrack.adult,
              icon: Icon(Icons.work_outline),
              label: Text('Adult Life Skills'),
            ),
            ButtonSegment(
              value: PreReaderTrack.youth,
              icon: Icon(Icons.school_outlined),
              label: Text('Young Learner'),
            ),
          ],
          selected: {profile.track},
          onSelectionChanged: (set) {
            notifier.setTrack(set.first);
          },
        ),
        const SizedBox(height: DesignTokens.space3),

        // Auto-Speak Toggle
        SwitchListTile(
          key: const Key('caseworker-autospeak-toggle'),
          title: const Text('Auto-Speak Screens on Open'),
          subtitle: const Text('Reads instructions automatically when navigating'),
          value: profile.autoSpeakScreens,
          onChanged: (_) => notifier.toggleAutoSpeak(),
        ),
        const SizedBox(height: DesignTokens.space4),

        // Reset Student Session State
        OutlinedButton.icon(
          key: const Key('caseworker-reset-student-button'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            side: BorderSide(color: Colors.red.shade300),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Reset Session for New Student'),
          onPressed: () {
            notifier.enable(PreReaderTrack.adult);
            widget.onResetStudentState?.call();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session reset! Ready for incoming student.'),
              ),
            );
          },
        ),
      ],
    );
  }
}
