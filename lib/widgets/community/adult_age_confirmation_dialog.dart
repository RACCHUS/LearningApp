import 'package:flutter/material.dart';

/// Modal dialog confirming adult age eligibility (>= 18) before allowing public
/// or community contributions (ECO-00B, Invariant 3).
class AdultAgeConfirmationDialog extends StatefulWidget {
  const AdultAgeConfirmationDialog({super.key});

  /// Displays the adult age confirmation dialog. Returns true if confirmed.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AdultAgeConfirmationDialog(),
    );
    return result == true;
  }

  @override
  State<AdultAgeConfirmationDialog> createState() => _AdultAgeConfirmationDialogState();
}

class _AdultAgeConfirmationDialogState extends State<AdultAgeConfirmationDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Age Eligibility Confirmation')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Under our Child Safety & Minor Protection standards (Invariant 3), posting questions, sharing explanations, and community contributions are strictly restricted to adult learners aged 18 and older.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Learners under 18 have full access to study materials and vetted reference FAQs in private mode.',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('adult_age_checkbox'),
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              title: Text(
                'I attest that I am 18 years of age or older.',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              onChanged: (val) => setState(() => _confirmed = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('I am under 18 (Cancel)'),
        ),
        FilledButton(
          key: const Key('confirm_adult_button'),
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
