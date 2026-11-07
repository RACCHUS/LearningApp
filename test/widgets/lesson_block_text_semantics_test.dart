import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/callout_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/code_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/example_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';

// Selectable lesson text must remain readable text in the accessibility tree.
// SelectableText-based rendering exposes it as empty disabled text fields on
// Flutter web, which screen readers cannot read.
void main() {
  final now = DateTime(2026, 11, 7);

  LessonBlock block(LessonBlockType type, Map<String, dynamic> content) =>
      LessonBlock(
        id: 'block-${type.name}',
        lessonId: 'lesson-1',
        sortOrder: 1,
        blockType: type,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

  Future<void> expectReadableText(
    WidgetTester tester,
    Widget child,
    List<String> texts,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(SelectionArea), findsWidgets);
    for (final text in texts) {
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(text))),
        findsWidgets,
        reason: '"$text" should be in the semantics tree',
      );
    }

    var textFields = 0;
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().flagsCollection.isTextField) textFields++;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(
      textFields,
      0,
      reason: 'lesson text must not be exposed as a text field',
    );
    handle.dispose();
  }

  testWidgets('markdown block exposes its body as readable text', (
    tester,
  ) async {
    await expectReadableText(
      tester,
      MarkdownBlockWidget(
        block: block(LessonBlockType.markdown, {
          'body': 'A home network is a chain of links.',
        }),
      ),
      ['A home network is a chain of links.'],
    );
  });

  testWidgets('callout block exposes its body as readable text', (
    tester,
  ) async {
    await expectReadableText(
      tester,
      CalloutBlockWidget(
        block: block(LessonBlockType.callout, {
          'callout_type': 'note',
          'title': 'Rule of thumb',
          'body': 'Fix the physical link before changing settings.',
        }),
      ),
      ['Fix the physical link before changing settings.'],
    );
  });

  testWidgets('example block exposes its scenario as readable text', (
    tester,
  ) async {
    await expectReadableText(
      tester,
      ExampleBlockWidget(
        block: block(LessonBlockType.example, {
          'scenario': 'The printer works but the laptop cannot connect.',
        }),
      ),
      ['The printer works but the laptop cannot connect.'],
    );
  });

  testWidgets('code block exposes code and output as readable text', (
    tester,
  ) async {
    await expectReadableText(
      tester,
      CodeBlockWidget(
        block: block(LessonBlockType.code, {
          'language': 'bash',
          'code': 'ping 192.168.1.1',
          'output': 'Request timed out.',
        }),
      ),
      ['ping 192.168.1.1', 'Request timed out.'],
    );
  });
}
