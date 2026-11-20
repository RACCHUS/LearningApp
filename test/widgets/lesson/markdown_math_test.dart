import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';

Future<void> pumpMarkdown(WidgetTester tester, String text) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: MarkdownBlockWidget(
        block: LessonBlock.fromJson({
          'id': 'b1',
          'lesson_id': 'l1',
          'block_type': 'markdown',
          'sort_order': 1,
          'content': {'text': text},
        }),
      ),
    ),
  ),
);

void main() {
  testWidgets('inline and display LaTeX render as math', (tester) async {
    await pumpMarkdown(
      tester,
      r'For any $a \neq 0$, $a^0 = 1$.' '\n\n' r'$$x = \frac{-b}{2a}$$',
    );
    expect(find.byType(Math), findsNWidgets(3));
    expect(find.textContaining(r'$a^0'), findsNothing);
  });

  testWidgets('math may start with a digit', (tester) async {
    await pumpMarkdown(tester, r'So $12$ and $2x+3$ are math.');
    expect(find.byType(Math), findsNWidgets(2));
  });

  testWidgets('money amounts are not mistaken for math', (tester) async {
    await pumpMarkdown(tester, r'It costs $5 and $10 plus tax.');
    expect(find.byType(Math), findsNothing);
    expect(find.textContaining(r'$5 and $10'), findsOneWidget);
  });

  testWidgets('broken LaTeX shows its source instead of an error', (tester) async {
    await pumpMarkdown(tester, r'Bad: $\frac{1$ here.');
    expect(tester.takeException(), isNull);
  });
}
