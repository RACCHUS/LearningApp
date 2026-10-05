import 'package:flutter/material.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/widgets/lesson/blocks/markdown_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/callout_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/code_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/table_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/formula_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/example_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/practice_prompt_block_widget.dart';
import 'package:learning_pwa/widgets/lesson/blocks/image_block_widget.dart';

/// Polymorphic Lesson Block Dispatcher
/// 
/// Inspects the `LessonBlockType` and delegates to the appropriate specialized block renderer.
class LessonBlockRenderer extends StatelessWidget {
  final LessonBlock block;
  final double fontSizeFactor;

  const LessonBlockRenderer({
    super.key,
    required this.block,
    this.fontSizeFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    switch (block.blockType) {
      case LessonBlockType.markdown:
        return MarkdownBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.callout:
        return CalloutBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.code:
        return CodeBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.table:
        return TableBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.formula:
        return FormulaBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.example:
        return ExampleBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.practicePrompt:
        return PracticePromptBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
      case LessonBlockType.image:
        return ImageBlockWidget(block: block, fontSizeFactor: fontSizeFactor);
    }
  }
}
