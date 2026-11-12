import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/widgets/learning_support/bridge_check_card.dart';
import 'package:uuid/uuid.dart';

/// Route name shared by every Bridge screen, so "Back to the start" can pop
/// exactly the help screens and nothing else.
const bridgeRouteName = 'learning-support-bridge';

/// What the learner was doing when help opened.
class BridgeOrigin {
  const BridgeOrigin({
    required this.lessonId,
    required this.lessonTitle,
    required this.strategy,
  });

  final String lessonId;
  final String lessonTitle;
  final PersistedLearningStrategy strategy;

  String get route => '/lesson/$lessonId';
}

/// Captures an anchor, saves it, then shows [bridge]. Returns the outcome
/// so the caller can explain a refusal.
Future<BridgeOpenOutcome> openBridgeFrom(
  BuildContext context,
  WidgetRef ref, {
  required SupportContextKey supportKey,
  required BridgeOrigin origin,
  required BridgeLesson bridge,
  BridgeLesson? leaving,
}) async {
  final anchor = ReturnAnchor(
    learningContextId: supportKey.learningContextId,
    rootType: leaving == null
        ? ReturnAnchorRootType.lesson
        : ReturnAnchorRootType.concept,
    rootId: leaving?.conceptId ?? origin.lessonId,
    originRoute: origin.route,
    lessonId: origin.lessonId,
    blockId: leaving?.bridgeId,
    activeLearningStrategy: origin.strategy,
    originActivityStateRevision: 0,
    rescueSessionId: const Uuid().v4(),
    createdAt: DateTime.now(),
  );
  final outcome = await ref
      .read(learningSupportControllerProvider(supportKey).notifier)
      .openBridge(bridge, anchor);
  if (outcome == BridgeOpenOutcome.opened && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: bridgeRouteName),
        builder: (_) => BridgeLessonView(
          bridge: bridge,
          supportKey: supportKey,
          origin: origin,
        ),
      ),
    );
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (outcome) {
          BridgeOpenOutcome.gateOff => 'Learning help is not available now.',
          BridgeOpenOutcome.depthLimit =>
            'That is as many steps back as help goes. '
                'Go back and try another route.',
          BridgeOpenOutcome.cycle =>
            'That topic is already open. Go back to it.',
          _ => 'This help could not be opened.',
        }),
      ),
    );
  }
  return outcome;
}

/// A no-AI prerequisite lesson shown over the learner's activity (master
/// plan v2.6 §10.0). "Back" is always visible and never depends on the
/// `learning.quick_rescue` flag; only opening *more* help does.
class BridgeLessonView extends ConsumerStatefulWidget {
  const BridgeLessonView({
    super.key,
    required this.bridge,
    required this.supportKey,
    required this.origin,
  });

  final BridgeLesson bridge;
  final SupportContextKey supportKey;
  final BridgeOrigin origin;

  @override
  ConsumerState<BridgeLessonView> createState() => _BridgeLessonViewState();
}

class _BridgeLessonViewState extends ConsumerState<BridgeLessonView> {
  bool _leaving = false;

  /// This screen's position in the help trail (1 = opened from the lesson).
  /// Screens underneath keep their own position while covered.
  late final int _depth = ref
      .read(learningSupportControllerProvider(widget.supportKey))
      .stack
      .depth;

  BridgeLesson get _bridge => widget.bridge;

