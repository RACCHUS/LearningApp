import 'package:flutter/material.dart';

/// One individual regulator-sourced milestone step within a pathway tree.
class PathwayStep {
  final String label;
  final String stage;
  final Uri sourceUrl;
  final String? condition;
  final bool isRouteAlternative;

  const PathwayStep({
    required this.label,
    required this.stage,
    required this.sourceUrl,
    this.condition,
    this.isRouteAlternative = false,
  });

  factory PathwayStep.fromJson(Map<String, dynamic> json) {
    return PathwayStep(
      label: json['label'] as String? ?? '',
      stage: json['stage'] as String? ?? 'other',
      sourceUrl: Uri.tryParse(json['source_url'] as String? ?? '') ?? Uri(),
      condition: json['condition'] as String?,
      isRouteAlternative: json['is_route_alternative'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'stage': stage,
      'source_url': sourceUrl.toString(),
      if (condition != null) 'condition': condition,
      'is_route_alternative': isRouteAlternative,
    };
  }

  String get stageDisplayName {
    switch (stage) {
      case 'education':
        return 'Education & Academic Qualification';
      case 'training':
        return 'Pre-Licensing Training';
      case 'experience':
        return 'Supervised Experience';
      case 'background_screening':
        return 'Fingerprints & Background Screening';
      case 'application':
        return 'Regulator Application & Documentation';
      case 'examination':
        return 'Licensure Examination';
      case 'appointment':
        return 'Insurer / Sponsor Appointment';
      case 'authorization':
        return 'State License Issuance';
      case 'continuing_education':
        return 'Continuing Education';
      default:
        return 'Regulator Milestone';
    }
  }

  IconData get stageIcon {
    switch (stage) {
      case 'education':
        return Icons.school_outlined;
      case 'training':
        return Icons.menu_book_outlined;
      case 'experience':
        return Icons.work_outline;
      case 'background_screening':
        return Icons.fingerprint;
      case 'application':
        return Icons.assignment_outlined;
      case 'examination':
        return Icons.fact_check_outlined;
      case 'appointment':
        return Icons.business_outlined;
      case 'authorization':
        return Icons.verified_user_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }
}

/// An alternative qualification route choice under an `op: 'any'` node.
class PathwayRouteOption {
  final int index;
  final String label;
  final String stage;
  final String? condition;
  final Uri? sourceUrl;

  const PathwayRouteOption({
    required this.index,
    required this.label,
    required this.stage,
    this.condition,
    this.sourceUrl,
  });

  factory PathwayRouteOption.fromJson(Map<String, dynamic> json) {
    return PathwayRouteOption(
      index: json['index'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      stage: json['stage'] as String? ?? 'education',
      condition: json['condition'] as String?,
      sourceUrl: json['source_url'] != null
          ? Uri.tryParse(json['source_url'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'label': label,
      'stage': stage,
      if (condition != null) 'condition': condition,
      if (sourceUrl != null) 'source_url': sourceUrl.toString(),
    };
  }

  String get shortSummary {
    if (label.length <= 48) return label;
    return '${label.substring(0, 45)}...';
  }
}

/// Current state of a learner's self-reported readiness for a license pathway.
/// Planning only: does not constitute legal eligibility determination.
class PathwayReadinessState {
  final String pathwayKey; // e.g. "fl_bon:registered-nurse"
  final String? targetId; // Linked private learning target ID, if any
  final int? selectedRouteIndex;
  final String? selectedRouteLabel;
  final Set<String> completedStepLabels;
  final DateTime lastUpdated;

  const PathwayReadinessState({
    required this.pathwayKey,
    this.targetId,
    this.selectedRouteIndex,
    this.selectedRouteLabel,
    this.completedStepLabels = const {},
    required this.lastUpdated,
  });

  factory PathwayReadinessState.empty(String pathwayKey, {String? targetId}) {
    return PathwayReadinessState(
      pathwayKey: pathwayKey,
      targetId: targetId,
      selectedRouteIndex: null,
      selectedRouteLabel: null,
      completedStepLabels: const {},
      lastUpdated: DateTime.now(),
    );
  }

  factory PathwayReadinessState.fromJson(Map<String, dynamic> json) {
    return PathwayReadinessState(
      pathwayKey: json['pathway_key'] as String? ?? '',
      targetId: json['target_id'] as String?,
      selectedRouteIndex: json['selected_route_index'] as int?,
      selectedRouteLabel: json['selected_route_label'] as String?,
      completedStepLabels: ((json['completed_step_labels'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet(),
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pathway_key': pathwayKey,
      if (targetId != null) 'target_id': targetId,
      if (selectedRouteIndex != null) 'selected_route_index': selectedRouteIndex,
      if (selectedRouteLabel != null) 'selected_route_label': selectedRouteLabel,
      'completed_step_labels': completedStepLabels.toList(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  bool isStepCompleted(String stepLabel) => completedStepLabels.contains(stepLabel);

  PathwayReadinessState copyWith({
    String? pathwayKey,
    String? targetId,
    int? selectedRouteIndex,
    String? selectedRouteLabel,
    Set<String>? completedStepLabels,
    DateTime? lastUpdated,
    bool clearRoute = false,
  }) {
    return PathwayReadinessState(
      pathwayKey: pathwayKey ?? this.pathwayKey,
      targetId: targetId ?? this.targetId,
      selectedRouteIndex: clearRoute ? null : (selectedRouteIndex ?? this.selectedRouteIndex),
      selectedRouteLabel: clearRoute ? null : (selectedRouteLabel ?? this.selectedRouteLabel),
      completedStepLabels: completedStepLabels ?? this.completedStepLabels,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}

/// Pure helper to parse pathway JSON trees and extract routes & active steps.
class PathwayTreeParser {
  const PathwayTreeParser._();

  /// Locates the alternative route group (`op: 'any'`) in the pathway tree.
  static List<PathwayRouteOption> extractRoutes(Map<String, dynamic> tree) {
    final routes = <PathwayRouteOption>[];
    _findAnyNodes(tree, routes);
    return routes;
  }

  static void _findAnyNodes(
    Map<String, dynamic> node,
    List<PathwayRouteOption> routes,
  ) {
    final op = node['op'] as String?;
    if (op == 'any') {
      final children = node['children'] as List?;
      if (children != null) {
        for (int i = 0; i < children.length; i++) {
          final child = children[i];
          if (child is Map<String, dynamic> && child['op'] == 'step') {
            routes.add(PathwayRouteOption(
              index: i,
              label: child['label'] as String? ?? '',
              stage: child['stage'] as String? ?? 'education',
              condition: child['condition'] as String?,
              sourceUrl: child['source_url'] != null
                  ? Uri.tryParse(child['source_url'] as String)
                  : null,
            ));
          }
        }
      }
      return;
    }

    final children = node['children'] as List?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _findAnyNodes(child, routes);
          if (routes.isNotEmpty) return;
        }
      }
    }
  }

  /// Extracts applicable steps based on the learner's chosen route.
  /// If [selectedRouteLabel] is provided, only that specific qualification route
  /// step is included from the `any` alternatives, alongside all mandatory steps.
  /// If [selectedRouteLabel] is null, all alternative steps are included with
  /// `isRouteAlternative: true`.
  static List<PathwayStep> extractApplicableSteps(
    Map<String, dynamic> tree, {
    String? selectedRouteLabel,
  }) {
    final steps = <PathwayStep>[];
    _collectSteps(tree, steps, selectedRouteLabel: selectedRouteLabel, inAnyGroup: false);
    return steps;
  }

  static void _collectSteps(
    Map<String, dynamic> node,
    List<PathwayStep> steps, {
    required String? selectedRouteLabel,
    required bool inAnyGroup,
  }) {
    final op = node['op'] as String?;
    if (op == 'step') {
      final label = node['label'] as String? ?? '';
      final stage = node['stage'] as String? ?? 'other';
      final sourceUrl = Uri.tryParse(node['source_url'] as String? ?? '') ?? Uri();
      final condition = node['condition'] as String?;

      if (inAnyGroup) {
        if (selectedRouteLabel == null) {
          steps.add(PathwayStep(
            label: label,
            stage: stage,
            sourceUrl: sourceUrl,
            condition: condition,
            isRouteAlternative: true,
          ));
        } else if (label == selectedRouteLabel) {
          steps.add(PathwayStep(
            label: label,
            stage: stage,
            sourceUrl: sourceUrl,
            condition: condition,
            isRouteAlternative: true,
          ));
        }
      } else {
        steps.add(PathwayStep(
          label: label,
          stage: stage,
          sourceUrl: sourceUrl,
          condition: condition,
          isRouteAlternative: false,
        ));
      }
      return;
    }

    if (op == 'any') {
      final children = node['children'] as List?;
      if (children != null) {
        for (final child in children) {
          if (child is Map<String, dynamic>) {
            _collectSteps(child, steps,
                selectedRouteLabel: selectedRouteLabel, inAnyGroup: true);
          }
        }
      }
      return;
    }

    final children = node['children'] as List?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _collectSteps(child, steps,
              selectedRouteLabel: selectedRouteLabel, inAnyGroup: inAnyGroup);
        }
      }
    }
  }

  /// Calculates qualitative and quantitative self-reported readiness metrics.
  static ({
    int totalSteps,
    int completedSteps,
    double ratio,
    bool isComplete,
  }) computeReadiness({
    required List<PathwayStep> applicableSteps,
    required Set<String> completedLabels,
  }) {
    if (applicableSteps.isEmpty) {
      return (totalSteps: 0, completedSteps: 0, ratio: 0.0, isComplete: false);
    }
    int completed = 0;
    for (final step in applicableSteps) {
      if (completedLabels.contains(step.label)) {
        completed++;
      }
    }
    final ratio = completed / applicableSteps.length;
    return (
      totalSteps: applicableSteps.length,
      completedSteps: completed,
      ratio: ratio,
      isComplete: completed == applicableSteps.length,
    );
  }
}
