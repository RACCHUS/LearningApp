import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/widgets/targets/exam_preparation_overview_card.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18);

  TargetVersion makeVersion(Map<String, dynamic> metadata) => TargetVersion(
    id: 'version-test',
    targetId: 'target-test',
    versionCode: '2027',
    createdAt: now,
    updatedAt: now,
    status: TargetVersionStatus.published,
    metadata: metadata,
  );

  testWidgets('Draft/unknown facts never imply an official reference checklist',
      (tester) async {
    final version = makeVersion({
      'exam_preparation': {
        'schema_version': 1,
        'exam_parts': [
          {
            'key': 'project_management',
            'display_name': 'Project Management',
            'curriculum_root_node_id': 'node-pm',
            'requirements': {
              'time_limit_minutes': {
                'state': 'unknown',
                'value': null,
                'evidence_ids': [],
              },
            },
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body:
          ExamPreparationOverviewCard(targetVersion: version))),
    );
    expect(find.byKey(const Key('exam-preparation-overview')), findsOneWidget);
    expect(find.text('Project Management'), findsOneWidget);
    expect(find.byKey(const Key('exam-reference-unknown-notice')),
        findsOneWidget);
    expect(find.textContaining('predict a passing result'), findsOneWidget);
  });

  testWidgets('Targets without an exam profile do not show invented parts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body:
          ExamPreparationOverviewCard(targetVersion: makeVersion({})))),
    );
    expect(find.byKey(const Key('exam-preparation-overview')), findsNothing);
  });

  testWidgets('Invalid profiles fail closed rather than showing false facts',
      (tester) async {
    final version = makeVersion({
      'exam_preparation': {
        'schema_version': 1,
        'exam_parts': [
          {'key': 'BAD PART', 'display_name': 'Bad part'},
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body:
          ExamPreparationOverviewCard(targetVersion: version))),
    );
    expect(find.byKey(const Key('exam-preparation-overview')), findsNothing);
  });
}
