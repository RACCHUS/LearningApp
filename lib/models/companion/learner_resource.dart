import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';

/// What kind of thing the learner is studying outside LearningApp
/// (companion plan v1.0 §3.3). Wire values match the database check.
enum LearnerResourceKind {
  course('course', 'Course'),
  video('video', 'Video'),
  videoSeries('video_series', 'Video series'),
  book('book', 'Book'),
  article('article', 'Article'),
  podcast('podcast', 'Podcast'),
  classroom('class', 'Class'),
  other('other', 'Something else');

  const LearnerResourceKind(this.wire, this.label);
  final String wire;
  final String label;

  static LearnerResourceKind fromWire(Object? v) {
    for (final k in values) {
      if (k.wire == v) return k;
    }
    return other;
  }
}

/// A learner's own outside resource for one goal. Private to the learner.
/// [objectives] maps each objective key the learner says it covers to when
/// they marked it studied (null: not yet). "Studied" is self-report and is
/// never evidence of readiness (§3.2).
class LearnerResource {
  const LearnerResource({
    required this.id,
    required this.targetId,
    required this.title,
    required this.kind,
    this.url,
    this.access,
    this.objectives = const {},
  });

  static const int maxTitleLength = 200;

  final String id;
  final String targetId;
  final String title;
  final LearnerResourceKind kind;
  final String? url;
  final ExternalAccess? access;
  final Map<String, DateTime?> objectives;

  int get studiedCount => objectives.values.where((v) => v != null).length;

  LearnerResource copyWith({
    String? title,
    LearnerResourceKind? kind,
    String? Function()? url,
    ExternalAccess? Function()? access,
    Map<String, DateTime?>? objectives,
  }) => LearnerResource(
    id: id,
    targetId: targetId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    url: url == null ? this.url : url(),
    access: access == null ? this.access : access(),
    objectives: objectives ?? this.objectives,
  );

  /// From a `learner_external_resources` row with its embedded
  /// `learner_resource_objectives`, or from device-local JSON.
  factory LearnerResource.fromJson(Map<String, dynamic> json) {
    final objectives = <String, DateTime?>{};
    for (final o in (json['learner_resource_objectives'] as List? ?? const [])) {
      if (o is! Map) continue;
      final key = o['objective_key'];
      if (key is! String || key.isEmpty) continue;
      final at = o['studied_at'];
      objectives[key] = at is String ? DateTime.tryParse(at) : null;
    }
    final url = json['url'];
    return LearnerResource(
      id: '${json['id']}',
      targetId: '${json['target_id']}',
      title: '${json['title'] ?? ''}',
      kind: LearnerResourceKind.fromWire(json['kind']),
      url: url is String && url.isNotEmpty ? url : null,
      access: ExternalAccess.fromWire(json['access']),
      objectives: Map.unmodifiable(objectives),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target_id': targetId,
    'title': title,
    'kind': kind.wire,
    'url': url,
    'access': access?.wire,
    'learner_resource_objectives': [
      for (final e in objectives.entries)
        {'objective_key': e.key, 'studied_at': e.value?.toUtc().toIso8601String()},
    ],
  };
}

/// Result of cleaning a link the learner typed or pasted.
class NormalizedLink {
  const NormalizedLink.ok(this.url) : error = null;
  const NormalizedLink.invalid(this.error) : url = null;

  /// Null when the field was empty (a resource needs no link) or invalid.
  final String? url;
  final String? error;
}

const _trackingParams = {
  'fbclid', 'gclid', 'dclid', 'msclkid', 'yclid', 'igshid', 'mc_cid', 'mc_eid',
  'si', 'ref_src', '_hsenc', '_hsmi', 'mkt_tok', 'srsltid', //
};

/// Cleans a learner-supplied link on the device before it is saved (§7.3):
/// https only, no sign-in details in the address, tracking parameters
/// removed. The link is never fetched by LearningApp.
NormalizedLink normalizeLearnerLink(String input) {
  var text = input.trim();
  if (text.isEmpty) return const NormalizedLink.ok(null);
  if (!text.contains('://')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.') || text.contains(RegExp(r'\s'))) {
    return const NormalizedLink.invalid('That does not look like a web link.');
  }
  if (uri.scheme != 'https') {
    return const NormalizedLink.invalid('Use a link that starts with https://');
  }
  if (uri.userInfo.isNotEmpty) {
    return const NormalizedLink.invalid('Remove the sign-in details from the link.');
  }
  final kept = <String, List<String>>{
    for (final e in uri.queryParametersAll.entries)
      if (!_trackingParams.contains(e.key.toLowerCase()) && !e.key.toLowerCase().startsWith('utm_'))
        e.key: e.value,
  };
  final cleaned = Uri(
    scheme: 'https',
    host: uri.host.toLowerCase(),
    port: uri.hasPort && uri.port != 443 ? uri.port : null,
    path: uri.path,
    queryParameters: kept.isEmpty ? null : kept,
    fragment: uri.hasFragment && uri.fragment.isNotEmpty ? uri.fragment : null,
  ).toString();
  if (cleaned.length > 2000) {
    return const NormalizedLink.invalid('That link is too long.');
  }
  return NormalizedLink.ok(cleaned);
}

/// One thing the learner can tick: an objective (or, in a goal without
/// objectives, its smallest topic).
class ResourceOutlineItem {
  const ResourceOutlineItem({required this.key, required this.label, this.code, this.weight});

