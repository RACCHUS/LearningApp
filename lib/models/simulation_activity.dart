enum SimulationLifecycleState {
  notStarted,
  running,
  paused,
  completed,
  terminated,
  failed,
  disposed,
}

enum SimulationEventType { launched, completed, terminated, failed }

enum SimulationTerminationReason { learnerExit, hostExit, runtimeEnded }

enum SimulationFailureCategory { initialization, runtime, resourceUnavailable }

class SimulationCapabilities {
  final bool supportsPauseAndResume;

  const SimulationCapabilities({this.supportsPauseAndResume = false});
}

/// Host-provided identity and capabilities for an in-memory simulation session.
class SimulationActivityConfig {
  final String id;
  final String version;
  final SimulationCapabilities capabilities;

  SimulationActivityConfig({
    required this.id,
    required this.version,
    this.capabilities = const SimulationCapabilities(),
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be blank.');
    }
    if (version.trim().isEmpty) {
      throw ArgumentError.value(version, 'version', 'Must not be blank.');
    }
  }
}

/// Completion telemetry contains no learner input, score, or free-text metadata.
class SimulationEvent {
  final SimulationEventType type;
  final SimulationTerminationReason? terminationReason;
  final SimulationFailureCategory? failureCategory;

  const SimulationEvent.launched()
    : type = SimulationEventType.launched,
      terminationReason = null,
      failureCategory = null;

  const SimulationEvent.completed()
    : type = SimulationEventType.completed,
      terminationReason = null,
      failureCategory = null;

  const SimulationEvent.terminated(SimulationTerminationReason reason)
    : type = SimulationEventType.terminated,
      terminationReason = reason,
      failureCategory = null;

  const SimulationEvent.failed(SimulationFailureCategory category)
    : type = SimulationEventType.failed,
      terminationReason = null,
      failureCategory = category;
}
