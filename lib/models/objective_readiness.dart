/// Readiness by objective (ingestion plan v1.2 §8.7), served by
/// `get_target_objective_readiness`. A per-domain view of a target's
/// objectives so learners see where effort pays off most.
enum ObjectiveReadinessStatus {
  /// Strong evidence and enough independent (held-out) checks (D-14).
  strong,

  /// Some evidence, but not yet strong, or not independently checked.
  building,

  /// Available in LearningApp, no evidence yet.
  notStarted,

  /// No lessons in LearningApp yet. Never counted as mastered or as zero.
  notAvailable;

  static ObjectiveReadinessStatus parse(Object? value) => switch (value) {
        'strong' => strong,
        'building' => building,
        'not_started' => notStarted,
        // Unknown values fail closed to the most conservative claim.
        _ => notAvailable,
      };

  String get label => switch (this) {
        strong => 'Strong',
        building => 'Building',
        notStarted => 'Not started',
        notAvailable => 'Not yet available',
      };
}

class ObjectiveReadiness {
  final String code;
  final String title;
  final ObjectiveReadinessStatus status;

  /// True when the objective has enough approved held-out checks.
  final bool checked;

  const ObjectiveReadiness({
    required this.code,
    required this.title,
    required this.status,
    required this.checked,
  });

  factory ObjectiveReadiness.fromJson(Map<String, dynamic> json) => ObjectiveReadiness(
        code: '${json['code'] ?? ''}',
        title: '${json['title'] ?? ''}',
        status: ObjectiveReadinessStatus.parse(json['status']),
        checked: json['checked'] == true,
      );
}

class DomainReadiness {
  final String code;
  final String title;

  /// Share of the blueprint (0.0 to 1.0).
  final double weightShare;
  final ObjectiveReadinessStatus status;
  final List<ObjectiveReadiness> objectives;

  const DomainReadiness({
    required this.code,
    required this.title,
    required this.weightShare,
    required this.status,
    required this.objectives,
  });

  factory DomainReadiness.fromJson(Map<String, dynamic> json) {
    final share = json['weight_share'];
    return DomainReadiness(
      code: '${json['code'] ?? ''}',
      title: '${json['title'] ?? ''}',
      weightShare: ((share is num ? share.toDouble() : double.tryParse('$share')) ?? 0).clamp(0.0, 1.0),
      status: ObjectiveReadinessStatus.parse(json['status']),
      objectives: [
        for (final o in (json['objectives'] as List? ?? const []))
          if (o is Map) ObjectiveReadiness.fromJson(Map<String, dynamic>.from(o)),
      ],
    );
  }

  /// Whole-number percentage of the blueprint, for display.
  int get weightPercent => (weightShare * 100).round();
}

class TargetObjectiveReadiness {
  final bool signedIn;

  /// True when the blueprint had no weights and domains share equally.
  final bool weightsEditorial;
  final int minHeldOutItems;
  final List<DomainReadiness> domains;

  const TargetObjectiveReadiness({
    required this.signedIn,
    required this.weightsEditorial,
    required this.minHeldOutItems,
    required this.domains,
  });

  /// Null when the server reports the switch is off.
  static TargetObjectiveReadiness? fromJson(Map<String, dynamic> json) {
    if (json['enabled'] != true) return null;
    final min = json['min_held_out_items'];
    return TargetObjectiveReadiness(
      signedIn: json['signed_in'] == true,
      weightsEditorial: json['weights_editorial'] == true,
      minHeldOutItems: min is num ? min.toInt() : 6,
      domains: [
        for (final d in (json['domains'] as List? ?? const []))
          if (d is Map) DomainReadiness.fromJson(Map<String, dynamic>.from(d)),
      ],
    );
  }

  /// True when some available objective is building only because it has no
  /// independent checks yet, so the card can explain why it isn't strong.
  bool get hasUncheckedObjectives => domains.any((d) => d.objectives
      .any((o) => !o.checked && o.status != ObjectiveReadinessStatus.notAvailable));
}
