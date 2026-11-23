import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_strategy_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/reading_position_provider.dart';
import 'package:learning_pwa/providers/rescue_candidates_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/gap_signal_service.dart';
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
/// Shown only when `learning.quick_rescue` is on, the bundled library
/// loaded, and a Bridge applies to one of the lesson's tags or another
/// published lesson shares its topic (rescue candidate search, §4.2 and
/// §10.0). It also tidies a finished help
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

  /// A dismissible suggestion from this lesson's own practice answers, when
  /// both `learning.quick_rescue` and `learning.auto_gap_suggestions` are
  /// on. Never opened automatically.
  GapSuggestion? _suggestion(BridgeLibrary library, SupportContextKey key) {
    if (!ref.watch(autoGapSuggestionsEnabledProvider)) return null;
    final controller = ref.read(
      learningSupportControllerProvider(key).notifier,
    );
    return GapSignalService.proposeForLesson(
      firstAnswers: ref.watch(lessonPracticeAttemptsProvider(widget.lessonId)),
      library: library,
      dismissed: ref.watch(lessonGapDismissedProvider(widget.lessonId)),
      canOpen: controller.canOpen,
    );
  }

  Future<void> _open(
    BridgeLibrary library,
    GapSuggestion? suggestion,
    List<RescueCandidate> candidates,
  ) async {
    final key = _key();
    if (key == null) return;
    final router = GoRouter.maybeOf(context);
    final bridge = await showSupportChoiceSheet(
      context,
      library,
      suggestion: suggestion,
      candidates: candidates,
      // Another lesson opens on top; Back returns here, where the reading
      // position is kept.
      onOpenLesson: router == null
          ? null
          : (c) => router.push('/lesson/${c.lessonId}'),
      onAskForIt: router == null ? null : () => router.push('/community/wanted'),
      onNotTheIssue: suggestion == null
          ? null
          : () {
              final d = ref.read(
                lessonGapDismissedProvider(widget.lessonId).notifier,
              );
              d.state = {...d.state, suggestion.prerequisite.bridgeId};
            },
    );
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
    if (!gateOn || key == null) return const SizedBox.shrink();
    // Only Bridges for this lesson's topics (and what they build on), and
    // other published lessons on the same topic; with neither, no button.
    final library = ref
        .watch(bridgeLibraryProvider)
        .valueOrNull
        ?.forLesson(widget.tags);
    final candidates =
        ref.watch(rescueCandidatesProvider(widget.lessonId)).valueOrNull ??
            const <RescueCandidate>[];
    if (library == null || (library.isEmpty && candidates.isEmpty)) {
      return const SizedBox.shrink();
    }

    final suggestion = _suggestion(library, key);
    return IconButton(
      key: const Key('learning_help_action'),
      icon: Badge(
        key: const Key('learning_help_suggestion_dot'),
        isLabelVisible: suggestion != null,
        smallSize: 8,
        child: const Icon(Icons.lightbulb_outline),
      ),
      tooltip: suggestion == null
          ? 'Learning help'
          : 'Learning help (a suggestion is waiting)',
      onPressed: () => _open(library, suggestion, candidates),
    );
  }
}

/// Lets the learner pick a Bridge, or close without choosing. Nothing is
/// opened automatically.
///
/// With [suggestion], a dismissible suggestion is shown first, with its
/// plain reason; "Not the issue" calls [onNotTheIssue] and closes.
Future<BridgeLesson?> showSupportChoiceSheet(
  BuildContext context,
  BridgeLibrary library, {
  GapSuggestion? suggestion,
  VoidCallback? onNotTheIssue,
  List<RescueCandidate> candidates = const [],
  void Function(RescueCandidate)? onOpenLesson,
  VoidCallback? onAskForIt,
}) {
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
              if (suggestion != null)
                Card(
                  key: const Key('support_lesson_suggestion'),
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suggestion: ${suggestion.reason}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonal(
                              key: const Key('support_lesson_suggestion_open'),
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(suggestion.prerequisite),
                              child: const Text('Open it'),
                            ),
                            TextButton(
                              key: const Key(
                                'support_lesson_suggestion_not_the_issue',
                              ),
                              onPressed: () {
                                onNotTheIssue?.call();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Not the issue'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
              if (library.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'There is no short lesson for this topic yet.',
                    key: const Key('support_choice_no_bridge'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (candidates.isNotEmpty && onOpenLesson != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(
                    'Other lessons on this topic',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                for (final c in candidates)
                  ListTile(
                    key: Key('support_candidate_${c.lessonId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(c.title),
                    subtitle: Text(c.summary),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenLesson(c);
                    },
                  ),
              ],
              if (library.isEmpty && onAskForIt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('support_choice_ask_for_it'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onAskForIt();
                    },
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Ask for a short lesson'),
                  ),
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
