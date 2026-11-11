import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/help/help_center_sheet.dart';

/// Prominent Help entry for learners who cannot decode a small '?' toolbar icon.
/// Keep this in the scrollable content rather than crowding the literacy AppBar.
class SpokenHelpEntry extends StatelessWidget {
  const SpokenHelpEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.tonalIcon(
        key: const Key('spoken-help-entry'),
        onPressed: () => showHelpCenter(context),
        icon: const Icon(Icons.help_outline_rounded, size: 34),
        label: const Text(
          '🖼️ 🔊 Picture and sound help',
          textAlign: TextAlign.center,
        ),
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
