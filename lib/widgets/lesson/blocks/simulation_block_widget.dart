import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';

class SimulationBlockWidget extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;
  final bool previewEnabled;

  const SimulationBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
    this.previewEnabled = simulationPreviewEnabled,
  });

  String? get _simulationId =>
      block.content['simulation_id'] as String? ??
      block.content['id'] as String?;

  String? get _simulationVersion =>
      block.content['simulation_version'] as String? ??
      block.content['version'] as String?;

  String get _title =>
      block.content['title'] as String? ?? 'Interactive practice';

  bool get _hasSupportedActivity {
    final id = _simulationId;
    final version = _simulationVersion;
    return id != null &&
        version != null &&
        SimulationActivityRegistry.supports(id, version);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackBlock();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            MarkdownBlockWidget(
              block: fallback,
              fontSizeFactor: fontSizeFactor,
            ),
            if (previewEnabled &&
                _hasSupportedActivity &&
                _simulationId != null &&
                _simulationVersion != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('launch-simulation'),
                onPressed: () => context.push(
                  '/simulation/${Uri.encodeComponent(_simulationId!)}/'
                  '${Uri.encodeComponent(_simulationVersion!)}',
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open simulation'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  LessonBlock _fallbackBlock() {
    final fallbackBody =
        block.content['body'] as String? ??
        block.content['fallback_body'] as String? ??
        block.content['fallback'] as String? ??
        block.content['text'] as String? ??
        'Interactive practice is unavailable. Review the lesson material and continue.';
    return block.copyWith(
      blockType: LessonBlockType.markdown,
      content: {'body': fallbackBody},
    );
  }
}
