import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_pwa/providers/timer_provider.dart';

/// Full-screen break prompt shown while the Pomodoro timer is on a break.
///
/// Self-managing: renders nothing unless [TimerState.isOnBreak] is true, so it
/// can be dropped into a study screen's [Stack] without extra guards.
class BreakOverlay extends ConsumerWidget {
  const BreakOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnBreak = ref.watch(timerProvider.select((s) => s.isOnBreak));
    if (!isOnBreak) {
      return const SizedBox.shrink();
    }

    return const Positioned.fill(
      child: _BreakContent(),
    );
  }
}

class _BreakContent extends ConsumerWidget {
  const _BreakContent();

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final secondsLeft =
        ref.watch(timerProvider.select((s) => s.breakTimeLeftSeconds));
    final blocks = ref.watch(timerProvider.select((s) => s.blocksCompleted));

    return Semantics(
      liveRegion: true,
      label: 'Break time. ${_format(secondsLeft)} remaining.',
      child: ColoredBox(
        color: theme.colorScheme.surface.withValues(alpha: 0.97),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.self_improvement,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Nice work!',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  blocks == 1
                      ? 'Take a short break — you have earned it.'
                      : "Take a short break — that's $blocks blocks done.",
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  _format(secondsLeft),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      ref.read(timerProvider.notifier).skipBreak(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
