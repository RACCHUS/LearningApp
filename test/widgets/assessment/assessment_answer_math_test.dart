import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/widgets/assessment/assessment_answer_views.dart';

/// Answer options written as $...$ math render as math, not raw LaTeX
/// (notation profile, plan v1.2 §8.9). The published College Algebra items
/// showed "$(x + 2)(x + 7)$" before this.
void main() {
  testWidgets('single-choice options render math', (tester) async {
    final item = AssessmentItem.fromJson({
      'id': 'i1',
      'interaction_type': 'single_choice',
      'prompt': r'Factor $x^2 + 9x + 14$.',
      'response_spec': {
        'options': [r'$(x + 2)(x + 7)$', r'$(x + 2)(x + 9)$', 'Not factorable'],
      },
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SingleChoiceAnswerView(
            item: item,
            revealedItem: item,
            presentationOrder: const [0, 1, 2],
            selected: null,
            submitted: false,
            isDark: false,
            onSelect: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsNWidgets(2));
    expect(find.textContaining(r'$(x + 2)'), findsNothing);
    expect(find.text('Not factorable'), findsOneWidget);
  });
}
