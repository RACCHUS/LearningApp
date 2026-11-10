import 'dart:async';
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
    VoidCallback? onFileSelect,
    Future<SoftwareLearningResult> Function(String, Uint8List, String)?
    onUpload,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExcelUploadCard(
            attemptId: attemptId,
            initialDuration: initialDuration,
            onComplete: onComplete,
            onFileSelect: onFileSelect,
            onUpload: onUpload,
          ),
        ),
      ),
    );
  }

  group('ExcelUploadCard UI & Accessibility Tests', () {
    testWidgets(
      'renders unverified demo badge, timer, and privacy notice in demo mode',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(attemptId: 'ba430000-0000-4000-8000-000000000001'),
        );
        await tester.pump();

        expect(find.text('Excel Workbook Practice'), findsOneWidget);
        expect(find.text('UNVERIFIED PRACTICE (DEMO)'), findsOneWidget);
        expect(find.textContaining('Time Remaining: 45:00'), findsOneWidget);
        expect(find.textContaining('Attempt: ba430000...'), findsOneWidget);
        expect(
          find.textContaining(
            'Privacy & Verification Gate: Live file upload is disabled in this preview.',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('excel-browse-button')), findsOneWidget);
        expect(
          find.byKey(const Key('excel-load-synthetic-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('excel-load-invalid-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('excel-load-corrupt-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'callback notice discloses proposed retention without an active purge claim',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onUpload: (name, bytes, attemptId) async => SoftwareLearningResult(
              attemptId: attemptId,
              exerciseId: 'excel-budget-total-v1',
              overallPassed: true,
              feedback: 'ok',
              criteria: const [],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('UNVERIFIED PRACTICE'), findsOneWidget);
        expect(
          find.textContaining(
            'a proposed target, not an active or verified purge service',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('automated 24-hour retention purge policy'),
          findsNothing,
        );
        // In live mode, demo sample buttons are NOT rendered
        expect(
          find.byKey(const Key('excel-load-synthetic-button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('excel-load-invalid-button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('excel-load-corrupt-button')),
          findsNothing,
        );
      },
    );

    testWidgets('countdown timer decrements per second', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(initialDuration: const Duration(minutes: 45)),
      );
      await tester.pump();

      expect(find.textContaining('Time Remaining: 45:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Time Remaining: 44:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      expect(find.textContaining('Time Remaining: 44:00'), findsOneWidget);
    });

    testWidgets('timer expiration locks out attempt with accessible banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(initialDuration: const Duration(seconds: 2)),
      );
      await tester.pump();

      expect(find.textContaining('Time Remaining: 00:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Time Remaining: 00:00'), findsOneWidget);
      expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
      expect(find.textContaining('This attempt has expired'), findsOneWidget);
    });

    testWidgets(
      'rejects non-xlsx file selection with accessible validation error',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        final state = tester.state<ExcelUploadCardState>(
          find.byType(ExcelUploadCard),
        );
        state.handleFileSelected(
          'transactions.csv',
          Uint8List.fromList([1, 2, 3]),
        );
        await tester.pump();

        expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
        expect(
          find.textContaining(
            'Invalid file type: Only Excel (.xlsx) workbooks are accepted.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('rejects oversized file selection (>10 MiB)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final state = tester.state<ExcelUploadCardState>(
        find.byType(ExcelUploadCard),
      );
      final oversizedBytes = Uint8List(10 * 1024 * 1024 + 1);
      state.handleFileSelected('huge.xlsx', oversizedBytes);
      await tester.pump();

      expect(find.byKey(const Key('excel-error-banner')), findsOneWidget);
      expect(
        find.textContaining(
          'File exceeds maximum limit: Workbooks must be 10 MiB or smaller.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'genuine valid OOXML workbook submission evaluates to pass with all 4 criteria',
      (tester) async {
        bool completed = false;
        await tester.pumpWidget(
          buildTestWidget(onComplete: () => completed = true),
        );
        await tester.pump();

        // Tap the Load Valid Budget Sample button
        await tester.ensureVisible(
          find.byKey(const Key('excel-load-synthetic-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-load-synthetic-button')));
        await tester.pump();

        expect(find.byKey(const Key('excel-submit-button')), findsOneWidget);
        expect(find.textContaining('practice_budget.xlsx'), findsOneWidget);

        // Tap submit
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump(); // Start uploading
        await tester.pump(
          const Duration(milliseconds: 350),
        ); // Finish evaluation
        await tester.pump();

        expect(
          find.byKey(const Key('excel-results-container')),
          findsOneWidget,
        );
        expect(
          find.textContaining('PRACTICE EXERCISE PASSED (DEMO)'),
          findsOneWidget,
        );
        expect(find.text('Worksheet Name'), findsOneWidget);
        expect(find.text('Transaction Inputs'), findsOneWidget);
        expect(find.text('SUM Formula Construction'), findsOneWidget);
        expect(find.text('Calculated Budget Total'), findsOneWidget);
        expect(find.text('TRUST: UNVERIFIED_CHECKER_ONLY'), findsOneWidget);
        expect(find.text('SKILL AWARD: NONE'), findsOneWidget);
        expect(find.text('MODE: RUBRIC DEMO'), findsOneWidget);
        // Demo evaluation must not trigger simulation completion!
        expect(completed, isFalse);
      },
    );

    testWidgets(
      'missing formula genuine OOXML evaluates to needs revision (formula fail, sheet pass)',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Tap the Missing Formula button
        await tester.ensureVisible(
          find.byKey(const Key('excel-load-invalid-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-load-invalid-button')));
        await tester.pump();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(
          find.byKey(const Key('excel-results-container')),
          findsOneWidget,
        );
        expect(find.text('NEEDS REVISION'), findsOneWidget);
        // Both PASS (for sheet & inputs) and FAIL (for formula & total) are present
        expect(find.text('PASS'), findsWidgets);
        expect(find.text('FAIL'), findsWidgets);
        expect(
          find.textContaining('Cell C10 does not contain a formula'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'corrupted archive sample evaluates to fail on all criteria with readable error',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();

        // Tap the Load Corrupt Archive button
        await tester.ensureVisible(
          find.byKey(const Key('excel-load-corrupt-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-load-corrupt-button')));
        await tester.pump();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(
          find.byKey(const Key('excel-results-container')),
          findsOneWidget,
        );
        expect(find.text('NEEDS REVISION'), findsOneWidget);
        expect(
          find.textContaining('Corrupt or unreadable Excel archive'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'upload callback pass remains unverified and cannot trigger completion',
      (tester) async {
        bool completed = false;
        await tester.pumpWidget(
          buildTestWidget(
            onComplete: () => completed = true,
            onUpload: (name, bytes, attemptId) async => SoftwareLearningResult(
              attemptId: attemptId,
              exerciseId: 'excel-budget-total-v1',
              overallPassed: true,
              evidenceTrust: 'unverified_checker_only',
              canAwardSkill: false,
              feedback: 'Verified pass from server.',
              criteria: const [
                SoftwareLearningCriterion(
                  id: 'c1',
                  title: 'Worksheet Name',
                  description: 'Budget',
                  passed: true,
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        // Supply valid OOXML bytes directly to state handler
        final state = tester.state<ExcelUploadCardState>(
          find.byType(ExcelUploadCard),
        );
        final validBytes =
            SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes();
        state.handleFileSelected('custom_budget.xlsx', validBytes);
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(
          find.byKey(const Key('excel-results-container')),
          findsOneWidget,
        );
        expect(completed, isFalse);
        expect(
          find.textContaining('scheduled deletion is not deployed or verified'),
          findsOneWidget,
        );
      },
    );

    for (final invalid in ['attempt', 'exercise', 'trust', 'award']) {
      testWidgets('rejects callback with invalid $invalid binding', (
        tester,
      ) async {
        bool completed = false;
        await tester.pumpWidget(
          buildTestWidget(
            onComplete: () => completed = true,
            onUpload: (name, bytes, attemptId) async => SoftwareLearningResult(
              attemptId: invalid == 'attempt' ? 'foreign-attempt' : attemptId,
              exerciseId: invalid == 'exercise'
                  ? 'other'
                  : 'excel-budget-total-v1',
              overallPassed: true,
              evidenceTrust: invalid == 'trust'
                  ? 'server_verified'
                  : 'unverified_checker_only',
              canAwardSkill: invalid == 'award',
              feedback: 'Must not be accepted',
              criteria: const [],
            ),
          ),
        );
        final state = tester.state<ExcelUploadCardState>(
          find.byType(ExcelUploadCard),
        );
        state.loadSyntheticPracticeFile();
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        expect(find.textContaining('Assessment failed:'), findsOneWidget);
        expect(find.byKey(const Key('excel-results-container')), findsNothing);
        expect(completed, isFalse);
      });
    }

    testWidgets(
      'race condition guard: in-flight evaluation discarded if timer expires during evaluation',
      (tester) async {
        final completer = Completer<SoftwareLearningResult>();
        bool completed = false;

        await tester.pumpWidget(
          buildTestWidget(
            initialDuration: const Duration(seconds: 2),
            onComplete: () => completed = true,
            onUpload: (name, bytes, attemptId) => completer.future,
          ),
        );
        await tester.pump();

        final state = tester.state<ExcelUploadCardState>(
          find.byType(ExcelUploadCard),
        );
        final validBytes =
            SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes();
        state.handleFileSelected('budget.xlsx', validBytes);
        await tester.pump();

        // Submit while 2 seconds remain
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump(
          const Duration(milliseconds: 350),
        ); // uploading -> evaluating

        // Timer expires while evaluation is in-flight!
        await tester.pump(const Duration(seconds: 3));
        expect(find.textContaining('This attempt has expired'), findsOneWidget);

        // Now complete the deferred in-flight evaluation
        completer.complete(
          const SoftwareLearningResult(
            attemptId: 'any',
            exerciseId: 'excel-budget-total-v1',
            overallPassed: true,
            feedback: 'Late pass that should be ignored',
            criteria: [],
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Result MUST BE DISCARDED, status remains expired, onComplete NOT called!
        expect(find.textContaining('This attempt has expired'), findsOneWidget);
        expect(find.byKey(const Key('excel-results-container')), findsNothing);
        expect(completed, isFalse);
      },
    );

    testWidgets(
      'race condition guard: in-flight evaluation discarded if attempt is reset during evaluation',
      (tester) async {
        final completer = Completer<SoftwareLearningResult>();
        bool completed = false;

        await tester.pumpWidget(
          buildTestWidget(
            onComplete: () => completed = true,
            onUpload: (name, bytes, attemptId) => completer.future,
          ),
        );
        await tester.pump();

        final state = tester.state<ExcelUploadCardState>(
          find.byType(ExcelUploadCard),
        );
        final validBytes =
            SoftwareLearningWorkbookEvaluator.createSampleWorkbookBytes();
        state.handleFileSelected('budget.xlsx', validBytes);
        await tester.pump();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump(const Duration(milliseconds: 350)); // evaluating

        // Learner resets attempt while evaluation is in-flight
        state.resetAttempt();
        await tester.pump();

        // Complete in-flight evaluation
        completer.complete(
          const SoftwareLearningResult(
            attemptId: 'old-attempt',
            exerciseId: 'excel-budget-total-v1',
            overallPassed: true,
            feedback: 'Late pass from old attempt',
            criteria: [],
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Result MUST BE DISCARDED, status is idle, onComplete NOT called!
        expect(find.byKey(const Key('excel-results-container')), findsNothing);
        expect(completed, isFalse);
      },
    );

    testWidgets(
      'clicking New Attempt resets attempt state and generates new attempt ID',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(attemptId: 'ba430000-0000-4000-8000-000000000001'),
        );
        await tester.pump();

        // Submit synthetic file
        await tester.ensureVisible(
          find.byKey(const Key('excel-load-synthetic-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-load-synthetic-button')));
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('excel-submit-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-submit-button')));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();

        expect(
          find.byKey(const Key('excel-new-attempt-button')),
          findsOneWidget,
        );

        // Scroll to New Attempt button and tap
        await tester.ensureVisible(
          find.byKey(const Key('excel-new-attempt-button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('excel-new-attempt-button')));
        await tester.pumpAndSettle();

        // Results container is gone and upload area is back
        expect(find.byKey(const Key('excel-results-container')), findsNothing);
        expect(find.byKey(const Key('excel-browse-button')), findsOneWidget);
        // Attempt ID has changed from original
        expect(find.textContaining('Attempt: ba430000...'), findsNothing);
      },
    );
  });
}
