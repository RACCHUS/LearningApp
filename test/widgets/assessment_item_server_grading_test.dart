import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/services/assessment/assessment_grading_service.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';

void main() {
  final now = DateTime.utc(2026, 11, 8);
  final hiddenKeyItem = AssessmentItem(
    id: 'hidden-1',
    interactionType: AssessmentInteractionType.singleChoice,
    prompt: 'Which device forwards packets between networks?',
    responseSpec: const {
      'options': ['Switch', 'Router', 'Hub'],
    },
    createdAt: now,
    updatedAt: now,
  );

  Widget host(AssessmentGradingService service, {void Function(bool)? onDone}) {
    return MaterialApp(
      home: Scaffold(
        body: AssessmentItemRenderer(
          item: hiddenKeyItem,
          shuffleOptions: false,
          gradingService: service,
          onAnswerSubmitted: (correct, _) => onDone?.call(correct),
        ),
      ),
    );
  }

  testWidgets('grades hidden-key items on the server and reveals the rationale',
      (tester) async {
    List<Map<String, dynamic>>? sent;
    bool? result;
    final service = AssessmentGradingService(transport: (payload) async {
      sent = payload;
      return [
        {
          'item_id': 'hidden-1',
          'is_correct': true,
          'is_partial': false,
          'score': 1,
          'scoring_spec': {'correct_index': 1},
          'explanation': 'Routers connect separate networks.',
        },
      ];
    });

    await tester.pumpWidget(host(service, onDone: (c) => result = c));
    await tester.tap(find.text('Router'));
    await tester.pump();
    await tester.tap(find.text('Check Answer'));
    await tester.pumpAndSettle();

    expect(sent, [
      {'item_id': 'hidden-1', 'response': 1},
    ]);
    expect(result, isTrue);
    expect(find.text('Practice evidence: Correct retrieval'), findsOneWidget);
    expect(find.text('Routers connect separate networks.'), findsOneWidget);
  });

  testWidgets('shows a retryable error while the server cannot grade',
      (tester) async {
    final pending = Completer<dynamic>();
    var attempts = 0;
    final service = AssessmentGradingService(transport: (_) {
      attempts++;
      return attempts == 1 ? pending.future : Future.value(<dynamic>[]);
    });

    await tester.pumpWidget(host(service));
    await tester.tap(find.text('Switch'));
    await tester.pump();
    await tester.tap(find.text('Check Answer'));
    await tester.pump();

    expect(find.text('Checking…'), findsOneWidget);
    final checking = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Checking…'),
    );
    expect(checking.onPressed, isNull);

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Answers could not be checked'),
      findsOneWidget,
    );
    final retry = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Check Answer'),
    );
    expect(retry.onPressed, isNotNull);
    expect(find.text('Practice evidence: Correct retrieval'), findsNothing);
  });
}
