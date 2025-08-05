import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timer_provider.dart';

class TimerWidget extends ConsumerWidget {
  const TimerWidget({Key? key}) : super(key: key);

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Timer enable/disable moved to AppBar
        if (timerState.enabled) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Countdown'),
              Switch(
                value: timerState.mode == TimerMode.stopwatch,
                onChanged: (v) => timerNotifier.setMode(v ? TimerMode.stopwatch : TimerMode.countdown),
              ),
              const Text('Stopwatch'),
            ],
          ),
          Text(
            timerState.mode == TimerMode.countdown
                ? _formatTime(timerState.timeLeftSeconds)
                : _formatTime(timerState.elapsedSeconds),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (timerState.mode == TimerMode.countdown)
            Slider(
              value: timerState.durationSeconds.toDouble(),
              min: 60,
              max: 3600,
              divisions: 59,
              label: '${timerState.durationSeconds ~/ 60} min',
              onChanged: timerState.running
                  ? null
                  : (v) => timerNotifier.setDuration(v.toInt()),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: timerState.running
                    ? timerNotifier.pause
                    : timerNotifier.start,
                child: Text(timerState.running ? 'Pause' : 'Start'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: timerNotifier.reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
