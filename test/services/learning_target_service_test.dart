import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/services/learning_target_service.dart';
import '../test_helpers/fake_supabase_client.dart';

void main() {
  test('exam query filters on the server before applying the result limit', () async {
    final fake = FakeSupabaseClient();
    fake.setTableData('learning_targets', [
      for (var i = 0; i < 60; i++)
        {
          'id': 'career-$i',
          'target_type': 'career',
          'title': 'Career $i',
          'slug': 'career-$i',
          'status': 'published',
        },
      {
        'id': 'exam-1',
        'target_type': 'standardized_exam',
        'title': 'Zzz Exam',
        'slug': 'zzz-exam',
        'status': 'published',
      },
    ]);

    final exams = await LearningTargetService(supabase: fake).getTargets(
      types: const [TargetType.standardizedExam, TargetType.licensureExam],
    );

    expect(exams.map((e) => e.id), ['exam-1']);
  });

  test('cluster includes a published target linked through a supporting field', () async {
    final fake = FakeSupabaseClient();
    fake.setTableData('catalog_cluster_fields', [
      {
        'cluster_id': 'cluster-1',
        'fields': {'id': 'field-1', 'name': 'Engineering', 'slug': 'engineering'},
      },
    ]);
    fake.setTableData('learning_targets', [
      {
        'id': 'target-direct',
        'target_type': 'career',
        'field_id': 'field-1',
        'title': 'Engineer',
        'slug': 'engineer',
        'status': 'published',
      },
    ]);
    fake.setTableData('learning_target_fields', [
      {
        'field_id': 'field-1',
        'learning_targets': {
          'id': 'target-supporting',
          'target_type': 'career',
          'field_id': 'other-field',
          'title': 'Industrial Designer',
          'slug': 'industrial-designer',
          'status': 'published',
        },
      },
    ]);

    final targets = await LearningTargetService(supabase: fake)
        .getTargetsForCluster('cluster-1');

    expect(targets.map((e) => e.id),
        ['target-direct', 'target-supporting']);
  });
}
