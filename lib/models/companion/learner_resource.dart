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

/// How the objectives of a section were proposed before the learner
/// confirmed them (companion plan v1.0 §3.4). None of these is a review.
enum SectionMapSource {
  learner('learner'),
  outlineMatch('outline_match'),
  ownAi('own_ai');

  const SectionMapSource(this.wire);
  final String wire;

  static SectionMapSource fromWire(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return learner;
  }
}

/// One part of the learner's outside resource (a chapter, unit or video),
/// with the objectives the learner confirmed it covers.
class ResourceSection {
  const ResourceSection({
    required this.title,
    this.objectiveKeys = const {},
    this.source = SectionMapSource.learner,
    this.minutes,
    this.startSeconds,
    this.studiedAt,
  });

  static const int maxTitleLength = 200;
  static const int maxSections = 200;
  static const int maxKeysPerSection = 50;

  final String title;
  final Set<String> objectiveKeys;
  final SectionMapSource source;

  static const int maxMinutes = 600;

  /// The learner's own estimate of how long this part takes, if they gave one.
  final int? minutes;

  static const int maxStartSeconds = 86400;

  /// Where this part begins in a video, in seconds, if the learner gave it.
  final int? startSeconds;

  /// When the learner marked this part studied. Self-report, never evidence.
  final DateTime? studiedAt;

  bool get studied => studiedAt != null;

  ResourceSection copyWith({DateTime? Function()? studiedAt}) => ResourceSection(
    title: title,
    objectiveKeys: objectiveKeys,
    source: source,
    minutes: minutes,
    startSeconds: startSeconds,
    studiedAt: studiedAt == null ? this.studiedAt : studiedAt(),
  );

  factory ResourceSection.fromJson(Map<String, dynamic> json) => ResourceSection(
    title: '${json['title'] ?? ''}',
    objectiveKeys: {
      for (final k in (json['objective_keys'] as List? ?? const []))
        if (k is String && k.isNotEmpty) k,
    },
    source: SectionMapSource.fromWire(json['map_source'] ?? json['source']),
    minutes: _minutes(json['est_minutes'] ?? json['minutes']),
    startSeconds: _start(json['start_seconds'] ?? json['start']),
    studiedAt: json['studied_at'] is String ? DateTime.tryParse(json['studied_at'] as String) : null,
  );

  static int? _start(Object? v) {
    final n = v is num ? v.round() : null;
    return n != null && n >= 0 && n <= maxStartSeconds ? n : null;
  }

  static int? _minutes(Object? v) {
    final n = v is num ? v.round() : null;
    return n != null && n >= 1 && n <= maxMinutes ? n : null;
  }

  /// The shape `set_learner_resource_sections` takes.
  Map<String, dynamic> toRpcJson() => {
    'title': title,
    'objective_keys': objectiveKeys.toList()..sort(),
    'source': source.wire,
    if (minutes != null) 'minutes': minutes,
    if (startSeconds != null) 'start': startSeconds,
  };

  /// Device storage: the RPC shape plus the studied mark.
  Map<String, dynamic> toJson() => {
    ...toRpcJson(),
    'studied_at': studiedAt?.toUtc().toIso8601String(),
  };
}

/// "25 min", "1 h 35 min", "2 h".
String formatStudyMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
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
    this.sections = const [],
  });

  static const int maxTitleLength = 200;

  final String id;
  final String targetId;
  final String title;
  final LearnerResourceKind kind;
  final String? url;
  final ExternalAccess? access;
  final Map<String, DateTime?> objectives;

  /// The resource's outline, in order. Empty until the learner adds one.
  final List<ResourceSection> sections;

  /// The titles of the sections that cover [key], in outline order.
  List<String> sectionTitlesFor(String key) => [
    for (final s in sections)
      if (s.objectiveKeys.contains(key)) s.title,
  ];

  /// The first part not yet marked studied: where to pick up. Null when
  /// there is no outline or every part is marked.
  int? get nextSectionIndex {
    final i = sections.indexWhere((s) => !s.studied);
    return i < 0 ? null : i;
  }

  int get studiedSectionCount => sections.where((s) => s.studied).length;

  /// The learner's own estimates for the parts not yet studied, added up.
  int get remainingMinutes => sections.where((s) => !s.studied).fold(0, (sum, s) => sum + (s.minutes ?? 0));

  /// Parts not yet studied that have no estimate, so the total is a floor.
  int get remainingWithoutEstimate => sections.where((s) => !s.studied && s.minutes == null).length;

  int get studiedCount => objectives.values.where((v) => v != null).length;

  LearnerResource copyWith({
    String? title,
    LearnerResourceKind? kind,
    String? Function()? url,
    ExternalAccess? Function()? access,
    Map<String, DateTime?>? objectives,
    List<ResourceSection>? sections,
  }) => LearnerResource(
    id: id,
    targetId: targetId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    url: url == null ? this.url : url(),
    access: access == null ? this.access : access(),
    objectives: objectives ?? this.objectives,
    sections: sections ?? this.sections,
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
    final rows = [
      for (final s in (json['learner_resource_sections'] as List? ?? const []))
        if (s is Map) Map<String, dynamic>.from(s),
    ]..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    final url = json['url'];
    return LearnerResource(
      id: '${json['id']}',
      targetId: '${json['target_id']}',
      title: '${json['title'] ?? ''}',
      kind: LearnerResourceKind.fromWire(json['kind']),
      url: url is String && url.isNotEmpty ? url : null,
      access: ExternalAccess.fromWire(json['access']),
      objectives: Map.unmodifiable(objectives),
      sections: List.unmodifiable([
        for (final s in rows)
          if ('${s['title'] ?? ''}'.trim().isNotEmpty) ResourceSection.fromJson(s),
      ]),
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
    'learner_resource_sections': [
      for (final (i, s) in sections.indexed) {...s.toJson(), 'position': i + 1},
    ],
  };
}

/// What is next in the learner's outside study for one goal (companion plan
/// v1.0 §6): the first part not yet marked studied in the first resource
/// that has one, and the learner's own estimates for everything left.
class OutsideStudyPlan {
  const OutsideStudyPlan({
    required this.targetId,
    required this.resourceId,
    required this.resourceTitle,
    required this.sectionTitle,
    required this.sectionMinutes,
    required this.remainingMinutes,
    required this.partsWithoutEstimate,
  });

  final String targetId;
  final String resourceId;
  final String resourceTitle;
  final String sectionTitle;
  final int? sectionMinutes;

  /// Across every resource of the goal, parts not yet studied.
  final int remainingMinutes;
  final int partsWithoutEstimate;

  /// Null when no resource of the goal has a part left to study.
  static OutsideStudyPlan? from(String targetId, List<LearnerResource> resources) {
    final current = resources.where((r) => r.nextSectionIndex != null).firstOrNull;
    if (current == null) return null;
    final part = current.sections[current.nextSectionIndex!];
    return OutsideStudyPlan(
      targetId: targetId,
      resourceId: current.id,
      resourceTitle: current.title,
      sectionTitle: part.title,
      sectionMinutes: part.minutes,
      remainingMinutes: resources.fold(0, (sum, r) => sum + r.remainingMinutes),
      partsWithoutEstimate: resources.fold(0, (sum, r) => sum + r.remainingWithoutEstimate),
    );
  }
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
