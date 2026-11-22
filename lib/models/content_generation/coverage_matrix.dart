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
