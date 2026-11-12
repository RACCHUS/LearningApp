import 'package:learning_pwa/models/content_generation/generation_error.dart';

/// Execution-only status of a content-generation job (master plan v2.6
/// §5.2, Appendix D.1). Publication, review and reuse are deliberately NOT
/// job states: see `AssetPublicationStatus` and `ContentResolutionDecision`.
///
/// The legacy V1 `GenerationPhase` stays separate and is never stored here.
enum GenerationJobStatus {
  ready('ready'),
  awaitingManualResponse('awaiting_manual_response'),
  running('running'),
  validating('validating'),
  partialReady('partial_ready'),
  repairNeeded('repair_needed'),
  paused('paused'),
  rateLimited('rate_limited'),
  completedPrivate('completed_private'),
  failedSafe('failed_safe'),
  cancelled('cancelled');

  const GenerationJobStatus(this.wire);

  /// Stable persisted value.
  final String wire;

  /// Terminal for the job; follow-on work is a new or revision job.
  bool get isTerminal =>
      this == completedPrivate || this == failedSafe || this == cancelled;

  static GenerationJobStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// Events that move a job between execution states.
enum GenerationJobEvent {
  showManualPrompt,
  startAuthorizedRoute,
  pasteResponse,
  receiveResponse,
  providerRateLimit,
  allRequiredSlotsValid,
  someValid,
  requiresRepair,
  prepareNext,
  repair,
  finishPartialIfAllowed,
  prepareRepairPrompt,
  userEdit,
  resumeManual,
  prepare,
  reauthorizeExecutor,
  userRetryOrSwitch,
  pause,
  fail,
  cancel,
}

/// A job's status plus its revision, for optimistic concurrency checks.
class GenerationJobState {
  const GenerationJobState(this.status, {this.revision = 0});

  final GenerationJobStatus status;
  final int revision;
}

/// Outcome of applying an event: a new state, or a structured error. An
/// invalid event never resets the job to `ready`.
class GenerationJobTransitionResult {
  const GenerationJobTransitionResult._(this.state, this.error);

  final GenerationJobState? state;
  final GenerationError? error;

  bool get isOk => error == null;
}

/// The authoritative transition table from plan §5.2.
class GenerationJobMachine {
  const GenerationJobMachine._();

  static const Map<
    GenerationJobStatus,
    Map<GenerationJobEvent, GenerationJobStatus>
  >
  table = {
    GenerationJobStatus.ready: {
      GenerationJobEvent.showManualPrompt:
          GenerationJobStatus.awaitingManualResponse,
      GenerationJobEvent.startAuthorizedRoute: GenerationJobStatus.running,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.awaitingManualResponse: {
      GenerationJobEvent.pasteResponse: GenerationJobStatus.validating,
      GenerationJobEvent.pause: GenerationJobStatus.paused,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.running: {
      GenerationJobEvent.receiveResponse: GenerationJobStatus.validating,
      GenerationJobEvent.providerRateLimit: GenerationJobStatus.rateLimited,
      GenerationJobEvent.pause: GenerationJobStatus.paused,
      GenerationJobEvent.fail: GenerationJobStatus.failedSafe,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.validating: {
      GenerationJobEvent.allRequiredSlotsValid:
          GenerationJobStatus.completedPrivate,
      GenerationJobEvent.someValid: GenerationJobStatus.partialReady,
      GenerationJobEvent.requiresRepair: GenerationJobStatus.repairNeeded,
      GenerationJobEvent.fail: GenerationJobStatus.failedSafe,
    },
    GenerationJobStatus.partialReady: {
      GenerationJobEvent.prepareNext: GenerationJobStatus.ready,
      GenerationJobEvent.repair: GenerationJobStatus.repairNeeded,
      GenerationJobEvent.finishPartialIfAllowed:
          GenerationJobStatus.completedPrivate,
      GenerationJobEvent.pause: GenerationJobStatus.paused,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.repairNeeded: {
      GenerationJobEvent.prepareRepairPrompt: GenerationJobStatus.ready,
      GenerationJobEvent.userEdit: GenerationJobStatus.validating,
      GenerationJobEvent.pause: GenerationJobStatus.paused,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.paused: {
      GenerationJobEvent.resumeManual:
          GenerationJobStatus.awaitingManualResponse,
      GenerationJobEvent.prepare: GenerationJobStatus.ready,
      GenerationJobEvent.reauthorizeExecutor: GenerationJobStatus.running,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    GenerationJobStatus.rateLimited: {
      GenerationJobEvent.userRetryOrSwitch: GenerationJobStatus.ready,
      GenerationJobEvent.pause: GenerationJobStatus.paused,
      GenerationJobEvent.cancel: GenerationJobStatus.cancelled,
    },
    // Terminal states: no in-place resurrection.
    GenerationJobStatus.completedPrivate: {},
    GenerationJobStatus.failedSafe: {},
    GenerationJobStatus.cancelled: {},
  };

  /// Applies [event]. When [expectedRevision] is given and differs from the
  /// current revision, the change is refused as a checkpoint conflict.
  static GenerationJobTransitionResult apply(
    GenerationJobState current,
    GenerationJobEvent event, {
    int? expectedRevision,
  }) {
    if (expectedRevision != null && expectedRevision != current.revision) {
      return GenerationJobTransitionResult._(
        null,
        GenerationError(
          GenerationErrorCode.checkpointConflict,
          detail:
              'expected revision $expectedRevision, '
              'found ${current.revision}',
        ),
      );
    }
    final next = table[current.status]?[event];
    if (next == null) {
      return GenerationJobTransitionResult._(
        null,
        GenerationError(
          GenerationErrorCode.invalidStateTransition,
          detail: '${event.name} is not allowed from ${current.status.wire}',
        ),
      );
    }
    return GenerationJobTransitionResult._(
      GenerationJobState(next, revision: current.revision + 1),
      null,
    );
  }
}
