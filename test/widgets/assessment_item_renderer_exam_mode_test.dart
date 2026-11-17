import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/widgets/assessment/assessment_item_renderer.dart';

/// Characterization tests for exam mode (mock exams): every interaction
/// reports its current response through onResponseChanged, in the shape
/// the exam screen stores. Written before the code-efficiency plan §14
/// Phase 3 split of the answer views, so the split cannot change it.
void main() {
  final now = DateTime(2026, 11, 17);

  AssessmentItem item(AssessmentInteractionType type, Map<String, dynamic> responseSpec,
          Map<String, dynamic> scoringSpec) =>
      AssessmentItem(
        id: 'exam-${type.name}',
        interactionType: type,
        prompt: 'Prompt for ${type.name}',
        responseSpec: responseSpec,
        scoringSpec: scoringSpec,
        createdAt: now,
        updatedAt: now,
      );

  Future<List<dynamic>> pump(WidgetTester tester, AssessmentItem item) async {
    final responses = <dynamic>[];
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssessmentItemRenderer(
            item: item,
            isExamMode: true,
            shuffleOptions: false,
            onResponseChanged: responses.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return responses;
  }

  testWidgets('single choice reports the original option index', (tester) async {
    final responses = await pump(
        tester,
        item(AssessmentInteractionType.singleChoice,
            {'options': ['DES', 'Blowfish', 'AES', 'RC4']}, {'correct_index': 2}));
    await tester.tap(find.text('AES'));
    await tester.pump();
    await tester.tap(find.text('DES'));
    await tester.pump();
    expect(responses, [2, 0]);
  });

  testWidgets('multi-select reports the selected indices after each toggle',
      (tester) async {
    final responses = await pump(
        tester,
        item(AssessmentInteractionType.multiSelect,
            {'options': ['AES', 'RSA', '3DES', 'ECC']}, {'correct_indices': [0, 2]}));
    await tester.tap(find.text('AES'));
    await tester.pump();
    await tester.tap(find.text('3DES'));
    await tester.pump();
    await tester.tap(find.text('AES'));
    await tester.pump();
    expect(responses, [
      [0],
      [0, 2],
      [2],
    ]);
  });

  testWidgets('matching reports the full pair map after each match', (tester) async {
    final responses = await pump(
        tester,
        item(AssessmentInteractionType.matching,
            {'left_items': ['HTTPS', 'SSH'], 'right_items': ['443', '22']},
            {'correct_pairs': {'HTTPS': '443', 'SSH': '22'}}));
    await tester.tap(find.text('HTTPS'));
    await tester.pump();
    await tester.tap(find.text('443'));
    await tester.pump();
    await tester.tap(find.text('SSH'));
    await tester.pump();
    await tester.tap(find.text('22'));
    await tester.pump();
    expect(responses, [
      {'HTTPS': '443'},
      {'HTTPS': '443', 'SSH': '22'},
    ]);
  });

  testWidgets('ordered response reports the full order after a drag', (tester) async {
    final responses = await pump(
        tester,
        item(AssessmentInteractionType.orderedResponse,
            {'items': ['First', 'Second', 'Third']}, {'correct_order': [0, 1, 2]}));
    final start = tester.getCenter(find.text('First'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(responses, isNotEmpty, reason: 'a reorder reports a response');
    final last = responses.last as List;
    expect(last.toSet(), {'First', 'Second', 'Third'});
    expect(last.first, isNot('First'), reason: 'First was dragged down');
  });
}
