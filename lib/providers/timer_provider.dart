import 'package:flutter/foundation.dart';
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

  // --- Pomodoro break system ---
  /// Whether a short break is offered after each completed work block.
  final bool breakEnabled;

  /// Length of the break, in seconds.
  final int breakDurationSeconds;

  /// True while the user is in a break (work timer paused).
  final bool isOnBreak;

  /// Seconds remaining in the current break.
  final int breakTimeLeftSeconds;

  /// Number of completed work blocks in this session.
  final int blocksCompleted;

  TimerState({
    required this.enabled,
    required this.running,
    required this.durationSeconds,
    required this.timeLeftSeconds,
    required this.elapsedSeconds,
    required this.mode,
    this.breakEnabled = false,
    this.breakDurationSeconds = 300,
    this.isOnBreak = false,
    this.breakTimeLeftSeconds = 0,
    this.blocksCompleted = 0,
  });

  TimerState copyWith({
    bool? enabled,
    bool? running,
    int? durationSeconds,
    int? timeLeftSeconds,
    int? elapsedSeconds,
    TimerMode? mode,
    bool? breakEnabled,
    int? breakDurationSeconds,
    bool? isOnBreak,
    int? breakTimeLeftSeconds,
    int? blocksCompleted,
  }) {
    return TimerState(
      enabled: enabled ?? this.enabled,
      running: running ?? this.running,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      mode: mode ?? this.mode,
      breakEnabled: breakEnabled ?? this.breakEnabled,
      breakDurationSeconds: breakDurationSeconds ?? this.breakDurationSeconds,
      isOnBreak: isOnBreak ?? this.isOnBreak,
      breakTimeLeftSeconds: breakTimeLeftSeconds ?? this.breakTimeLeftSeconds,
      blocksCompleted: blocksCompleted ?? this.blocksCompleted,
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

  /// Enable/disable the Pomodoro break system and set the break length.
  void setBreak({bool? enabled, int? durationSeconds}) {
    state = state.copyWith(
      breakEnabled: enabled ?? state.breakEnabled,
      breakDurationSeconds: durationSeconds ?? state.breakDurationSeconds,
    );
  }

  /// End the current break early and resume the next work block.
  void skipBreak() {
    if (!state.isOnBreak) return;
    state = state.copyWith(
      isOnBreak: false,
      breakTimeLeftSeconds: 0,
      timeLeftSeconds: state.durationSeconds,
    );
  }

  void start() {
    if (!state.enabled || state.running) return;
    state = state.copyWith(running: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => tick());
  }

  /// Advances the timer by one second. Exposed for deterministic tests so the
  /// break/work transitions can be verified without waiting on a real clock.
  @visibleForTesting
  void tick() {
    try {
      if (state.isOnBreak) {
        _tickBreak();
      } else if (state.mode == TimerMode.countdown) {
        _tickCountdown();
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
  }

  void _tickCountdown() {
    if (state.timeLeftSeconds > 1) {
      state = state.copyWith(timeLeftSeconds: state.timeLeftSeconds - 1);
      return;
    }
    // Work block finished.
    final blocks = state.blocksCompleted + 1;
    if (state.breakEnabled) {
      _logger.info('Work block $blocks complete — starting break');
      state = state.copyWith(
        timeLeftSeconds: 0,
        blocksCompleted: blocks,
        isOnBreak: true,
        breakTimeLeftSeconds: state.breakDurationSeconds,
      );
    } else {
      state = state.copyWith(timeLeftSeconds: 0, blocksCompleted: blocks);
      pause();
      _logger.info('Timer completed');
    }
  }

  void _tickBreak() {
    if (state.breakTimeLeftSeconds > 1) {
      state = state.copyWith(
          breakTimeLeftSeconds: state.breakTimeLeftSeconds - 1);
      return;
    }
    // Break finished — resume a fresh work block.
    _logger.info('Break over — resuming work block');
    state = state.copyWith(
      isOnBreak: false,
      breakTimeLeftSeconds: 0,
      timeLeftSeconds: state.durationSeconds,
    );
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
          timeLeftSeconds: state.durationSeconds,
          elapsedSeconds: 0,
          isOnBreak: false,
          breakTimeLeftSeconds: 0,
          blocksCompleted: 0);
    } else {
      state = state.copyWith(
          elapsedSeconds: 0,
          isOnBreak: false,
          breakTimeLeftSeconds: 0,
          blocksCompleted: 0);
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
