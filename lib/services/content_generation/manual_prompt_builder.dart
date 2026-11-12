import 'dart:convert';

import 'package:learning_pwa/models/content_generation/slot_plan.dart';
import 'package:learning_pwa/services/content_generation/la_gen_parser.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';

/// Output shape requested from the learner's AI chat.
enum ManualOutputMode {
  /// One `la-gen/1.1` JSON object (the default, master plan v2.6 C04).
  package,

  /// Mode S: one JSON object per line (optional, for small models).
  lines,
}

/// Bundled, versioned prompt pack for the slot-based manual generator
/// (master plan v2.6 §5.7). Prompts are plain data built from the plan:
/// they contain only the learner's subject and idea names, never private
/// progress, account data or keys.
class ManualPromptBuilder {
  const ManualPromptBuilder._();

  static const packId = 'micro_lesson_v1';

  /// Field length limit stated to the model (the parser allows more).
  static const statedMaxChars = 600;

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[\u0000-\u001F\u007F]+'), ' ').trim();

  /// The prompt for [slotCodes] (a batch of still-missing slots).
  static String build(
    ManualJob job,
    List<String> slotCodes, {
    ManualOutputMode mode = ManualOutputMode.package,
  }) {
    final plan = job.plan;
    final specs = [for (final c in slotCodes) plan[c]!];
    final usedConcepts = {for (final s in specs) s.conceptCode};
    final b = StringBuffer()
      ..writeln(
        'You are helping me make a short private study lesson about '
        '${jsonEncode(_clean(job.request.subject))}.',
      )
      ..writeln()
      ..writeln('IDEAS (use these codes exactly):');
    for (final code in usedConcepts) {
      b.writeln('- $code: ${jsonEncode(_clean(job.conceptNames[code]!))}');
    }
    b
      ..writeln()
      ..writeln('FILL EXACTLY THESE ${specs.length} SLOTS, no more, no fewer:');
    for (final s in specs) {
      b.writeln('- ${s.code} (${s.conceptCode}): ${_describe(s.kind)}');
    }
    b
      ..writeln()
      ..writeln('FIELDS FOR EACH KIND:')
      ..writeln(
        '- explanation: "slot", "kind":"explanation", "concept", '
        '"title", "text", optional "example"',
      )
      ..writeln(
        '- term: "slot", "kind":"term", "concept", "term", "definition", '
        'optional "example"',
      )
      ..writeln(
        '- mcq: "slot", "kind":"mcq", "concept", "stem", "options" '
        '(3 to 5 different texts), "answer" (ONE capital letter: A for the '
        'first option, B for the second, ...), optional "why"',
      )
      ..writeln()
      ..writeln('RULES:')
      ..writeln('- Plain text only. No HTML, no Markdown, no links.')
      ..writeln('- Each text field at most $statedMaxChars characters.')
      ..writeln('- Use no other fields. Do not add a "support" field.')
      ..writeln('- Exactly one option is correct, and "answer" names it.')
      ..writeln('- If you are unsure of a fact, leave that slot out.')
      ..writeln();

    final example = specs.firstWhere(
      (s) => s.kind == SlotKind.mcq,
      orElse: () => specs.first,
    );
    final sample = _sample(example);
    if (mode == ManualOutputMode.package) {
      b
        ..writeln('REPLY WITH ONLY THIS JSON (no other text):')
        ..writeln('{')
        ..writeln('  "schema": "${LaGenParser.schemaId}",')
        ..writeln('  "job": "${plan.jobCode}",')
        ..writeln('  "pack": "$packId",')
        ..writeln('  "items": [')
        ..writeln('    ${jsonEncode(sample)}')
        ..writeln('  ],')
        ..writeln('  "end": "${plan.endSentinel}"')
        ..writeln('}')
        ..writeln()
        ..writeln(
          'Put one item per slot in "items". '
          'Finish with "end": "${plan.endSentinel}".',
        );
    } else {
      b
        ..writeln('REPLY WITH ONE JSON OBJECT PER LINE (no other text):')
        ..writeln(jsonEncode(sample))
        ..writeln('{"end":"${plan.endSentinel}"}')
        ..writeln()
        ..writeln(
          'One line per slot, then the end line {"end":"${plan.endSentinel}"}.',
        );
    }
    return b.toString().trimRight();
  }

  static String _describe(SlotKind kind) => switch (kind) {
    SlotKind.explanation => 'explanation of the idea for a beginner',
    SlotKind.term => 'one key term and its definition',
    SlotKind.mcq => 'one multiple-choice question',
  };

  /// A shape example. Its placeholder text is obviously not an answer.
  static Map<String, Object> _sample(SlotSpec s) => switch (s.kind) {
    SlotKind.explanation => {
      'slot': s.code,
      'kind': 'explanation',
      'concept': s.conceptCode,
      'title': '...',
      'text': '...',
      'example': '...',
    },
    SlotKind.term => {
      'slot': s.code,
      'kind': 'term',
      'concept': s.conceptCode,
      'term': '...',
      'definition': '...',
    },
    SlotKind.mcq => {
      'slot': s.code,
      'kind': 'mcq',
      'concept': s.conceptCode,
      'stem': '...',
      'options': ['...', '...', '...', '...'],
      'answer': 'B',
      'why': '...',
    },
  };
}
