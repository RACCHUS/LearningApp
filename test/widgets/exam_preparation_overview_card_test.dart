import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/widgets/targets/exam_preparation_overview_card.dart';
import 'package:learning_pwa/services/assessment/exam_reference_manifest_service.dart';
import '../test_helpers/fake_supabase_client.dart';

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

  testWidgets('Date picker only reveals approved metadata for that date',
      (tester) async {
    final fake = FakeSupabaseClient();
    fake.setTableData('exam_reference_manifest_revisions', [
      {
        'id': 'approved-fixture',
        'target_version_id': 'version-test',
        'exam_part_key': 'project_management',
        'revision': 1,
        'effective_from': '2000-01-01',
        'effective_until': '2100-12-31',
        'publication_status': 'published',
        'review_status': 'approved',
        'reviewer_ref': 'reviewer-alias',
        'reviewed_at': '2026-10-18T20:00:00Z',
        'source_checked_at': '2026-10-18T19:00:00Z',
        'source_release_id': 'source-release',
        'official_source_url': 'https://example.gov/fixture.pdf',
        'reference_entries': [
          {'key': 'fixture_book', 'title': 'Fixture Handbook',
           'edition': 'Synthetic Edition', 'source_page': '1'},
        ],
        'room_rules': [],
      },
    ]);
    final version = makeVersion({
      'exam_preparation': {
        'schema_version': 1,
        'exam_parts': [
          {
            'key': 'project_management',
            'display_name': 'Project Management',
            'curriculum_root_node_id': 'node-pm',
          }
        ]
      }
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _GuestAuthNotifier())],
      child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExamPreparationOverviewCard(
            targetVersion: version,
            manifestService: ExamReferenceManifestService(supabase: fake),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('Check references'));
    await tester.pumpAndSettle();
    expect(find.text('Select your actual exam administration date'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exam-reference-reviewed')), findsOneWidget);
    expect(find.textContaining('Fixture Handbook'), findsOneWidget);
    expect(find.text('Open official reference source'), findsOneWidget);
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

class _GuestAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _GuestAuthNotifier() : super(GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
