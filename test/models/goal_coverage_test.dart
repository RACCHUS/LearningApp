import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/companion/goal_coverage.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';

ResourceOutline outline({bool weighted = true}) => ResourceOutline([
  ResourceOutlineGroup(
    title: 'Algebra',
    weight: weighted ? 60 : null,
    items: const [
      ResourceOutlineItem(key: '1.1', code: '1.1', label: '1.1 Exponents'),
      ResourceOutlineItem(key: '1.2', code: '1.2', label: '1.2 Radicals'),
      ResourceOutlineItem(key: '1.3', code: '1.3', label: '1.3 Polynomials'),
    ],
  ),
  ResourceOutlineGroup(
    title: 'Functions',
    weight: weighted ? 40 : null,
    items: const [
      ResourceOutlineItem(key: '2.1', code: '2.1', label: '2.1 Graphs'),
      ResourceOutlineItem(key: 'Uncoded', label: 'Uncoded'),
    ],
  ),
]);

CoverageRow row(String code, {CoverageState teach = CoverageState.reviewed, CoverageState check = CoverageState.gap, String? title}) =>
    CoverageRow(
      objectiveId: 'node-$code',
      code: code.isEmpty ? null : code,
      title: title ?? 'T$code',
      cells: {CoverageRole.teach: teach, CoverageRole.check: check},
    );

LearnerResource resource(String title, Set<String> keys) => LearnerResource(
  id: title,
  targetId: 't',
  title: title,
  kind: LearnerResourceKind.course,
  objectives: {for (final k in keys) k: null},
);

void main() {
  final rows = [
    row('1.1', check: CoverageState.verified),
    row('1.2', check: CoverageState.partial),
    row('1.3', teach: CoverageState.gap),
    row('2.1'),
    row('', title: 'Uncoded', teach: CoverageState.gap),
  ];

  test('each objective is placed by where it can be studied', () {
    final c = GoalCoverage.build(
      outline: outline(),
      resources: [resource('Course A', {'1.1', '1.3'}), resource('Book B', {'1.1'})],
      coverageRows: rows,
    );
    GoalCoverageKind kindOf(String key) => c.entries.firstWhere((e) => e.item.key == key).kind;
    expect(kindOf('1.1'), GoalCoverageKind.outsideAndApp);
    expect(kindOf('1.3'), GoalCoverageKind.outsideOnly);
    expect(kindOf('1.2'), GoalCoverageKind.appOnly);
    expect(kindOf('2.1'), GoalCoverageKind.appOnly);
    expect(kindOf('Uncoded'), GoalCoverageKind.nothing);
    expect(c.entries.first.outsideTitles, ['Course A', 'Book B']);
    expect(c.appContentKnown, isTrue);
  });

  test('shares use blueprint weights and the percentages add up to 100', () {
    final c = GoalCoverage.build(
      outline: outline(),
      resources: [resource('Course A', {'1.1', '1.3'})],
      coverageRows: rows,
    );
    // Algebra is 60 with 3 objectives (20 each); Functions is 40 with 2 (20 each).
    expect(c.outsideShare, closeTo(0.40, 1e-9));
    expect(c.appOnlyShare, closeTo(0.40, 1e-9));
    expect(c.nothingShare, closeTo(0.20, 1e-9));
    final p = c.percents;
    expect((p.outside, p.appOnly, p.nothing), (40, 40, 20));
  });

  test('rounding never loses or invents a percent', () {
    final c = GoalCoverage.build(
      outline: ResourceOutline([
        const ResourceOutlineGroup(
          title: 'A',
          items: [
            ResourceOutlineItem(key: '1', code: '1', label: '1'),
            ResourceOutlineItem(key: '2', code: '2', label: '2'),
            ResourceOutlineItem(key: '3', code: '3', label: '3'),
          ],
        ),
      ]),
      resources: [resource('R', {'1'})],
      coverageRows: [row('2'), row('3', teach: CoverageState.gap)],
    );
    final p = c.percents;
    expect(p.outside + p.appOnly + p.nothing, 100);
    expect({p.outside, p.appOnly, p.nothing}, {33, 34});
  });

  test('what is studied outside but has no independent check is named', () {
    final c = GoalCoverage.build(
      outline: outline(),
      resources: [resource('Course A', {'1.1', '1.2', '1.3', '2.1'})],
      coverageRows: rows,
    );
    // 1.1 is independently checked and 1.2 has some checks; 1.3 and 2.1 have none.
    expect(c.uncheckable.map((e) => e.item.key), ['1.3', '2.1']);
  });

  test("a learner's own draft is not a LearningApp lesson", () {
    final c = GoalCoverage.build(
      outline: outline(),
      resources: const [],
      coverageRows: [row('1.1', teach: CoverageState.draft)],
    );
    expect(c.entries.first.appHasLessons, isFalse);
    expect(c.entries.first.kind, GoalCoverageKind.nothing);
  });

  test('without a Coverage Matrix only the outside half is known', () {
    final c = GoalCoverage.build(
      outline: outline(weighted: false),
      resources: [resource('Course A', {'1.1'})],
      coverageRows: null,
    );
    expect(c.appContentKnown, isFalse);
    expect(c.outsideShare, closeTo(0.2, 1e-9));
    expect(c.of(GoalCoverageKind.appOnly), isEmpty);
    expect(c.entries.every((e) => e.row == null), isTrue);
  });

  test('a coded objective never matches a row by title', () {
    final c = GoalCoverage.build(
      outline: outline(),
      resources: const [],
      coverageRows: [row('9.9', title: '1.1')],
    );
    expect(c.entries.first.row, isNull);
  });
}
