import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_math.dart';

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

  testWidgets('inline math flows inside one paragraph of text', (tester) async {
    await pumpMarkdown(
      tester,
      r'There are $100$ cents in a dollar and **$\frac{1}{4}$** of it is a quarter.',
    );
    expect(find.byType(Math), findsNWidgets(2));
    // One merged text run: a bare widget would split the paragraph into
    // separate Wrap children that each start on their own line.
    final wrap = tester.widget<Wrap>(find.byType(Wrap).first);
    expect(wrap.children, hasLength(1));
    expect(find.textContaining('cents in a dollar'), findsOneWidget);
  });

  testWidgets('prompt text with a list renders the list, not dashes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: mathAwareText('Write as a rational number.\n\n- ⓐ 11\n- ⓑ 3', null),
        ),
      ),
    );
    expect(find.textContaining('- ⓐ'), findsNothing);
    expect(find.textContaining('ⓐ 11'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('plain prompt text stays a plain Text widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: mathAwareText('What is 2 - 1?', null))),
    );
    expect(find.text('What is 2 - 1?'), findsOneWidget);
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