  /// The objective code, or the title where the node has no code. This is
  /// what is stored, so it survives a new version of the goal.
  final String key;
  final String label;
  final String? code;

  /// The item's own blueprint weight, when the goal weights it directly.
  final double? weight;
}

class ResourceOutlineGroup {
  const ResourceOutlineGroup({required this.title, required this.items, this.weight});
  final String title;
  final List<ResourceOutlineItem> items;

  /// The blueprint weight of this area, when the goal states one.
  final double? weight;
}

/// The goal's objectives grouped by area, for ticking what a resource covers.
class ResourceOutline {
  const ResourceOutline(this.groups);
  final List<ResourceOutlineGroup> groups;

  int get itemCount => groups.fold(0, (n, g) => n + g.items.length);
  Set<String> get keys => {for (final g in groups) for (final i in g.items) i.key};

  /// Built from the goal's curriculum nodes: every node without children is
  /// tickable, grouped under its parent.
  factory ResourceOutline.fromNodes(List<CurriculumNode> nodes) {
    final sorted = [...nodes]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final parents = {for (final n in sorted) if (n.parentId != null) n.parentId!};
    final byId = {for (final n in sorted) n.id: n};
    final groups = <String?, List<ResourceOutlineItem>>{};
    final seen = <String>{};
    for (final n in sorted) {
      if (parents.contains(n.id)) continue;
      final code = (n.code ?? '').trim();
      final key = code.isNotEmpty ? code : n.title.trim();
      if (key.isEmpty || key.length > 200 || !seen.add(key)) continue;
      (groups[n.parentId] ??= []).add(
        ResourceOutlineItem(
          key: key,
          code: code.isEmpty ? null : code,
          weight: n.weight,
          label: code.isEmpty ? n.title : '$code ${n.title}',
        ),
      );
    }
    // Sort order is per parent, so order the areas by their own position,
    // not by where their first objective happened to fall.
    final ordered = groups.entries.toList()
      ..sort((a, b) => (byId[a.key]?.sortOrder ?? 0).compareTo(byId[b.key]?.sortOrder ?? 0));
    return ResourceOutline([
      for (final e in ordered)
        ResourceOutlineGroup(
          title: byId[e.key]?.title ?? 'Topics',
          weight: byId[e.key]?.weight,
          items: e.value,
        ),
    ]);
  }

  bool get _groupsWeighted => groups.isNotEmpty && groups.every((g) => (g.weight ?? 0) > 0);
  bool get _itemsWeighted =>
      itemCount > 0 && groups.every((g) => g.items.every((i) => (i.weight ?? 0) > 0));

  /// How much of the goal the covered keys account for, 0.0 to 1.0. Uses
  /// blueprint weights when every area (or every item) has one, else a
  /// plain count.
  double coverageShare(Set<String> covered) {
    if (itemCount == 0) return 0;
    if (!_groupsWeighted) {
      if (_itemsWeighted) {
        final items = [for (final g in groups) ...g.items];
        final all = items.fold(0.0, (s, i) => s + i.weight!);
        return items.where((i) => covered.contains(i.key)).fold(0.0, (s, i) => s + i.weight!) / all;
      }
      return keys.where(covered.contains).length / itemCount;
    }
    final total = groups.fold(0.0, (s, g) => s + g.weight!);
    var share = 0.0;
    for (final g in groups) {
      if (g.items.isEmpty) continue;
      share += g.weight! / total * g.items.where((i) => covered.contains(i.key)).length / g.items.length;
    }
    return share;
  }

  bool get usesWeights => _groupsWeighted || _itemsWeighted;
}
