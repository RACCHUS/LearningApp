import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/diagnostic_assessment_provider.dart';
import 'package:learning_pwa/services/assessment/diagnostic_assessment_service.dart';

import '../test_helpers/fake_supabase_client.dart';

void main() {
  group('DiagnosticSessionNotifier response completeness', () {
    late DiagnosticSessionNotifier notifier;

    setUp(() {
      notifier = DiagnosticSessionNotifier(
        DiagnosticAssessmentService(supabase: FakeSupabaseClient()),
        (targetId: 'target-1', targetVersionId: 'version-1'),
      );
    });

    tearDown(() {
      notifier.dispose();
    });

    test('empty multi-select response is treated as unanswered', () {
      notifier.recordResponse('item-1', <int>[0, 2]);
      expect(notifier.state.responses, contains('item-1'));

      notifier.recordResponse('item-1', <int>[]);
      expect(notifier.state.responses, isNot(contains('item-1')));
    });

    test('empty map and blank string are treated as unanswered', () {
      notifier.recordResponse('item-1', <String, String>{});
      notifier.recordResponse('item-2', '   ');

      expect(notifier.state.responses, isEmpty);
    });

    test('numeric zero remains a valid single-choice response', () {
      notifier.recordResponse('item-1', 0);

      expect(notifier.state.responses['item-1'], 0);
    });
  });
}
