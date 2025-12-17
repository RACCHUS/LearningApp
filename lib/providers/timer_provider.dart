import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:learning_pwa/core/logging/app_logger.dart';

enum TimerMode { countdown, stopwatch }

class TimerState {
  final bool enabled;
  final bool running;
  final int durationSeconds;
  final int timeLeftSeconds;
  final int elapsedSeconds;
  final TimerMode mode;

  TimerState({
    required this.enabled,
    required this.running,
    required this.durationSeconds,
    required this.timeLeftSeconds,
    required this.elapsedSeconds,
    required this.mode,
  });

  TimerState copyWith({
    bool? enabled,
    bool? running,
    int? durationSeconds,
    int? timeLeftSeconds,
    int? elapsedSeconds,
    TimerMode? mode,
  }) {
    return TimerState(
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      mode: mode ?? this.mode,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  final _logger = AppLogger('TimerNotifier');

  TimerNotifier()
      : super(TimerState(
          enabled: false,
          running: false,
          durationSeconds: 600,
          timeLeftSeconds: 600,
          elapsedSeconds: 0,
          mode: TimerMode.countdown,
        ));

  Timer? _timer;

  void toggleEnabled(bool value) {
    state = state.copyWith(enabled: value);
    if (!value) {
      pause();
      reset();
    }
  }

  void setDuration(int seconds) {
    state = state.copyWith(durationSeconds: seconds, timeLeftSeconds: seconds);
  }

  void setMode(TimerMode mode) {
    pause();
    if (mode == TimerMode.countdown) {
      state = state.copyWith(
          mode: mode,
          timeLeftSeconds: state.durationSeconds,
          elapsedSeconds: 0);
    } else {
      state = state.copyWith(
          mode: mode,
          elapsedSeconds: 0,
          timeLeftSeconds: state.durationSeconds);
    }
  }

  void start() {
    if (!state.enabled || state.running) return;
    state = state.copyWith(running: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        if (state.mode == TimerMode.countdown) {
          if (state.timeLeftSeconds > 0) {
            state = state.copyWith(timeLeftSeconds: state.timeLeftSeconds - 1);
          } else {
            pause();
            _logger.info('Timer completed');
          }
        } else {
          state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
        }
      } catch (e, stackTrace) {
        _logger.error(
          'Timer tick failed',
          error: e,
          stackTrace: stackTrace,
        );
        // Timer continues despite error - don't crash the periodic callback
      }
    });
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(running: false);
  }

  void resume() {
    if (!state.enabled || state.running) return;
    start();
  }

  void reset() {
    pause();
    if (state.mode == TimerMode.countdown) {
      state = state.copyWith(
          timeLeftSeconds: state.durationSeconds, elapsedSeconds: 0);
    } else {
      state = state.copyWith(elapsedSeconds: 0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) => TimerNotifier());
