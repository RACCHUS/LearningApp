import 'package:learning_pwa/models/learning_support/bridge_lesson.dart';
import 'package:learning_pwa/models/learning_support/support_identifiers.dart';

/// What it takes to open an external resource (master plan v2.6 §9.5:
/// never promise access to paid or login-only material).
enum ExternalAccess {
  freeNoLogin('free_no_login', 'Free · no sign-in'),
  freeWithLogin('free_with_login', 'Free · sign-in needed'),
  paid('paid', 'Paid');

  const ExternalAccess(this.wire, this.label);
  final String wire;
  final String label;

  static ExternalAccess? fromWire(Object? v) {
    for (final a in values) {
      if (a.wire == v) return a;
    }
    return null;
  }
}

/// A link-only pointer to one section of an outside resource (§9.1). It
/// grants no redistribution right and is never completion evidence.
class ExternalResource {
  const ExternalResource({
    required this.publisher,
    required this.title,
    required this.url,
    required this.license,
    required this.access,
    required this.lastCheckedAt,
    this.section,
  });

  final String publisher;
  final String title;
  final String? section;
  final String url;
  final String license;
  final ExternalAccess access;
  final DateTime lastCheckedAt;
}

/// A level-2 companion (§9.2 "Checkpoint"): a section pointer, a focus
/// note in LearningApp's own words, and independent checks that are not
/// copied from the source and use numbers the Bridge has not shown.
class ExternalCompanion {
  const ExternalCompanion({
    required this.companionId,
    required this.bridgeId,
    required this.objectiveId,
    required this.resource,
    required this.focusNote,
    required this.checks,
    required this.humanReviewed,
  });

  static const int currentVersion = 1;

  final String companionId;

  /// The Bridge whose objective this companion supports.
  final String bridgeId;

  /// Must equal that Bridge's objective, so evidence stays comparable.
  final String objectiveId;
  final ExternalResource resource;
  final String focusNote;
  final List<BridgeCheck> checks;
  final bool humanReviewed;

  static ({ExternalCompanion? companion, List<BridgeIssue> issues}) decode(
    Object? json,
  ) {
    final issues = <BridgeIssue>[];
    void issue(String p, String m) => issues.add(BridgeIssue(p, m));
    const p = r'$';
    if (json is! Map) {
      return (companion: null, issues: [const BridgeIssue(p, 'not an object')]);
    }

    String? text(Map m, String key, String path, int max, {bool req = true}) {
      final v = m[key];
      if (v == null) {
        if (req) issue('$path.$key', 'required');
        return null;
      }
      if (v is! String || v.trim().isEmpty) {
        issue('$path.$key', 'must be non-empty text');
        return null;
      }
      if (v.length > max) issue('$path.$key', 'longer than $max characters');
      if (v.contains('<') || v.contains('](')) {
        issue('$path.$key', 'markup and links are not allowed in text');
      }
      return v;
    }

    String? id(String key) {
      final v = json[key];
      if (!SupportIdentifiers.isId(v)) {
        issue('$p.$key', 'must be a safe identifier');
        return null;
      }
      return v as String;
    }

    if (json['companion_version'] != currentVersion) {
      issue('$p.companion_version', 'must be $currentVersion');
    }
    if (json['uses_ai'] != false) {
      issue('$p.uses_ai', 'a companion must work without AI (false)');
    }
    final companionId = id('companion_id');
    final bridgeId = id('bridge_id');
    final objectiveId = id('objective_id');
    final focus = text(json, 'focus_note', p, BridgeLesson.maxPromptLength);

    ExternalResource? resource;
    final r = json['resource'];
    if (r is Map) {
      const rp = '$p.resource';
      final url = r['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        issue('$rp.url', 'must be an https URL');
      }
      if (r['rights_posture'] != 'link_only') {
        issue('$rp.rights_posture', 'companions are link-only');
      }
      final access = ExternalAccess.fromWire(r['access']);
      if (access == null) issue('$rp.access', 'unknown access');
      final checked = r['last_checked_at'] is String
          ? DateTime.tryParse(r['last_checked_at'] as String)
          : null;
      if (checked == null) issue('$rp.last_checked_at', 'must be an ISO date');
      final publisher = text(r, 'publisher', rp, 120);
      final title = text(r, 'title', rp, 200);
      final section = text(r, 'section', rp, 200, req: false);
      final license = text(r, 'license', rp, 200);
      if (uri != null &&
          access != null &&
          checked != null &&
          publisher != null &&
          title != null &&
          license != null) {
        resource = ExternalResource(
          publisher: publisher,
          title: title,
          section: section,
          url: url as String,
          license: license,
          access: access,
          lastCheckedAt: checked,
        );
      }
    } else {
      issue('$p.resource', 'required object');
    }

    final decoded = BridgeLesson.decodeChecks(json['checks'], p);
    issues.addAll(decoded.issues);

    final evidence = json['evidence'];
    bool? reviewed;
    if (evidence is Map && evidence['human_reviewed'] is bool) {
      reviewed = evidence['human_reviewed'] as bool;
      final reviewer = evidence['reviewer'];
      if (reviewed && (reviewer is! String || reviewer.trim().isEmpty)) {
        issue('$p.evidence.reviewer', 'a human review must name who reviewed');
      }
    } else {
      issue('$p.evidence.human_reviewed', 'must be true or false');
    }

    if (issues.isNotEmpty) return (companion: null, issues: issues);
    return (
      companion: ExternalCompanion(
        companionId: companionId!,
        bridgeId: bridgeId!,
        objectiveId: objectiveId!,
        resource: resource!,
        focusNote: focus!,
        checks: List.unmodifiable(decoded.checks),
        humanReviewed: reviewed!,
      ),
      issues: const <BridgeIssue>[],
    );
  }

  /// Cross-checks against the Bridge it supports: same objective, and
  /// every check uses numbers the Bridge never showed (independence).
  List<BridgeIssue> validateAgainst(BridgeLesson bridge) {
    final issues = <BridgeIssue>[];
    if (bridge.bridgeId != bridgeId) {
      issues.add(BridgeIssue(companionId, 'bridge_id mismatch'));
    }
    if (bridge.objectiveId != objectiveId) {
      issues.add(
        BridgeIssue(
          companionId,
          'objective_id must equal the Bridge objective',
        ),
      );
    }
    final shown = bridge.shownSignatures;
    for (final c in checks) {
      if (shown.contains(BridgeLesson.signatureOf(c.template, c.inputs))) {
        issues.add(
          BridgeIssue(c.itemId, 'repeats numbers the Bridge already shows'),
        );
      }
      if (bridge.checks.any((b) => b.itemId == c.itemId)) {
        issues.add(BridgeIssue(c.itemId, 'item id clashes with the Bridge'));
      }
    }
    return issues;
  }
}
