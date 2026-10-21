/// EXM-02A: four-step reference-navigation practice, without official-score
/// claims or durable-progress claims. Input must already be independently
/// reviewed for the exact immutable reference-manifest revision.
///
/// This model contains no licensed book text or reviewer-private answer keys
/// in a public persistence layer. Any in-memory steps are disposable until
/// EXM-02B supplies authenticated, version-pinned attempt persistence.
enum ReferenceDrillStep { resourceChoice, sectionLocation, interpretation, application }

enum ReferenceDrillOutcome { correct, incorrect, skipped }

/// Only service-reviewed tasks can reach this engine. Editorial approval must
/// be enforced server-side; a client flag cannot authorize publication.
class ReviewedReferenceDrillTask {
  final String itemId;
  final String answerBindingId;
  final String manifestRevisionId;
  final String partKey;
  final String referenceEditionKey;
  final String sourceEdition;
  final int itemContentRevision;
  final int answerLocationRevision;
  final Map<ReferenceDrillStep, String> expectedAnswers;

  ReviewedReferenceDrillTask({
    required this.itemId,
    required this.answerBindingId,
    required this.manifestRevisionId,
    required this.partKey,
    required this.referenceEditionKey,
    required this.sourceEdition,
    required this.itemContentRevision,
    required this.answerLocationRevision,
    required Map<ReferenceDrillStep, String> expectedAnswers,
  }) : expectedAnswers = Map.unmodifiable(expectedAnswers) {
    for (final value in [
      itemId, answerBindingId, manifestRevisionId, partKey,
      referenceEditionKey, sourceEdition,
    ]) {
      if (value.trim().isEmpty) {
        throw const FormatException('Reference drill identity must not be empty');
      }
    }
    if (itemContentRevision <= 0 || answerLocationRevision <= 0) {
      throw const FormatException('Item and answer revisions must be positive');
    }
    if (expectedAnswers.length != ReferenceDrillStep.values.length ||
        ReferenceDrillStep.values.any(
          (step) => expectedAnswers[step]?.trim().isNotEmpty != true,
        )) {
      throw const FormatException('Full-chain task requires R1, R2, R3 and R4 answers');
    }
  }
}

class ReferenceStepResult {
  final ReferenceDrillStep step;
  final ReferenceDrillOutcome outcome;
  final Duration appElapsed;
  final Duration? selfReportedBookTime;

  const ReferenceStepResult({
    required this.step,
    required this.outcome,
    required this.appElapsed,
    this.selfReportedBookTime,
  });
}

class ReferenceDrillResults {
  final String bindingId;
  final String manifestRevisionId;
  final List<ReferenceStepResult> steps;

  ReferenceDrillResults({
    required this.bindingId,
    required this.manifestRevisionId,
    required List<ReferenceStepResult> steps,
  }) : steps = List.unmodifiable(steps);

  /// Show the weak link, not an opaque composite exam pass prediction.
  Map<ReferenceDrillStep, ReferenceDrillOutcome> get byStep => {
    for (final result in steps) result.step: result.outcome,
  };

  bool get isComplete => steps.length == ReferenceDrillStep.values.length;
  bool get fullChainCorrect =>
      isComplete && steps.every((s) => s.outcome == ReferenceDrillOutcome.correct);
}

/// Volatile practice engine. It cannot claim observed physical-book duration,
/// persist progress, or identify an unverified answer as officially correct.
class DisposableReferenceDrillSession {
  final ReviewedReferenceDrillTask task;
  final Set<ReferenceDrillStep> permittedSteps;
  final DateTime startedAt;
  final List<ReferenceStepResult> _results = [];

  DisposableReferenceDrillSession({
    required this.task,
    required this.permittedSteps,
    required this.startedAt,
  }) {
    if (permittedSteps.isEmpty) {
      throw const FormatException('Select at least one reference drill step');
    }
  }

  ReferenceDrillStep? get nextStep {
    for (final step in ReferenceDrillStep.values) {
      if (permittedSteps.contains(step) &&
          !_results.any((r) => r.step == step)) return step;
    }
    return null;
  }

  ReferenceStepResult submit({
    required ReferenceDrillStep step,
    required String? answer,
    required Duration appElapsed,
    Duration? selfReportedBookTime,
  }) {
    if (step != nextStep) {
      throw StateError('Reference drill steps must be completed in sequence');
    }
    if (appElapsed.isNegative || (selfReportedBookTime?.isNegative ?? false)) {
      throw ArgumentError('Duration cannot be negative');
    }
    final trimmed = answer?.trim();
    final expected = task.expectedAnswers[step]!;
    final outcome = trimmed == null || trimmed.isEmpty
        ? ReferenceDrillOutcome.skipped
        : trimmed == expected
            ? ReferenceDrillOutcome.correct
            : ReferenceDrillOutcome.incorrect;
    final result = ReferenceStepResult(
      step: step,
      outcome: outcome,
      appElapsed: appElapsed,
      selfReportedBookTime: selfReportedBookTime,
    );
    _results.add(result);
    return result;
  }

  ReferenceDrillResults get results => ReferenceDrillResults(
    bindingId: task.answerBindingId,
    manifestRevisionId: task.manifestRevisionId,
    steps: _results,
  );
}

/// Client-side guard only; real authorizations must also be checked by an RLS
/// or service endpoint that excludes private reviewed answer-key material.
class ReferenceDrillEligibility {
  static bool canStart({
    required String? requestedManifestRevisionId,
    required String? approvedManifestRevisionId,
    required bool bindingApproved,
    required bool partMatches,
    required bool editionMatches,
  }) =>
      requestedManifestRevisionId != null &&
      requestedManifestRevisionId.isNotEmpty &&
      requestedManifestRevisionId == approvedManifestRevisionId &&
      bindingApproved && partMatches && editionMatches;
}
