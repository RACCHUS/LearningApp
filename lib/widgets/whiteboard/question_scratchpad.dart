import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/scratchpad_provider.dart';
import 'package:learning_pwa/widgets/whiteboard/whiteboard_widget.dart';

/// Collapsed "Scratchpad" section shown below a question when the
/// `learning.scratchpad` gate is ON and the learner opted in. Renders
/// nothing otherwise, so the study screen is unchanged by default (§5.6).
///
/// Temporary by design: give it a key per question so each question starts
/// with a blank pad. Nothing is stored or uploaded.
///
/// Question renderers are also used outside a ProviderScope (they are plain
/// widgets); there the scratchpad simply renders nothing.
class QuestionScratchpad extends StatelessWidget {
  const QuestionScratchpad({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return const SizedBox.shrink();
    }
    return const _ScratchpadSection();
  }
}

class _ScratchpadSection extends ConsumerWidget {
  const _ScratchpadSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showQuestionScratchpadProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        key: const PageStorageKey('question-scratchpad'),
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.draw_outlined),
        title: const Text('Scratchpad'),
        subtitle: const Text('For working things out. Not saved; use Download to keep a copy.'),
        children: const [
          WhiteboardWidget(height: 280),
        ],
      ),
    );
  }
}
