import 'package:learning_pwa/services/learning_support/bridge_library.dart';

/// The Coverage Matrix (master plan v2.6 §4.2): for every objective in
/// scope, one row; each cell is a role × source state. A derived view,
/// never a new source of truth.
enum CoverageRole {
  teach('Teach'),
  example('Example'),
  practice('Practice'),
  check('Check'),
  bridge('Bridge'),
  access('Access');

  const CoverageRole(this.label);
  final String label;
}

/// Cell states with the plan's icon and the text label it requires.
enum CoverageState {
  reviewed('✓', 'Reviewed'),
  imported('◐', 'Imported'),
  external('⇢', 'Outside resource'),
  draft('✎', 'Your draft'),
  gap('○', 'Not available yet'),
  notVerified('?', 'Not yet verified');

  const CoverageState(this.icon, this.label);
  final String icon;
  final String label;
}

class CoverageRow {
  const CoverageRow({
    required this.objectiveId,
    required this.code,
    required this.title,
    required this.cells,
  });

  final String objectiveId;
  final String? code;
  final String title;
  final Map<CoverageRole, CoverageState> cells;

  /// Content roles a learner's own private lesson can stand in for.
  static const draftableRoles = {
    CoverageRole.teach,
    CoverageRole.example,
    CoverageRole.practice,
    CoverageRole.check,
  };

  /// The same row with its content gaps marked "Your draft", for a learner
  /// who attached a private lesson to this objective. Reviewed and
  /// imported cells are left as they are: a draft never outranks them.
  CoverageRow withDraft() => CoverageRow(
        objectiveId: objectiveId,
        code: code,
        title: title,
        cells: {
          for (final e in cells.entries)
            e.key: e.value == CoverageState.gap && draftableRoles.contains(e.key)
                ? CoverageState.draft
                : e.value,
        },
      );

  List<CoverageRole> get gaps => [
    for (final e in cells.entries)
      if (e.value == CoverageState.gap) e.key,
  ];

  /// Builds a row from `get_coverage_matrix` data and the bundled Bridges.
  ///
  /// Content cells are "Imported" while any lesson is tagged `unreviewed`,
  /// "Reviewed" otherwise, and a gap when nothing is there. The Bridge cell
  /// uses the Bridges that apply to the objective's lesson tags (Bridges are
  /// not yet human-reviewed, so "Imported"). Access is "Not yet verified":
  /// read-aloud exists for all text, but no accessible adaptation has been
  /// checked for these objectives.
  factory CoverageRow.fromServer(Map<String, dynamic> row, BridgeLibrary bridges) {
    final unreviewed = row['unreviewed'] == true;
    CoverageState content(String key) {
      final n = (row[key] as num?)?.toInt() ?? 0;
      if (n == 0) return CoverageState.gap;
      return unreviewed ? CoverageState.imported : CoverageState.reviewed;
    }

    final tags = [
      for (final t in (row['tags'] as List? ?? const [])) t.toString(),
    ];
    final helps = bridges.forLesson(tags).bridges;
    return CoverageRow(
      objectiveId: row['objective_id'].toString(),
      code: row['code'] as String?,
      title: row['title']?.toString() ?? '',
      cells: {
        CoverageRole.teach: content('teach_blocks'),
        CoverageRole.example: content('example_blocks'),
        CoverageRole.practice: content('practice_items'),
        CoverageRole.check: content('check_items'),
        CoverageRole.bridge: helps.isEmpty
            ? CoverageState.gap
            : helps.every((b) => b.evidence.humanReviewed)
                ? CoverageState.reviewed
                : CoverageState.imported,
        CoverageRole.access: CoverageState.notVerified,
      },
    );
  }
}

/// One missing piece for one objective: what the Need cards and the Create
/// chooser's need list show (master plan v2.6 §13.0).
class CoverageNeed {
  const CoverageNeed({required this.row, required this.missing});

  final CoverageRow row;
  final List<CoverageRole> missing;

  String get missingLabel => missing.map((r) => r.label).join(', ');
}

/// Per-role counts of each state across a target's objectives, for the
/// Target Detail chips. Derived from the rows; never stored.
class CoverageSummary {
  CoverageSummary(this.rows);

  final List<CoverageRow> rows;

  Map<CoverageState, int> countsFor(CoverageRole role) {
    final out = <CoverageState, int>{};
    for (final r in rows) {
      final s = r.cells[role];
      if (s != null) out[s] = (out[s] ?? 0) + 1;
    }
    return out;
  }

  /// Objectives with at least one content gap (Teach, Example, Practice,
  /// Check or Bridge), in outline order. Access is "not yet verified"
  /// everywhere, so it is not listed as a need.
  List<CoverageNeed> get needs => [
        for (final r in rows)
          if (r.gaps.where((g) => g != CoverageRole.access).isNotEmpty)
            CoverageNeed(
              row: r,
              missing: [
                for (final g in r.gaps)
                  if (g != CoverageRole.access) g,
              ],
            ),
      ];
}
