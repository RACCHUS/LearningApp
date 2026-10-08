import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/help/help_center_sheet.dart';

class HelpAction extends StatelessWidget {
  const HelpAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Help',
      child: IconButton(
        key: const Key('help-action'),
        tooltip: 'Help',
        onPressed: () => showHelpCenter(context),
        icon: const Icon(Icons.help_outline),
      ),
    );
  }
}
