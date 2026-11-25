import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';

/// Label shown on every performance task: the learner checks their own work,
/// so it is never presented as verified (ingestion plan v1.2 §8.8, D-16).
const performanceTaskSelfCheckNote =
    'Self-checked against a published rubric. It isn\'t independently '
    'verified, so it doesn\'t count toward readiness or award skills.';

/// One rubric criterion: what good work shows, and how to check it.
class PerformanceTaskCriterion {
  final String id;
  final String text;
  final String? howToCheck;

  const PerformanceTaskCriterion({
    required this.id,
    required this.text,
    this.howToCheck,
  });
}

/// A hands-on task with a published rubric and an exemplar.
///
/// The learner does the work in the real application, then ticks each
/// criterion they have checked. Ticks stay on this screen: nothing is sent
/// to the server, scored or recorded as evidence. A block without a usable
/// rubric falls back to its markdown `body`, as older app versions do.
class PerformanceTaskBlockWidget extends StatefulWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const PerformanceTaskBlockWidget({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  static List<PerformanceTaskCriterion> criteriaOf(LessonBlock block) {
    final raw = block.content['criteria'];
    if (raw is! List) return const [];
    final out = <PerformanceTaskCriterion>[];
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c is! Map) continue;
      final text = (c['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      final how = (c['how_to_check'] as String?)?.trim();
      out.add(PerformanceTaskCriterion(
        id: (c['id'] as String?) ?? 'criterion-$i',
        text: text,
        howToCheck: how == null || how.isEmpty ? null : how,
      ));
    }
    return out;
  }

  @override
  State<PerformanceTaskBlockWidget> createState() =>
      _PerformanceTaskBlockWidgetState();
}

class _PerformanceTaskBlockWidgetState
    extends State<PerformanceTaskBlockWidget> {
  final Set<String> _met = {};

  String? _text(String key) {
    final v = widget.block.content[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  Widget _markdown(String body) => MarkdownBlockWidget(
        block: widget.block.copyWith(
          blockType: LessonBlockType.markdown,
          content: {'body': body},
        ),
        fontSizeFactor: widget.fontSizeFactor,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final criteria = PerformanceTaskBlockWidget.criteriaOf(widget.block);
    final title = _text('title') ?? 'Hands-on task';
    final body = _text('body');
    final brief = _text('brief');

    if (criteria.length < 2 || brief == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _markdown(body ?? brief ?? 'This task is unavailable. Continue with the lesson.'),
            ],
          ),
        ),
      );
    }

    final deliverable = _text('deliverable');
    final exemplar = _text('exemplar');
    final allMet = _met.length == criteria.length;

    return Card(
      key: const Key('performance-task'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.construction_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Hands-on task · self-checked',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _markdown(brief),
            if (deliverable != null) ...[
              const SizedBox(height: 8),
              Text('What you\'ll make', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              _markdown(deliverable),
            ],
            const SizedBox(height: 12),
            Text('Check your work', style: theme.textTheme.titleSmall),
            for (final c in criteria)
              CheckboxListTile(
                key: Key('criterion-${c.id}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _met.contains(c.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _met.add(c.id);
                  } else {
                    _met.remove(c.id);
                  }
                }),
                title: Text(c.text),
                subtitle: c.howToCheck == null ? null : Text(c.howToCheck!),
              ),
            Semantics(
              liveRegion: true,
              child: Text(
                allMet
                    ? 'Your work meets every criterion in this rubric.'
                    : '${_met.length} of ${criteria.length} criteria checked',
                key: const Key('performance-task-progress'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: allMet ? theme.colorScheme.primary : null,
                  fontWeight: allMet ? FontWeight.w600 : null,
                ),
              ),
            ),
            if (exemplar != null)
              ExpansionTile(
                key: const Key('performance-task-exemplar'),
                tilePadding: EdgeInsets.zero,
                title: const Text('See an example that meets the rubric'),
                children: [_markdown(exemplar)],
              ),
            const SizedBox(height: 8),
            Text(
              performanceTaskSelfCheckNote,
              key: const Key('performance-task-note'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
