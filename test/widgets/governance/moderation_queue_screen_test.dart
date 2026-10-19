import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/screens/governance/moderation_queue_screen.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';

class FakeModerationService extends Fake implements ModerationService {
  final bool hasModeratorAccess;
  final List<ModerationReport> reports;
  ReportStatus? lastStatusFilter;
  bool actionApplied = false;
  String? lastActionReason;
  ModerationActionType? lastActionType;

  FakeModerationService({
    this.hasModeratorAccess = true,
    this.reports = const [],
  });

  @override
  Future<bool> isModerator() async => hasModeratorAccess;

  @override
  Future<List<ModerationReport>> fetchReports({
    ReportStatus? statusFilter,
    int limit = 50,
  }) async {
    lastStatusFilter = statusFilter;
    if (statusFilter == null) return reports;
    return reports.where((r) => r.status == statusFilter).toList();
  }

  @override
  Future<void> applyModerationAction({
    required String reportId,
    required ModerationActionType action,
    required String reason,
    String? notes,
  }) async {
    actionApplied = true;
    lastActionReason = reason;
    lastActionType = action;
  }
}

void main() {
  Widget createWidgetUnderTest(ModerationService service) {
    return MaterialApp(
      home: ModerationQueueScreen(moderationService: service),
    );
  }

  group('ECO-00B: ModerationQueueScreen Widget Tests', () {
    testWidgets('displays Access Denied when user is not a moderator',
        (tester) async {
      final fakeService = FakeModerationService(hasModeratorAccess: false);

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(
        find.text(
          'You must have the "moderator" or "admin" role to view and process reports in the Trust & Safety Console.',
        ),
        findsOneWidget,
      );
      expect(find.text('Check Access Again'), findsOneWidget);
    });

    testWidgets('displays empty queue state when user is moderator with no reports',
        (tester) async {
      final fakeService = FakeModerationService(
        hasModeratorAccess: true,
        reports: const [],
      );

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Trust & Safety Console'), findsOneWidget);
      expect(
        find.textContaining('ECO-00B Governance Mode'),
        findsOneWidget,
      );
      expect(find.text('Queue is empty'), findsOneWidget);
      expect(find.text('All Reports'), findsOneWidget);
      expect(find.text('Pending Review'), findsOneWidget);
    });

    testWidgets('renders reports with details and opens action dialog',
        (tester) async {
      final sampleReport = ModerationReport(
        id: 'rep-001',
        reporterId: 'usr-999',
        targetType: ModerationTargetType.lesson,
        targetId: 'lesson-bio-1',
        reason: ReportReason.harassment,
        description: 'Contains targeted offensive content',
        status: ReportStatus.pending,
        createdAt: DateTime.utc(2026, 10, 18, 14, 30),
      );

      final fakeService = FakeModerationService(
        hasModeratorAccess: true,
        reports: [sampleReport],
      );

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Lesson #lesson-bio-1'), findsOneWidget);
      expect(find.text('Reason: Harassment or Bullying'), findsOneWidget);
      expect(
        find.text('Reporter notes: "Contains targeted offensive content"'),
        findsOneWidget,
      );
      expect(find.text('Review Action'), findsOneWidget);

      // Tap Review Action
      await tester.tap(find.text('Review Action'));
      await tester.pumpAndSettle();

      // Verify Dialog renders
      expect(find.text('Take Moderation Action'), findsOneWidget);
      expect(find.text('Public / Standard Reason *'), findsOneWidget);
      expect(find.text('Internal Audit Notes (Optional)'), findsOneWidget);
      expect(
        find.textContaining('Audit Trail Notice: Actions are atomic'),
        findsOneWidget,
      );

      // Submit action
      await tester.tap(find.text('Apply Action'));
      await tester.pumpAndSettle();

      expect(fakeService.actionApplied, isTrue);
      expect(
        fakeService.lastActionReason,
        contains('Violates platform safety policy'),
      );
    });

    testWidgets('status filter chip updates query', (tester) async {
      final samplePending = ModerationReport(
        id: 'rep-pending-1',
        reporterId: 'usr-1',
        targetType: ModerationTargetType.course,
        targetId: 'course-1',
        reason: ReportReason.copyrightInfringement,
        status: ReportStatus.pending,
        createdAt: DateTime.utc(2026, 10, 18, 15, 0),
      );

      final sampleResolved = ModerationReport(
        id: 'rep-resolved-1',
        reporterId: 'usr-2',
        targetType: ModerationTargetType.studySet,
        targetId: 'set-1',
        reason: ReportReason.spamPhishing,
        status: ReportStatus.resolvedActionTaken,
        createdAt: DateTime.utc(2026, 10, 18, 14, 0),
        resolvedBy: 'mod-1',
        resolutionNotes: 'Spam removed',
      );

      final fakeService = FakeModerationService(
        hasModeratorAccess: true,
        reports: [samplePending, sampleResolved],
      );

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Course #course-1'), findsOneWidget);
      expect(find.text('Study Set #set-1'), findsOneWidget);

      // Select Pending Review filter
      await tester.tap(find.widgetWithText(FilterChip, 'Pending Review'));
      await tester.pumpAndSettle();

      expect(fakeService.lastStatusFilter, ReportStatus.pending);
      expect(find.text('Course #course-1'), findsOneWidget);
      expect(find.text('Study Set #set-1'), findsNothing);
    });
  });
}
