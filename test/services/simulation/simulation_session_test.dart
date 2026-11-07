import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/simulation_activity.dart';
import 'package:learning_pwa/services/simulation/simulation_session.dart';

SimulationActivityConfig _activity({bool canPause = false}) {
  return SimulationActivityConfig(
    id: 'atm-withdrawal',
    version: '1',
    capabilities: SimulationCapabilities(supportsPauseAndResume: canPause),
  );
}

void main() {
  group('SimulationSession', () {
    test('rejects blank activity identity', () {
      expect(
        () => SimulationActivityConfig(id: ' ', version: '1'),
        throwsArgumentError,
      );
      expect(
        () => SimulationActivityConfig(id: 'atm', version: ''),
        throwsArgumentError,
      );
    });

    test('rejects a disabled preview without emitting an event', () {
      final session = SimulationSession(activity: _activity(), enabled: false);

      expect(session.start, throwsStateError);
      expect(session.state, SimulationLifecycleState.notStarted);
      expect(session.events, isEmpty);
    });

    test('honors the compile-time preview flag', () {
      const enabled = bool.fromEnvironment(
        'ENABLE_SIMULATION_PREVIEW',
        defaultValue: false,
      );
      final session = SimulationSession(activity: _activity());

      if (enabled) {
        session.start();
        expect(session.state, SimulationLifecycleState.running);
      } else {
        expect(session.start, throwsStateError);
        expect(session.events, isEmpty);
      }
    });

    test('launches and completes once, ignoring later terminal reports', () {
      final session = SimulationSession(activity: _activity(), enabled: true);

      session.start();
      expect(session.state, SimulationLifecycleState.running);
      expect(session.complete(), isTrue);
      expect(session.complete(), isFalse);
      expect(
        session.terminate(SimulationTerminationReason.learnerExit),
        isFalse,
      );
      expect(session.fail(SimulationFailureCategory.runtime), isFalse);
      expect(session.state, SimulationLifecycleState.completed);
      expect(session.events.map((event) => event.type), [
        SimulationEventType.launched,
        SimulationEventType.completed,
      ]);
      expect(session.start, throwsStateError);
    });

    test('does not silently pause an unsupported activity', () {
      final session = SimulationSession(activity: _activity(), enabled: true);
      session.start();

      expect(session.pause, throwsUnsupportedError);
      expect(session.state, SimulationLifecycleState.running);
      expect(session.events, hasLength(1));
    });

    test('pauses and resumes only when the capability is declared', () {
      final session = SimulationSession(
        activity: _activity(canPause: true),
        enabled: true,
      );
      session.start();

      session.pause();
      expect(session.state, SimulationLifecycleState.paused);
      expect(session.complete, throwsStateError);
      session.resume();
      expect(session.complete(), isTrue);
      expect(session.events, hasLength(2));
    });

    test('allows termination while paused with a typed reason', () {
      final session = SimulationSession(
        activity: _activity(canPause: true),
        enabled: true,
      );
      session.start();
      session.pause();

      expect(session.terminate(SimulationTerminationReason.hostExit), isTrue);
      expect(session.state, SimulationLifecycleState.terminated);
      expect(session.events.last.type, SimulationEventType.terminated);
      expect(
        session.events.last.terminationReason,
        SimulationTerminationReason.hostExit,
      );
      expect(session.complete(), isFalse);
    });

    test('records a coarse runtime failure without reporting completion', () {
      final session = SimulationSession(activity: _activity(), enabled: true);
      session.start();

      expect(
        session.fail(SimulationFailureCategory.resourceUnavailable),
        isTrue,
      );
      expect(session.state, SimulationLifecycleState.failed);
      expect(session.events.last.type, SimulationEventType.failed);
      expect(
        session.events.last.failureCategory,
        SimulationFailureCategory.resourceUnavailable,
      );
      expect(session.complete(), isFalse);
    });

    test('rejects terminal operations before launch', () {
      final session = SimulationSession(activity: _activity(), enabled: true);

      expect(session.complete, throwsStateError);
      expect(
        () => session.terminate(SimulationTerminationReason.learnerExit),
        throwsStateError,
      );
      expect(
        () => session.fail(SimulationFailureCategory.runtime),
        throwsStateError,
      );
      expect(session.events, isEmpty);
    });

    test('exposes an immutable snapshot and clears it on disposal', () {
      final session = SimulationSession(activity: _activity(), enabled: true);
      session.start();

      expect(() => session.events.clear(), throwsUnsupportedError);
      session.dispose();
      expect(session.state, SimulationLifecycleState.disposed);
      expect(session.events, isEmpty);
      expect(session.start, throwsStateError);
      expect(session.complete, throwsStateError);
    });
  });
}
