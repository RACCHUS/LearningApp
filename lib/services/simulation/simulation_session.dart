import '../../models/simulation_activity.dart';

/// An ephemeral lifecycle only; it does not persist or submit learning evidence.
class SimulationSession {
  final SimulationActivityConfig activity;
  final bool _enabled;
  final List<SimulationEvent> _events = [];
  SimulationLifecycleState _state = SimulationLifecycleState.notStarted;

  SimulationSession({
    required this.activity,
    bool enabled = simulationPreviewEnabled,
  }) : _enabled = isSimulationPreviewAllowed(requested: enabled);

  SimulationLifecycleState get state => _state;
  List<SimulationEvent> get events => List.unmodifiable(_events);

  bool get isClosed =>
      _state == SimulationLifecycleState.completed ||
      _state == SimulationLifecycleState.terminated ||
      _state == SimulationLifecycleState.failed;

  void start() {
    _ensureNotDisposed();
    if (!_enabled) {
      throw StateError('Simulation preview is disabled.');
    }
    _requireState(SimulationLifecycleState.notStarted, 'start');
    _state = SimulationLifecycleState.running;
    _events.add(const SimulationEvent.launched());
  }

  void pause() {
    _ensureNotDisposed();
    _requireState(SimulationLifecycleState.running, 'pause');
    if (!activity.capabilities.supportsPauseAndResume) {
      throw UnsupportedError('This simulation cannot pause and resume.');
    }
    _state = SimulationLifecycleState.paused;
  }

  void resume() {
    _ensureNotDisposed();
    _requireState(SimulationLifecycleState.paused, 'resume');
    _state = SimulationLifecycleState.running;
  }

  bool complete() {
    if (_isLateTerminalEvent()) return false;
    _requireState(SimulationLifecycleState.running, 'complete');
    _state = SimulationLifecycleState.completed;
    _events.add(const SimulationEvent.completed());
    return true;
  }

  bool terminate(SimulationTerminationReason reason) {
    if (_isLateTerminalEvent()) return false;
    _requireActive('terminate');
    _state = SimulationLifecycleState.terminated;
    _events.add(SimulationEvent.terminated(reason));
    return true;
  }

  bool fail(SimulationFailureCategory category) {
    if (_isLateTerminalEvent()) return false;
    _requireActive('fail');
    _state = SimulationLifecycleState.failed;
    _events.add(SimulationEvent.failed(category));
    return true;
  }

  void dispose() {
    _events.clear();
    _state = SimulationLifecycleState.disposed;
  }

  bool _isLateTerminalEvent() {
    _ensureNotDisposed();
    return isClosed;
  }

  void _ensureNotDisposed() {
    if (_state == SimulationLifecycleState.disposed) {
      throw StateError('The simulation session has been disposed.');
    }
  }

  void _requireActive(String operation) {
    if (_state != SimulationLifecycleState.running &&
        _state != SimulationLifecycleState.paused) {
      throw StateError(
        'Cannot $operation while the simulation is ${_state.name}.',
      );
    }
  }

  void _requireState(SimulationLifecycleState expected, String operation) {
    if (_state != expected) {
      throw StateError(
        'Cannot $operation while the simulation is ${_state.name}.',
      );
    }
  }
}
