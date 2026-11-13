import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/reading_position_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/widgets/learning_support/bridge_lesson_view.dart';

/// The learning context help belongs to: the active context when it has a
/// safe ID, otherwise an explicit per-lesson key (master plan v2.6 §13.5
/// "use an explicit context key rather than a global singleton"). Help
/// never creates a new learning context.
final supportContextIdProvider = Provider.family<String?, String>((
  ref,
  lessonId,
) {
  try {
    final active = ref.watch(activeLearningContextProvider)?.id;
    if (SupportIdentifiers.isId(active)) return active;
  } catch (_) {}
  final fallback = 'lesson:$lessonId';
  return SupportIdentifiers.isId(fallback) ? fallback : null;
});

/// The learner's current Standard/Fast strategy, recorded in the anchor and
/// never changed by help.
final supportStrategyProvider = Provider<PersistedLearningStrategy>((ref) {
  try {
    return ref
        .read(learningStrategyProvider.notifier)
        .effectiveStrategyFor(
          context: ref.watch(activeLearningContextProvider),
          flags: ref.watch(telFeatureFlagsProvider),
        );
  } catch (_) {
    return PersistedLearningStrategy.standard;
  }
});

final supportOwnerScopeProvider = Provider<String>((ref) {
  try {
    return supportOwnerScope(ref.watch(learnerIdProvider));
  } catch (_) {
    return 'guest';
  }
});

/// Single "Learning help" entry for a lesson's top bar (master plan v2.6
/// §13.4: one subject-help affordance, distinct from product Help `?`).
///
/// Shown only when `learning.quick_rescue` is on, the lesson is in the
/// pilot, and the bundled library loaded. It also tidies a finished help
/// trail after a refresh, whether or not the flag is on.
class LearningHelpAction extends ConsumerStatefulWidget {
  const LearningHelpAction({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.tags,
  });

  final String lessonId;
  final String lessonTitle;
  final List<String> tags;

  @override
  ConsumerState<LearningHelpAction> createState() => _LearningHelpActionState();
}

class _LearningHelpActionState extends ConsumerState<LearningHelpAction> {
  bool _settled = false;

  SupportContextKey? _key() {
    final contextId = ref.read(supportContextIdProvider(widget.lessonId));
    if (contextId == null || !SupportIdentifiers.isId(widget.lessonId)) {
      return null;
    }
    return SupportContextKey(
      ownerScope: ref.read(supportOwnerScopeProvider),
      learningContextId: contextId,
    );
  }

  String? _currentBlock() {
    final block = ref.read(readingBlockProvider(widget.lessonId));
    return SupportIdentifiers.isId(block) ? block : null;
  }

  Future<void> _open(BridgeLibrary library) async {
    final key = _key();
    if (key == null) return;
    final bridge = await showSupportChoiceSheet(context, library);
    if (bridge == null || !mounted) return;
    await openBridgeFrom(
      context,
      ref,
      supportKey: key,
      origin: BridgeOrigin(
        lessonId: widget.lessonId,
        lessonTitle: widget.lessonTitle,
        strategy: ref.read(supportStrategyProvider),
        blockId: _currentBlock(),
      ),
      bridge: bridge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _key();
    if (key != null) {
      // Keep this route's controller alive while the lesson is open.
      ref.watch(learningSupportControllerProvider(key));
      if (!_settled) {
        _settled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(learningSupportControllerProvider(key).notifier)
              .settleAt('/lesson/${widget.lessonId}')
              .then((root) {
                final block = root?.blockId;
                if (mounted && block != null) {
                  ref
                          .read(
                            pendingReturnBlockProvider(
                              widget.lessonId,
                            ).notifier,
                          )
                          .state =
                      block;
                }
              });
        });
      }
    }

    final gateOn = ref.watch(quickRescueEnabledProvider);
    if (!gateOn || key == null || !isQuickRescuePilotLesson(widget.tags)) {
      return const SizedBox.shrink();
    }
    final library = ref.watch(bridgeLibraryProvider).valueOrNull;
    if (library == null || library.isEmpty) return const SizedBox.shrink();

    return IconButton(
      key: const Key('learning_help_action'),
      icon: const Icon(Icons.lightbulb_outline),
      tooltip: 'Learning help',
      onPressed: () => _open(library),
    );
  }
}

/// Lets the learner pick a Bridge, or close without choosing. Nothing is
/// opened automatically.
Future<BridgeLesson?> showSupportChoiceSheet(
  BuildContext context,
  BridgeLibrary library,
) {
  return showModalBottomSheet<BridgeLesson>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          key: const Key('support_choice_sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('Learning help', style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: 4),
              Text(
                'Short lessons that work without AI. '
                'Your place in this lesson is kept.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              for (final b in library.offerOrder)
                ListTile(
                  key: Key('support_choice_${b.bridgeId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.school_outlined),
                  title: Text(b.title),
                  subtitle: Text(
                    'About ${b.estimatedMinutes} min · practice only',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pop(b),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('support_choice_not_now'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