  Future<void> _goBack() async {
    if (_leaving) return;
    _leaving = true;
    await ref
        .read(learningSupportControllerProvider(widget.supportKey).notifier)
        .returnFromTop();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _backToStart() async {
    if (_leaving) return;
    _leaving = true;
    await ref
        .read(learningSupportControllerProvider(widget.supportKey).notifier)
        .returnToRoot();
    if (mounted) {
      Navigator.of(
        context,
      ).popUntil((route) => route.settings.name != bridgeRouteName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(
      learningSupportControllerProvider(widget.supportKey),
    );
    final controller = ref.read(
      learningSupportControllerProvider(widget.supportKey).notifier,
    );
    final gateOn = ref.watch(quickRescueEnabledProvider);
    final library = ref.watch(bridgeLibraryProvider).valueOrNull;

    // Where "Back" goes: the Bridge we came from, or the original lesson.
    final entries = state.stack.entries;
    final leftBridgeId = _depth >= 1 && _depth <= entries.length
        ? entries[_depth - 1].anchor.blockId
        : null;
    final backTitle = leftBridgeId != null
        ? (library?[leftBridgeId]?.title ?? 'the previous step')
        : widget.origin.lessonTitle;
    final nested = _depth > 1;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleMedium),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('bridge-back-action'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to $backTitle',
            onPressed: _goBack,
          ),
          title: Text(_bridge.title, overflow: TextOverflow.ellipsis),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              key: const Key('bridge-return-banner'),
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Short help lesson · works without AI · '
                      'about ${_bridge.estimatedMinutes} min. '
                      'Your place in "${widget.origin.lessonTitle}" is kept.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    if (!state.persisted)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Couldn't save your place on this device. "
                          'Back still works here.',
                          key: const Key('bridge-not-persisted'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (nested)
                      TextButton.icon(
                        key: const Key('bridge-back-to-start'),
                        onPressed: _backToStart,
                        icon: const Icon(Icons.keyboard_double_arrow_left),
                        label: Text('Back to "${widget.origin.lessonTitle}"'),
                      ),
                  ],
                ),
              ),
            ),
            section('Goal'),
            Text(_bridge.objectiveStatement, style: theme.textTheme.bodyLarge),
            section('Learn'),
            for (final b in _bridge.teach)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(b.text, style: theme.textTheme.bodyLarge),
              ),
            section('Examples'),
            for (final b in _bridge.examples)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(b.text, style: theme.textTheme.bodyLarge),
                ),
              ),
            if (_bridge.alternateExplanations.isNotEmpty)
              ExpansionTile(
                key: const Key('bridge-explain-differently'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Explain it another way'),
                children: [
                  for (final b in _bridge.alternateExplanations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(b.text, style: theme.textTheme.bodyLarge),
                    ),
                ],
              ),
            section('Check your understanding'),
            Text(
              'Practice only: these answers are not saved as progress.',
              key: const Key('bridge-practice-only'),
              style: theme.textTheme.bodySmall,
            ),
            for (final (i, c) in _bridge.checks.indexed)
              BridgeCheckCard(check: c, index: i),
            if (_bridge.buildsOn.isNotEmpty) ...[
              section('Need a step back?'),
              if (!gateOn)
                Text(
                  'More help is turned off right now. '
                  'You can still go back.',
                  key: const Key('bridge-more-help-off'),
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final dep in _bridge.buildsOn)
                  if (library?[dep] case final prereq?)
                    OutlinedButton.icon(
                      key: Key('bridge-prereq-$dep'),
                      onPressed: controller.canOpen(prereq)
                          ? () => openBridgeFrom(
                              context,
                              ref,
                              supportKey: widget.supportKey,
                              origin: widget.origin,
                              bridge: prereq,
                              leaving: _bridge,
                            )
                          : null,
                      icon: const Icon(Icons.school_outlined),
                      label: Text(prereq.title),
                    ),
            ],
            section('Sources (links only)'),
            for (final s in _bridge.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.publisher}: ${s.title}'
                      '${s.section == null ? '' : ', ${s.section}'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    SelectableText(s.url, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            if (!_bridge.evidence.humanReviewed)
              Text(
                'Not yet reviewed by a person. Answers are checked '
                'automatically.',
                key: const Key('bridge-not-reviewed'),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 24),
            Text(_bridge.returnCue, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('bridge-return-button'),
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back),
              label: Text('Back to "$backTitle"'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
