import 'package:flutter/material.dart';
import 'package:learning_pwa/l10n/app_localizations.dart';
import 'package:learning_pwa/widgets/help/help_center_sheet.dart';

class HelpAction extends StatelessWidget {
  const HelpAction({super.key});

  @override
  Widget build(BuildContext context) {
    final helpLabel = AppLocalizations.of(context)?.actionHelp ?? 'Help';
    return Tooltip(
      message: helpLabel,
      excludeFromSemantics: true,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          label: helpLabel,
          child: IconButton(
            key: const Key('help-action'),
            onPressed: () => showHelpCenter(context),
            icon: const Icon(Icons.help_outline),
          ),
        ),
      ),
    );
  }
}
