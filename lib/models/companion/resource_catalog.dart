import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/learning_support/external_companion.dart';

/// One part of a catalog resource that covers an objective.
class CatalogSection {
  const CatalogSection({
    required this.label,
    this.locator,
    this.startSeconds,
    required this.depth,
    this.hasPractice,
    required this.confidence,
  });

  final String label;
  final String? locator;
  final int? startSeconds;

  /// introduces, teaches or practises.
  final String depth;
  final bool? hasPractice;
  final String confidence;

  factory CatalogSection.fromJson(Map<String, dynamic> j) => CatalogSection(
    label: '${j['label'] ?? ''}',
    locator: j['locator'] is String ? j['locator'] as String : null,
    startSeconds: j['start_seconds'] is int ? j['start_seconds'] as int : null,
    depth: '${j['depth'] ?? 'introduces'}',
    hasPractice: j['has_practice'] is bool ? j['has_practice'] as bool : null,
    confidence: '${j['confidence'] ?? 'low'}',
  );
}

/// Which objectives of one goal a catalog resource covers.
class CatalogMap {
  const CatalogMap({
    required this.targetSlug,
    required this.resourceId,
    required this.approved,
    required this.coverage,
  });

  final String targetSlug;
  final String resourceId;
  final bool approved;

  /// Objective code to the sections that cover it; empty when not covered.
  final Map<String, List<CatalogSection>> coverage;

  factory CatalogMap.fromJson(Map<String, dynamic> j) => CatalogMap(
    targetSlug: '${j['target_slug'] ?? ''}',
    resourceId: '${j['resource_id'] ?? ''}',
    approved: (j['review'] as Map?)?['status'] == 'approved',
    coverage: {
      for (final c in (j['coverage'] as List? ?? const []))
        if (c is Map)
          '${c['objective']}': [
            for (final s in (c['sections'] as List? ?? const []))
              if (s is Map)
                CatalogSection.fromJson(Map<String, dynamic>.from(s)),
          ],
    },
  );
}

/// A reviewed, link-only outside resource (data/external_resources/).
class CatalogResource {
  const CatalogResource({
    required this.id,
    required this.kind,
    required this.publisher,
    required this.title,
    this.url,
    required this.access,
    this.priceBand,
    this.hasPractice,
    this.captions,
    required this.checkedOn,
    required this.approved,
    this.reviewerKind,
  });

  final String id;
  final LearnerResourceKind kind;
  final String publisher;
  final String title;
  final String? url;
  final ExternalAccess access;
  final String? priceBand;
  final bool? hasPractice;
  final bool? captions;
  final String checkedOn;
  final bool approved;

  /// ai or human: shown with the recommendation, never upgraded.
  final String? reviewerKind;

  factory CatalogResource.fromJson(Map<String, dynamic> j) {
    final review = (j['review'] as Map?) ?? const {};
    return CatalogResource(
      id: '${j['id']}',
      kind: LearnerResourceKind.fromWire(j['kind']),
      publisher: '${j['publisher'] ?? ''}',
      title: '${j['title'] ?? ''}',
      url: j['canonical_url'] is String ? j['canonical_url'] as String : null,
      access: ExternalAccess.fromWire(j['access']) ?? ExternalAccess.paid,
      priceBand: (j['price'] as Map?)?['band'] as String?,
      hasPractice: j['has_practice'] is bool ? j['has_practice'] as bool : null,
      captions: j['captions'] is bool ? j['captions'] as bool : null,
      checkedOn: '${j['metadata_checked_at'] ?? ''}',
      approved: review['status'] == 'approved',
      reviewerKind: review['reviewer_kind'] as String?,
    );
  }
}

class ResourceCatalog {
  const ResourceCatalog({this.resources = const [], this.maps = const []});

  final List<CatalogResource> resources;
  final List<CatalogMap> maps;

  factory ResourceCatalog.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 'la-resource-catalog/1') return const ResourceCatalog();
    return ResourceCatalog(
      resources: [
        for (final r in (j['resources'] as List? ?? const []))
          if (r is Map) CatalogResource.fromJson(Map<String, dynamic>.from(r)),
      ],
      maps: [
        for (final m in (j['maps'] as List? ?? const []))
          if (m is Map) CatalogMap.fromJson(Map<String, dynamic>.from(m)),
      ],
    );
  }
}

/// One way to study a goal, with the reasons it is listed.
class WayToStudy {
  const WayToStudy({
    required this.resource,
    required this.map,
    required this.coverage,
    required this.practiceShare,
  });

  final CatalogResource resource;
  final CatalogMap map;

  /// Share of the goal (by blueprint weight where the goal has it) that the
  /// resource teaches or practises, 0.0 to 1.0.
  final double coverage;

  /// Share of the covered objectives where at least one part has practice.
  final double practiceShare;

  bool get free => resource.access != ExternalAccess.paid;

  /// Plain reasons, in the order a learner weighs them.
  List<String> get reasons => [
    'covers about ${(coverage * 100).round()}% of this goal',
    resource.access.label,
    if (practiceShare >= 0.5) 'has practice for most of what it covers',
    if (practiceShare > 0 && practiceShare < 0.5)
      'has practice for some of what it covers',
    if (resource.captions == true) 'captions',
  ];
}

/// Recommends catalog resources for one goal (companion plan v1.0 §3.5).
///
/// Learner benefit only. A resource is listed only when its record and its
/// map for this goal are both approved. Free resources come first, ordered
/// by coverage then practice; a paid resource is listed only when at least
/// one free one is listed too, and always after it. Nothing else can move a
/// resource up: the catalog has no field for it, and a test reads this file
/// to make sure no such word appears in it.
List<WayToStudy> waysToStudy({
  required String targetSlug,
  required ResourceOutline outline,
  required ResourceCatalog catalog,
}) {
  final byId = {for (final r in catalog.resources) r.id: r};
  final keys = {
    for (final g in outline.groups)
      for (final i in g.items) i.code ?? i.key: i.key,
  };
  final ways = <WayToStudy>[];
  for (final m in catalog.maps) {
    final r = byId[m.resourceId];
    if (m.targetSlug != targetSlug || !m.approved || r == null || !r.approved) {
      continue;
    }
    final covered = <String>{};
    var withPractice = 0;
    for (final e in m.coverage.entries) {
      final real = e.value.where((s) => s.depth != 'introduces').toList();
      final key = keys[e.key];
      if (real.isEmpty || key == null) continue;
      covered.add(key);
      if (real.any((s) => s.hasPractice == true)) withPractice++;
    }
    if (covered.isEmpty) continue;
    ways.add(
      WayToStudy(
        resource: r,
        map: m,
        coverage: outline.coverageShare(covered),
        practiceShare: withPractice / covered.length,
      ),
    );
  }
  int byBenefit(WayToStudy a, WayToStudy b) {
    final c = b.coverage.compareTo(a.coverage);
    if (c != 0) return c;
    final p = b.practiceShare.compareTo(a.practiceShare);
    return p != 0 ? p : a.resource.title.compareTo(b.resource.title);
  }

  final free = ways.where((w) => w.free).toList()..sort(byBenefit);
  final paid = ways.where((w) => !w.free).toList()..sort(byBenefit);
  return [...free, if (free.isNotEmpty) ...paid];
}
