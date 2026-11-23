import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// What one step of a companion plan asks the learner to do.
enum CompanionPlanPartKind {
  /// Read a section of the outside course (link-only, with its companion's
  /// focus note and independent checks: §9.2 levels 1–2).
  outsideSection('outside_section'),

  /// A short LearningApp lesson for something the outside course skips:
  /// the Bridge is the companion micro-lesson (§9.2 level 3).
  fillIn('fill_in');

  const CompanionPlanPartKind(this.wire);
  final String wire;

  static CompanionPlanPartKind? fromWire(Object? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return null;
  }
}

class CompanionPlanPart {
  const CompanionPlanPart({
    required this.partId,
    required this.bridgeId,
    required this.kind,
  });

  final String partId;

  /// The Bridge this step uses: its companion for an outside section, or
  /// the Bridge itself as a fill-in lesson.
  final String bridgeId;
  final CompanionPlanPartKind kind;
}

/// A full companion plan (master plan v2.6 §9.2 level 4): ordered
/// companion tasks across a multi-part outside course, made only of
/// already-validated companions and Bridges, so it adds order but no new
/// claims. Works without AI; progress is the learner's own ticks, kept on
/// the device and never counted as evidence.
class CompanionPlan {
  const CompanionPlan({
    required this.planId,
    required this.title,
    required this.intro,
    required this.parts,
  });

  static const int currentVersion = 1;
  static const int minParts = 2;
  static const int maxParts = 20;

  final String planId;
  final String title;
  final String intro;
  final List<CompanionPlanPart> parts;

  int indexOfBridge(String bridgeId) =>
      parts.indexWhere((p) => p.bridgeId == bridgeId);

  static ({CompanionPlan? plan, List<BridgeIssue> issues}) decode(Object? json) {
    final issues = <BridgeIssue>[];
    void issue(String p, String m) => issues.add(BridgeIssue(p, m));
    const p = r'$';
    if (json is! Map) {
      return (plan: null, issues: [const BridgeIssue(p, 'not an object')]);
    }
    String? text(String key, int max) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        issue('$p.$key', 'must be non-empty text');
        return null;
      }
      if (v.length > max) issue('$p.$key', 'longer than $max characters');
      if (v.contains('<') || v.contains('](')) {
        issue('$p.$key', 'markup and links are not allowed in text');
      }
      return v;
    }

    if (json['plan_version'] != currentVersion) {
      issue('$p.plan_version', 'must be $currentVersion');
    }
    if (json['uses_ai'] != false) {
      issue('$p.uses_ai', 'a companion plan must work without AI (false)');
    }
    final planId = json['plan_id'];
    if (!SupportIdentifiers.isId(planId)) issue('$p.plan_id', 'must be a safe identifier');
    final title = text('title', 120);
    final intro = text('intro', BridgeLesson.maxPromptLength);

    final parts = <CompanionPlanPart>[];
    final raw = json['parts'];
    if (raw is! List || raw.length < minParts || raw.length > maxParts) {
      issue('$p.parts', 'must list $minParts to $maxParts steps');
    } else {
      final ids = <String>{};
      final bridges = <String>{};
      for (final (i, r) in raw.indexed) {
        final pp = '$p.parts[$i]';
        if (r is! Map) {
          issue(pp, 'not an object');
          continue;
        }
        final partId = r['part_id'];
        final bridgeId = r['bridge_id'];
        final kind = CompanionPlanPartKind.fromWire(r['kind']);
        if (!SupportIdentifiers.isId(partId)) issue('$pp.part_id', 'must be a safe identifier');
        if (!SupportIdentifiers.isId(bridgeId)) issue('$pp.bridge_id', 'must be a safe identifier');
        if (kind == null) issue('$pp.kind', 'must be outside_section or fill_in');
        if (partId is String && !ids.add(partId)) issue('$pp.part_id', 'duplicate');
        if (bridgeId is String && !bridges.add(bridgeId)) issue('$pp.bridge_id', 'used twice');
        if (SupportIdentifiers.isId(partId) && SupportIdentifiers.isId(bridgeId) && kind != null) {
          parts.add(CompanionPlanPart(
            partId: partId as String,
            bridgeId: bridgeId as String,
            kind: kind,
          ));
        }
      }
      if (parts.isNotEmpty &&
          !parts.any((x) => x.kind == CompanionPlanPartKind.outsideSection)) {
        issue('$p.parts', 'a companion plan follows an outside course: add an outside_section');
      }
    }

    if (issues.isNotEmpty) return (plan: null, issues: issues);
    return (
      plan: CompanionPlan(
        planId: planId as String,
        title: title!,
        intro: intro!,
        parts: List.unmodifiable(parts),
      ),
      issues: const <BridgeIssue>[],
    );
  }

  /// Every step must resolve: its Bridge exists, and an outside section
  /// has a valid companion for that Bridge.
  List<BridgeIssue> validateAgainst({
    required bool Function(String bridgeId) hasBridge,
    required bool Function(String bridgeId) hasCompanion,
  }) {
    final issues = <BridgeIssue>[];
    for (final part in parts) {
      if (!hasBridge(part.bridgeId)) {
        issues.add(BridgeIssue(part.partId, 'unknown bridge ${part.bridgeId}'));
      } else if (part.kind == CompanionPlanPartKind.outsideSection &&
          !hasCompanion(part.bridgeId)) {
        issues.add(BridgeIssue(part.partId, 'no companion for ${part.bridgeId}'));
      }
    }
    return issues;
  }
}
