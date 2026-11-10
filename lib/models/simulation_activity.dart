import 'package:flutter/foundation.dart';

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

/// Experimental native simulations are disabled unless the app build
/// explicitly opts in. This is a compile-time flag, not a remotely switchable
/// production setting.
const simulationPreviewEnabled =
    bool.fromEnvironment('ENABLE_SIMULATION_PREVIEW', defaultValue: false);

/// The single preview gate. Test/profile code may request a preview without
/// an explicit build flag, but release builds require the compile-time opt-in.
/// This prevents a constructor override from bypassing a disabled release.
bool isSimulationPreviewAllowed({required bool requested}) {
  return requested && (!kReleaseMode || simulationPreviewEnabled);
}

String simulationActivityTitle(String id) => switch (id) {
  'networking-basics' => 'Network troubleshooting practice',
  'atm-withdrawal' => 'ATM withdrawal practice',
  _ => 'Interactive practice',
};

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

class SimulationActivityRegistry {
  static final networking = SimulationActivityConfig(
    id: 'networking-basics',
    version: '1.0.0',
  );
  static final atmWithdrawal = SimulationActivityConfig(
    id: 'atm-withdrawal',
    version: '1.0.0',
  );

  static final activities = <String, SimulationActivityConfig>{
    'networking-basics': networking,
    'atm-withdrawal': atmWithdrawal,
  };

  static SimulationActivityConfig? resolve(String id, String version) {
    final activity = activities[id];
    return activity?.version == version ? activity : null;
  }

  static bool supports(String id, String version) =>
      resolve(id, version) != null;
}
