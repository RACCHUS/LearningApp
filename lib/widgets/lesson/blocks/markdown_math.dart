import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// `$…$` (inline) and `$$…$$` (display) LaTeX inside lesson markdown.
///
/// Curriculum lessons and imported open textbook sections write math this
/// way. Pandoc's rule keeps money as text: no space just inside either `$`,
/// and a closing `$` cannot be followed by a digit, so "$5 and $10" stays
/// text while "$12$" and "$2x+3$" are math.
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax()
    : super(r'\$\$(?!\s)([^$]+?)(?<!\s)\$\$|\$(?!\s)([^$\n]+?)(?<!\s)\$(?!\d)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final display = match[1] != null;
    final element = md.Element.text('math', (match[1] ?? match[2])!.trim());
    element.attributes['display'] = display ? 'true' : 'false';
    parser.addNode(element);
    return true;
  }
}

/// Renders a `math` element with flutter_math. Invalid LaTeX falls back to
/// the source text instead of an error box.
class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent;
    final display = element.attributes['display'] == 'true';
    final math = Math.tex(
      tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: parentStyle,
      onErrorFallback: (_) => Text(tex, style: parentStyle),
    );
    return display
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: math)
        : math;
  }
}

/// Shared settings for lesson markdown that may contain math.
final lessonMarkdownInlineSyntaxes = <md.InlineSyntax>[InlineMathSyntax()];
final lessonMarkdownBuilders = <String, MarkdownElementBuilder>{
  'math': MathElementBuilder(),
};

/// Plain [Text] unless [text] contains `$` math, in which case it renders
/// as markdown with math. Keeps existing plain prompts unchanged.
Widget mathAwareText(String text, TextStyle? style) {
  if (!text.contains(r'$')) return Text(text, style: style);
  return MarkdownBody(
    data: text,
    inlineSyntaxes: lessonMarkdownInlineSyntaxes,
    builders: lessonMarkdownBuilders,
    styleSheet: MarkdownStyleSheet(p: style),
  );
}
