import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/timer_provider.dart';

void main() {
  group('TimerProvider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have timer disabled', () {
      final state = container.read(timerProvider);
      
      expect(state.enabled, isFalse);
      expect(state.running, isFalse);
      expect(state.durationSeconds, 600); // Default duration
      expect(state.mode, TimerMode.countdown);
    });

    test('should toggle enabled state', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      var state = container.read(timerProvider);
      expect(state.enabled, isTrue);
      
      notifier.toggleEnabled(false);
      state = container.read(timerProvider);
      expect(state.enabled, isFalse);
    });

    test('should set timer duration', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.setDuration(300); // 5 minutes
      final state = container.read(timerProvider);
      
      expect(state.durationSeconds, 300);
      expect(state.timeLeftSeconds, 300);
    });

    test('should start and pause timer', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.setDuration(60);
      notifier.start();
      
      var state = container.read(timerProvider);
      expect(state.running, isTrue);
      
      notifier.pause();
      state = container.read(timerProvider);
      expect(state.running, isFalse);
    });

    test('should reset timer', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.setDuration(100);
      notifier.start();
      notifier.reset();
      
      final state = container.read(timerProvider);
      expect(state.timeLeftSeconds, 100);
      expect(state.running, isFalse);
      expect(state.elapsedSeconds, 0);
    });

    test('should switch between countdown and stopwatch modes', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.setMode(TimerMode.countdown);
      var state = container.read(timerProvider);
      expect(state.mode, TimerMode.countdown);
      
      notifier.setMode(TimerMode.stopwatch);
      state = container.read(timerProvider);
      expect(state.mode, TimerMode.stopwatch);
    });

    test('should pause when changing modes', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.start();
      
      expect(container.read(timerProvider).running, isTrue);
      
      notifier.setMode(TimerMode.stopwatch);
      
      expect(container.read(timerProvider).running, isFalse);
    });

    test('should maintain state across multiple operations', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.setDuration(120);
      notifier.setMode(TimerMode.countdown);
      
      final state = container.read(timerProvider);
      
      expect(state.enabled, isTrue);
      expect(state.durationSeconds, 120);
      expect(state.mode, TimerMode.countdown);
    });

    test('should allow custom duration values', () {
      final notifier = container.read(timerProvider.notifier);
      
      final durations = [30, 60, 300, 600, 1800];
      
      for (final duration in durations) {
        notifier.setDuration(duration);
        final state = container.read(timerProvider);
        expect(state.durationSeconds, duration);
        expect(state.timeLeftSeconds, duration);
      }
    });

    test('should not start if not enabled', () {
      final notifier = container.read(timerProvider.notifier);
      
      // Timer is disabled by default
      notifier.start();
      
      final state = container.read(timerProvider);
      expect(state.running, isFalse);
    });

    test('should pause and reset on disable', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.setDuration(60);
      notifier.start();
      
      expect(container.read(timerProvider).running, isTrue);
      
      notifier.toggleEnabled(false);
      
      final state = container.read(timerProvider);
      expect(state.running, isFalse);
      expect(state.enabled, isFalse);
    });

    test('TimerState copyWith should work correctly', () {
      final originalState = TimerState(
        enabled: true,
        running: false,
        durationSeconds: 60,
        timeLeftSeconds: 45,
        elapsedSeconds: 15,
        mode: TimerMode.countdown,
      );

      final newState = originalState.copyWith(
        running: true,
        timeLeftSeconds: 40,
      );

      expect(newState.enabled, isTrue);
      expect(newState.running, isTrue);
      expect(newState.durationSeconds, 60);
      expect(newState.timeLeftSeconds, 40);
      expect(newState.elapsedSeconds, 15);
      expect(newState.mode, TimerMode.countdown);
    });

    test('should resume timer after pause', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.start();
      
      expect(container.read(timerProvider).running, isTrue);
      
      notifier.pause();
      expect(container.read(timerProvider).running, isFalse);
      
      notifier.resume();
      expect(container.read(timerProvider).running, isTrue);
    });

    test('should track elapsed time in stopwatch mode', () {
      final notifier = container.read(timerProvider.notifier);
      
      notifier.toggleEnabled(true);
      notifier.setMode(TimerMode.stopwatch);
      
      final state = container.read(timerProvider);
      expect(state.mode, TimerMode.stopwatch);
      expect(state.elapsedSeconds, 0);
    });
  });

  group('Pomodoro break system', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose);

    test('is disabled by default', () {
      final state = container.read(timerProvider);
      expect(state.breakEnabled, isFalse);
      expect(state.isOnBreak, isFalse);
      expect(state.blocksCompleted, 0);
    });

    test('setBreak enables and configures the break', () {
      final notifier = container.read(timerProvider.notifier);
      notifier.setBreak(enabled: true, durationSeconds: 120);

      final state = container.read(timerProvider);
      expect(state.breakEnabled, isTrue);
      expect(state.breakDurationSeconds, 120);
    });

    test('starts a break after a work block completes', () {
      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setDuration(2);
      notifier.setBreak(enabled: true, durationSeconds: 3);

      notifier.tick(); // 2 -> 1
      expect(container.read(timerProvider).isOnBreak, isFalse);
      notifier.tick(); // block completes -> break begins

      final state = container.read(timerProvider);
      expect(state.isOnBreak, isTrue);
      expect(state.blocksCompleted, 1);
      expect(state.breakTimeLeftSeconds, 3);
    });

    test('resumes a fresh work block when the break ends', () {
      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setDuration(1);
      notifier.setBreak(enabled: true, durationSeconds: 2);

      notifier.tick(); // block completes -> break (2 left)
      expect(container.read(timerProvider).isOnBreak, isTrue);
      notifier.tick(); // break 2 -> 1
      notifier.tick(); // break ends

      final state = container.read(timerProvider);
      expect(state.isOnBreak, isFalse);
      expect(state.timeLeftSeconds, 1);
    });

    test('pauses at zero when breaks are disabled', () {
      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setDuration(1);
      notifier.start();

      notifier.tick(); // completes with no break

      final state = container.read(timerProvider);
      expect(state.isOnBreak, isFalse);
      expect(state.running, isFalse);
      expect(state.blocksCompleted, 1);
    });

    test('skipBreak resumes work immediately', () {
      final notifier = container.read(timerProvider.notifier);
      notifier.toggleEnabled(true);
      notifier.setDuration(1);
      notifier.setBreak(enabled: true, durationSeconds: 300);

      notifier.tick(); // -> break
      expect(container.read(timerProvider).isOnBreak, isTrue);

      notifier.skipBreak();
      final state = container.read(timerProvider);
      expect(state.isOnBreak, isFalse);
      expect(state.timeLeftSeconds, 1);
    });
  });
}
