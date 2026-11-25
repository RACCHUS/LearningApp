import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';

/// Where one objective of a goal can be studied (companion plan v1.0 §3.1
/// "Place" and "Fill", EX-2).
enum GoalCoverageKind {
  /// In something the learner uses, and LearningApp has lessons too.
  outsideAndApp,

  /// Only in something the learner uses. LearningApp has no lesson, so it
  /// cannot check this objective yet.
  outsideOnly,

  /// Not in anything the learner uses, but LearningApp has lessons: the
  /// gap LearningApp can fill today.
  appOnly,

  /// In neither. Never shown as done or as zero progress.
  nothing,
}

/// One objective with everything known about where it is covered.
class GoalCoverageEntry {
  const GoalCoverageEntry({
    required this.item,
    required this.groupTitle,
    required this.outsideTitles,
    required this.row,
  });

  final ResourceOutlineItem item;
  final String groupTitle;

  /// Titles of the learner's resources that cover this objective.
  final List<String> outsideTitles;

  /// LearningApp's own content for this objective, when the goal has a
  /// published Coverage Matrix. Null: unknown.
  final CoverageRow? row;

  bool get coveredOutside => outsideTitles.isNotEmpty;

  /// True when LearningApp has teaching content for it.
  bool get appHasLessons {
    final teach = row?.cells[CoverageRole.teach];
    return teach != null && teach != CoverageState.gap && teach != CoverageState.draft;
  }

  /// True when LearningApp has at least one independent check for it.
  bool get appHasChecks {
    final check = row?.cells[CoverageRole.check];
    return check == CoverageState.verified || check == CoverageState.partial;
  }

  GoalCoverageKind get kind => coveredOutside
      ? (appHasLessons ? GoalCoverageKind.outsideAndApp : GoalCoverageKind.outsideOnly)
      : (appHasLessons ? GoalCoverageKind.appOnly : GoalCoverageKind.nothing);
}

/// A goal's objectives placed against the learner's outside resources and
/// LearningApp's own content. Derived on the device from data the learner
/// can already see; nothing here is stored or counts as evidence.
class GoalCoverage {
  GoalCoverage._(this.outline, this.entries, this.appContentKnown);

  final ResourceOutline outline;
  final List<GoalCoverageEntry> entries;

  /// False when the goal has no published Coverage Matrix, so only the
  /// outside half of the picture is known.
  final bool appContentKnown;

  factory GoalCoverage.build({
    required ResourceOutline outline,
    required List<LearnerResource> resources,
    required List<CoverageRow>? coverageRows,
  }) {
    final byCode = <String, CoverageRow>{};
    final byTitle = <String, CoverageRow>{};
    for (final r in coverageRows ?? const <CoverageRow>[]) {
      final code = (r.code ?? '').trim();
      if (code.isNotEmpty) byCode[code] = r;
      byTitle[r.title.trim()] = r;
    }
    final entries = <GoalCoverageEntry>[];
    for (final g in outline.groups) {
      for (final item in g.items) {
        entries.add(
          GoalCoverageEntry(
            item: item,
            groupTitle: g.title,
            outsideTitles: [
              for (final r in resources)
                if (r.objectives.containsKey(item.key)) r.title,
            ],
            // A coded objective matches by code only; one without a code is
            // stored by its title, so match that.
            row: item.code != null ? byCode[item.code] : byTitle[item.key],
          ),
        );
      }
    }
    return GoalCoverage._(outline, entries, (coverageRows ?? const []).isNotEmpty);
  }

  List<GoalCoverageEntry> of(GoalCoverageKind kind) => [
    for (final e in entries)
      if (e.kind == kind) e,
  ];

  Set<String> _keys(bool Function(GoalCoverageEntry) test) => {
    for (final e in entries)
      if (test(e)) e.item.key,
  };

  /// Share of the goal (by blueprint weight where it has weights) in
  /// something the learner uses.
  double get outsideShare => outline.coverageShare(_keys((e) => e.coveredOutside));

  /// Share not in the learner's resources that LearningApp has lessons for.
  double get appOnlyShare => outline.coverageShare(_keys((e) => e.kind == GoalCoverageKind.appOnly));

  /// Share covered by neither.
  double get nothingShare => outline.coverageShare(_keys((e) => e.kind == GoalCoverageKind.nothing));

  /// Covered outside, but LearningApp has no independent check for it, so
  /// studying it cannot move readiness yet.
  List<GoalCoverageEntry> get uncheckable => [
    for (final e in entries)
      if (e.coveredOutside && !e.appHasChecks) e,
  ];

  /// Whole-number percentages that always add up to 100, largest remainder
  /// first, for the three-way split shown to the learner.
  ({int outside, int appOnly, int nothing}) get percents {
    final raw = [outsideShare * 100, appOnlyShare * 100, nothingShare * 100];
    final floors = [for (final v in raw) v.floor()];
    var left = 100 - floors.fold(0, (a, b) => a + b);
    final order = [0, 1, 2]..sort((a, b) => (raw[b] - floors[b]).compareTo(raw[a] - floors[a]));
    for (final i in order) {
      if (left <= 0) break;
      floors[i]++;
      left--;
    }
    return (outside: floors[0], appOnly: floors[1], nothing: floors[2]);
  }
}
