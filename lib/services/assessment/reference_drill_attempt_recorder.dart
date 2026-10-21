import 'package:uuid/uuid.dart';

import '../../models/assessment_engine/reference_drill_engine.dart';
import 'exam_reference_drill_event_service.dart';

/// Immutable, answer-free identity supplied alongside a reviewed drill.
/// These fields are NOT proof of editorial approval: the database checks the
/// binding, content hash, reference edition, part and exam date on insert.
/// Never send expected answers or reviewer-only locations to this class.
class ReferenceDrillBindingSnapshot {
  final String assessmentItemId;
  final String approvedBindingId;
  final String manifestRevisionId;
  final String examPartKey;
  final DateTime administrationDate;
  final int itemContentRevision;
  final int answerLocationRevision;

  const ReferenceDrillBindingSnapshot({
    required this.assessmentItemId,
    required this.approvedBindingId,
    required this.manifestRevisionId,
    required this.examPartKey,
    required this.administrationDate,
    required this.itemContentRevision,
    required this.answerLocationRevision,
  });

  void validate() {
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuid.hasMatch(assessmentItemId) ||
        !uuid.hasMatch(approvedBindingId) ||
        !uuid.hasMatch(manifestRevisionId) ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(examPartKey) ||
        itemContentRevision < 1 ||
        answerLocationRevision < 1) {
      throw const FormatException('Invalid reference drill binding identity');
    }
    final date = DateTime.utc(
      administrationDate.year,
      administrationDate.month,
      administrationDate.day,
    );
    if (administrationDate.year != date.year ||
        administrationDate.month != date.month ||
        administrationDate.day != date.day) {
      throw const FormatException('Invalid exam administration date');
    }
  }
}

class _PendingDrillObservation {
  final ReferenceDrillStep step;
  final bool responded;
  final Duration appElapsed;
  final Duration? selfReportedBookTime;
  final DateTime startedAt;
  final DateTime completedAt;

  const _PendingDrillObservation({
    required this.step,
    required this.responded,
    required this.appElapsed,
    required this.selfReportedBookTime,
    required this.startedAt,
    required this.completedAt,
  });
}

/// Connects an R1-R4 learner step to durable, UNGRADED event storage.
///
/// No client-side expected answer or correctness value enters the event.
/// A permanent Auth owner must be captured at session start. Each write
/// rechecks that owner; account switching cannot save an old session under
/// the newly signed-in account. A failed write stays pending with the exact
/// same attempt ID, step, timestamps and observations for idempotent retry.
///
/// This is an event-recording layer, not approved-item delivery, a scoring
/// endpoint, or browser-refresh restoration. Do not expose the synthetic
/// DisposableReferenceDrillSession's answer map to production learners.
class ReferenceDrillAttemptRecorder {
  final ExamReferenceDrillEventService eventService;
  final ReferenceDrillBindingSnapshot binding;
  final String expectedOwnerId;
  final String clientAttemptId;
  final DateTime Function() _now;

  late final List<ReferenceDrillStep> _orderedSteps;
  late DateTime _stepStartedAt;
  int _completed = 0;
  bool _writing = false;
  _PendingDrillObservation? _pending;

  ReferenceDrillAttemptRecorder({
    required this.eventService,
    required this.binding,
    required this.expectedOwnerId,
    Set<ReferenceDrillStep> permittedSteps = const {
      ReferenceDrillStep.resourceChoice,
      ReferenceDrillStep.sectionLocation,
      ReferenceDrillStep.interpretation,
      ReferenceDrillStep.application,
    },
    String? clientAttemptId,
    DateTime Function()? now,
  })  : clientAttemptId = clientAttemptId ?? const Uuid().v4(),
        _now = now ?? DateTime.now {
    binding.validate();
    if (expectedOwnerId.trim().isEmpty ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(this.clientAttemptId)) {
      throw const FormatException('Invalid owner or attempt ID');
    }
    _orderedSteps = List.unmodifiable([
      for (final step in ReferenceDrillStep.values)
        if (permittedSteps.contains(step)) step,
    ]);
    if (_orderedSteps.isEmpty) {
      throw const FormatException('Select at least one reference drill step');
    }
    _stepStartedAt = _now().toUtc();
  }

  ReferenceDrillStep? get nextStep =>
      _completed == _orderedSteps.length ? null : _orderedSteps[_completed];

  bool get hasPendingWrite => _pending != null;
  bool get isComplete => nextStep == null;
  int get recordedStepCount => _completed;

  Future<Map<String, dynamic>> submitStep({
    required ReferenceDrillStep step,
    required bool responded,
    required Duration appElapsed,
    Duration? selfReportedBookTime,
  }) {
    if (_writing || _pending != null) {
      throw StateError('Retry the pending reference drill step first');
    }
    if (step != nextStep) {
      throw StateError('Reference drill steps must be recorded in order');
    }
    if (appElapsed.isNegative ||
        appElapsed.inMilliseconds > 86400000 ||
        (selfReportedBookTime?.isNegative ?? false) ||
        (selfReportedBookTime?.inMilliseconds ?? 0) > 86400000) {
      throw ArgumentError('Invalid reference drill observation duration');
    }
    final finishedAt = _now().toUtc();
    if (finishedAt.isBefore(_stepStartedAt)) {
      throw StateError('Reference drill clock moved backwards');
    }
    _pending = _PendingDrillObservation(
      step: step,
      responded: responded,
      appElapsed: appElapsed,
      selfReportedBookTime: selfReportedBookTime,
      startedAt: _stepStartedAt,
      completedAt: finishedAt,
    );
    return retryPending();
  }

  Future<Map<String, dynamic>> retryPending() async {
    if (_writing) {
      throw StateError('Reference drill write already in progress');
    }
    final pending = _pending;
    if (pending == null) {
      throw StateError('No reference drill step is pending');
    }
    _writing = true;
    try {
      final saved = await eventService.recordStep(
        expectedOwnerId: expectedOwnerId,
        clientAttemptId: clientAttemptId,
        assessmentItemId: binding.assessmentItemId,
        approvedBindingId: binding.approvedBindingId,
        manifestRevisionId: binding.manifestRevisionId,
        examPartKey: binding.examPartKey,
        administrationDate: binding.administrationDate,
        itemContentRevision: binding.itemContentRevision,
        answerLocationRevision: binding.answerLocationRevision,
        step: switch (pending.step) {
          ReferenceDrillStep.resourceChoice => 'resource_choice',
          ReferenceDrillStep.sectionLocation => 'section_location',
          ReferenceDrillStep.interpretation => 'interpretation',
          ReferenceDrillStep.application => 'application',
        },
        responded: pending.responded,
        appElapsed: pending.appElapsed,
        selfReportedBookTime: pending.selfReportedBookTime,
        startedAt: pending.startedAt,
        completedAt: pending.completedAt,
      );
      _completed++;
      _pending = null;
      _stepStartedAt = _now().toUtc();
      return saved;
    } finally {
      _writing = false;
    }
  }
}
