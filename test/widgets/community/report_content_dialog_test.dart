import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import 'package:learning_pwa/widgets/community/report_content_dialog.dart';

class _FakeModerationService extends ModerationService {
  ModerationTargetType? reportedType;
  String? reportedId;
  ReportReason? reportedReason;
  String? reportedDesc;

  @override
  Future<String> submitReport({
    required ModerationTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? description,
  }) async {
    reportedType = targetType;
    reportedId = targetId;
    reportedReason = reason;
    reportedDesc = description;
    return 'fake-report-id-123';
  }
}

void main() {
  group('ReportContentDialog (ECO-00B & ECO-01)', () {
    testWidgets('renders dialog elements and submits report', (tester) async {
      final fakeService = _FakeModerationService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportContentDialog(
              targetType: ModerationTargetType.communityQuestion,
              targetId: 'question-456',
              contentSnippet: 'Sample question content snippet',
              moderationService: fakeService,
            ),
          ),
        ),
      );

      expect(find.text('Report Content'), findsOneWidget);
      expect(find.text('"Sample question content snippet"'), findsOneWidget);
      expect(find.text('Reason for reporting:'), findsOneWidget);
      expect(find.byKey(const Key('submit_report_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit_report_button')));
      await tester.pumpAndSettle();

      expect(fakeService.reportedType, equals(ModerationTargetType.communityQuestion));
      expect(fakeService.reportedId, equals('question-456'));
      expect(fakeService.reportedReason, equals(ReportReason.spam));
    });
  });
}
