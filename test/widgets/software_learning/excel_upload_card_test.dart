import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/software_learning_attempt.dart';
import 'package:learning_pwa/widgets/software_learning/excel_upload_card.dart';

void main() {
  Widget buildTestWidget({
    String? attemptId,
    Duration initialDuration = const Duration(minutes: 45),
    VoidCallback? onComplete,
    Future<SoftwareLearningResult> Function(String, Uint8List, String)? onUpload,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExcelUploadCard(
            attemptId: attemptId,
            initialDuration: initialDuration,
            onComplete: onComplete,
            onUpload: onUpload,
          ),
        ),
      ),
    );
  }

  group('ExcelUploadCard UI & Accessibility Tests', () {
    testWidgets('renders unverified practice badge, timer, and privacy notice',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(attemptId: 'ba430000-0000-4000-8000-000000000001'));
      await tester.pump();

      expect(find.text('Excel Workbook Practice'), findsOneWidget);
      expect(find.text('UNVERIFIED PRACTICE'), findsOneWidget);
      expect(find.textContaining('Time Remaining: 45:00'), findsOneWidget);
      expect(find.textContaining('Attempt: ba430000...'), findsOneWidget);
      expect(
        find.textContaining('Privacy & Verification Gate'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('excel-browse-button')), findsOneWidget);
    });

    testWidgets('countdown timer decrements per second', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialDuration: const Duration(minutes: 45),
      ));
      await tester.pump();

      expect(find.textContaining('Time Remaining: 45:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Time Remaining: 44:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.textContaining('Time Remaining: 44:00'), findsOneWidget);
    });

    testWidgets('timer expiration locks out attempt with accessible banner',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(
        initialDuration: const Duration(seconds: 2),
      ));
      await tester.pump();

      expect(find.textContaining('Time Remaining: 00:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Time Remaining: 00:00'), findsOneWidget);
      expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
      expect(
        find.textContaining('This attempt has expired'),
        findsOneWidget,
      );
    });

    testWidgets('rejects non-xlsx file selection with accessible validation error',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Trigger synthetic invalid file by finding State and calling handler directly
      final state = tester.state<ExcelUploadCardState>(find.byType(ExcelUploadCard));
      state.handleFileSelected('transactions.csv', Uint8List.fromList([1, 2, 3]));
      await tester.pump();

      expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
      expect(
        find.textContaining('Invalid file type: Only Excel (.xlsx) workbooks are accepted.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects oversized file selection (>10 MiB)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final state = tester.state<ExcelUploadCardState>(find.byType(ExcelUploadCard));
      final oversizedBytes = Uint8List(10 * 1024 * 1024 + 1);
      state.handleFileSelected('huge.xlsx', oversizedBytes);
      await tester.pump();

      expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
      expect(
        find.textContaining('File exceeds maximum limit: Workbooks must be 10 MiB or smaller.'),
        findsOneWidget,
      );
    });

    testWidgets('synthetic valid workbook submission evaluates to pass with all 4 criteria',
        (tester) async {
      bool completed = false;
      await tester.pumpWidget(buildTestWidget(
        onComplete: () => completed = true,
      ));
      await tester.pump();

      // Tap the Load Synthetic Valid Workbook button
      await tester.tap(find.byKey(const Key('excel-load-synthetic-button')));
      await tester.pump();

      expect(find.byKey(const Key('excel-submit-button')), findsOneWidget);
      expect(find.textContaining('practice_budget.xlsx'), findsOneWidget);

      // Tap submit
      await tester.tap(find.byKey(const Key('excel-submit-button')));
      await tester.pump(); // Start uploading
      await tester.pump(const Duration(milliseconds: 350)); // Finish evaluation
      await tester.pump();

      expect(find.byKey(const Key('excel-results-container')), findsOneWidget);
      expect(find.text('PRACTICE EXERCISE PASSED'), findsOneWidget);
      expect(find.text('Worksheet Name'), findsOneWidget);
      expect(find.text('Transaction Inputs'), findsOneWidget);
      expect(find.text('SUM Formula Construction'), findsOneWidget);
      expect(find.text('Calculated Budget Total'), findsOneWidget);
      expect(find.text('TRUST: UNVERIFIED_CHECKER_ONLY'), findsOneWidget);
      expect(find.text('SKILL AWARD: NONE'), findsOneWidget);
      expect(completed, isTrue);
    });

    testWidgets('missing formula workbook evaluates to needs revision',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Tap the Missing Formula button
      await tester.tap(find.byKey(const Key('excel-load-invalid-button')));
      await tester.pump();

      // Submit
      await tester.tap(find.byKey(const Key('excel-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byKey(const Key('excel-results-container')), findsOneWidget);
      expect(find.text('NEEDS REVISION'), findsOneWidget);
      expect(find.text('FAIL'), findsWidgets);
    });

    testWidgets('clicking New Attempt resets attempt state and generates new attempt ID',
        (tester) async {
      await tester.pumpWidget(buildTestWidget(attemptId: 'ba430000-0000-4000-8000-000000000001'));
      await tester.pump();

      // Submit synthetic file
      await tester.tap(find.byKey(const Key('excel-load-synthetic-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('excel-submit-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byKey(const Key('excel-new-attempt-button')), findsOneWidget);

      // Scroll to New Attempt button and tap
      await tester.ensureVisible(find.byKey(const Key('excel-new-attempt-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('excel-new-attempt-button')));
      await tester.pumpAndSettle();

      // Results container is gone and upload area is back
      expect(find.byKey(const Key('excel-results-container')), findsNothing);
      expect(find.byKey(const Key('excel-browse-button')), findsOneWidget);
      // Attempt ID has changed from original
      expect(find.textContaining('Attempt: ba430000...'), findsNothing);
    });
  });
}
