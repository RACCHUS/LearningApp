/// How the planner decided to meet a content need (master plan v2.6 §5.2,
/// Appendix D.1). This is a planning record, not a job state: only a
/// [ContentResolutionKind.generate] decision may lead to a generation job.
enum ContentResolutionKind {
  exactReuse('exact_reuse'),
  adapt('adapt'),
  externalLink('external_link'),
  ingest('ingest'),
  deterministic('deterministic'),
  generate('generate'),
  unavailable('unavailable');

  const ContentResolutionKind(this.wire);

  final String wire;
}

class ContentResolutionDecision {
  const ContentResolutionDecision({
    required this.kind,
    required this.reason,
    this.eligibleAssetRef,
    this.scope,
  }) : assert(
         kind != ContentResolutionKind.exactReuse || eligibleAssetRef != null,
         'A reuse decision must name the asset it reuses.',
       );

  final ContentResolutionKind kind;

  /// Why this resolution was chosen (shown to owners/auditors).
  final String reason;

  /// The reused/adapted/linked asset, when there is one.
  final String? eligibleAssetRef;

  /// Owner/visibility scope the decision applies to.
  final String? scope;

  /// Reuse, linking, ingestion and deterministic fills never create a
  /// generation job (no fictitious `reused_existing` execution status).
  bool get createsGenerationJob => kind == ContentResolutionKind.generate;
}
