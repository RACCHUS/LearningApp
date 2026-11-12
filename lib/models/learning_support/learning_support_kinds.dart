/// Shared vocabulary for learning support and content needs (master plan
/// v2.6 §12.1). Each value has a stable wire string; unknown wire values
/// decode to `null` rather than a guessed default.
library;

T? _fromWire<T extends Enum>(
  List<T> values,
  String Function(T) wire,
  Object? v,
) {
  for (final e in values) {
    if (wire(e) == v) return e;
  }
  return null;
}

/// Where a piece of learning content comes from.
enum ContentSourceKind {
  internalApproved('internal_approved'),
  ingested('ingested'),
  externalReference('external_reference'),
  generated('generated');

  const ContentSourceKind(this.wire);
  final String wire;

  static ContentSourceKind? fromWire(Object? v) =>
      _fromWire(values, (e) => e.wire, v);
}

/// A hypothesis about why a learner is stuck. It is never a diagnosis.
enum GapKind {
  clarification('clarification'),
  missingPrerequisite('missing_prerequisite'),
  misconception('misconception'),
  forgetting('forgetting'),
  application('application'),
  sourceQuality('source_quality'),
  accessibility('accessibility'),
  externalCoverage('external_coverage'),
  unknown('unknown');

  const GapKind(this.wire);
  final String wire;

  static GapKind? fromWire(Object? v) => _fromWire(values, (e) => e.wire, v);
}

/// The kind of help offered. `postponed` records a learner's choice to
/// continue without help; it never falsifies mastery.
enum SupportKind {
  explain('explain'),
  alternateExample('alternate_example'),
  quickLesson('quick_lesson'),
  foundationLesson('foundation_lesson'),
  guidedPractice('guided_practice'),
  externalResource('external_resource'),
  postponed('postponed');

  const SupportKind(this.wire);
  final String wire;

  static SupportKind? fromWire(Object? v) =>
      _fromWire(values, (e) => e.wire, v);
}

/// How (if at all) AI is executed for a job. `noAi` is always available.
enum GenerationExecutionKind {
  noAi('no_ai'),
  localInference('local_inference'),
  userAuthorizedPlan('user_authorized_plan'),
  manualChat('manual_chat'),
  userApi('user_api'),
  managedAi('managed_ai');

  const GenerationExecutionKind(this.wire);
  final String wire;

  /// Only these routes can spend money or send data to a provider on the
  /// app's behalf; each needs its own gates (BYOK latch, spend gate).
  bool get callsProviderAutomatically =>
      this == userAuthorizedPlan || this == userApi || this == managedAi;

  static GenerationExecutionKind? fromWire(Object? v) =>
      _fromWire(values, (e) => e.wire, v);
}

/// Strength of the evidence behind a [ContentNeed].
enum NeedEvidenceClass {
  /// The learner asked for help.
  userRequest('user_request'),

  /// One weak signal; may be wrong.
  tentative('tentative'),

  /// Several independent authenticated signals agree.
  corroborated('corroborated');

  const NeedEvidenceClass(this.wire);
  final String wire;

  static NeedEvidenceClass? fromWire(Object? v) =>
      _fromWire(values, (e) => e.wire, v);
}
