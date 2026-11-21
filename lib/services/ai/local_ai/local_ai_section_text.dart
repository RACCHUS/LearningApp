import 'package:learning_pwa/models/lesson_block.dart';

/// Plain reading text for the on-device summary: the section the learner
/// is reading (or the first one), extended with the following reading
/// blocks up to [maxChars]. Markdown marks and `$…$` math delimiters are
/// stripped, since the model reads plain text. Practice prompts, checks
/// and answers are never included.
String sectionTextForSummary(
  List<LessonBlock> blocks, {
  String? currentBlockId,
  int maxChars = 4000,
}) {
  final reading = [
    for (final b in blocks)
      if (b.blockType == LessonBlockType.markdown ||
          b.blockType == LessonBlockType.callout ||
          b.blockType == LessonBlockType.example)
        b,
  ];
  if (reading.isEmpty) return '';
  var start = reading.indexWhere((b) => b.id == currentBlockId);
  if (start < 0) start = 0;

  final out = StringBuffer();
  for (final b in reading.skip(start)) {
    final text = _plain(b);
    if (text.isEmpty) continue;
    if (out.isNotEmpty && out.length + text.length + 2 > maxChars) break;
    if (out.isNotEmpty) out.write('\n\n');
    out.write(text.length > maxChars ? text.substring(0, maxChars) : text);
  }
  return out.toString();
}

String _plain(LessonBlock b) {
  final c = b.content;
  final raw = [
    c['title'],
    c['text'],
    c['body'],
  ].whereType<String>().join('\n');
  return raw
      .replaceAll(RegExp(r'\$\$?'), '')
      .replaceAll(RegExp(r'[*_`#>]+'), '')
      .replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}
