import '../models/generation_session.dart';

/// Compresses prior generation context to fit within token budgets for
/// free-tier AI models (ChatGPT, Claude, Gemini free).
///
/// Strategy: later phases get more compressed summaries of earlier content
/// to avoid exceeding context windows while preserving terminology accuracy.
class PromptContextCompressor {
  PromptContextCompressor._();

  /// Rough token estimate: ~4 English characters per token.
  static int estimateTokens(String text) => (text.length / 4).ceil();

  /// Build a compressed context string for the given phase.
  ///
  /// [maxTokens] defaults to 2000 — safe for free-tier models.
  static String buildContext({
    required GenerationSession session,
    required GenerationPhase forPhase,
    int maxTokens = 2000,
  }) {
    switch (forPhase) {
      case GenerationPhase.planning:
        // No prior context needed
        return '';

      case GenerationPhase.generatingTerms:
        // Plan is small (~1K tokens), inject full
        return _fullPlanContext(session);

      case GenerationPhase.generatingConcepts:
        // Plan + compressed terms table
        final plan = _compressPlan(session, keepManifestSections: ['concepts', 'mcqs']);
        final terms = compressTerms(session.terms);
        return _fitTobudget('$plan\n\n$terms', maxTokens);

      case GenerationPhase.generatingMcqs:
        // Compressed plan (mcqs manifest only) + terms table + concepts table
        final plan = _compressPlan(session, keepManifestSections: ['mcqs']);
        final terms = compressTerms(session.terms);
        final concepts = compressConcepts(session.concepts);
        return _fitTobudget('$plan\n\n$terms\n\n$concepts', maxTokens);

      case GenerationPhase.reviewing:
        // Review needs full content — no compression
        return '';

      case GenerationPhase.complete:
        return '';
    }
  }

  /// Compress terms to a compact reference table.
  static String compressTerms(List<Map<String, dynamic>> terms) {
    if (terms.isEmpty) return '';

    final buffer = StringBuffer('PREVIOUSLY GENERATED TERMS (use these exact names):\n');
    buffer.writeln('| # | Term | Core Definition |');
    buffer.writeln('|---|------|----------------|');

    for (var i = 0; i < terms.length; i++) {
      final t = terms[i];
      final name = t['title'] ?? t['term'] ?? '';
      final def = _truncate(t['content'] ?? t['definition'] ?? '', 80);
      buffer.writeln('| ${i + 1} | $name | $def |');
    }

    return buffer.toString();
  }

  /// Compress concepts to a compact summary table.
  static String compressConcepts(List<Map<String, dynamic>> concepts) {
    if (concepts.isEmpty) return '';

    final buffer = StringBuffer('PREVIOUSLY GENERATED CONCEPTS:\n');
    buffer.writeln('| # | Concept | Key Points |');
    buffer.writeln('|---|---------|-----------|');

    for (var i = 0; i < concepts.length; i++) {
      final c = concepts[i];
      final title = c['title'] ?? c['concept_text'] ?? '';
      final keyPoints = c['key_points'];
      String summary;
      if (keyPoints is List && keyPoints.isNotEmpty) {
        summary = keyPoints.take(4).join(', ');
      } else {
        summary = _truncate(c['content'] ?? c['example_text'] ?? '', 80);
      }
      buffer.writeln('| ${i + 1} | $title | $summary |');
    }

    return buffer.toString();
  }

  /// Compress the lesson plan, keeping only the glossary and specified
  /// manifest sections (sections for already-completed phases are dropped).
  static String _compressPlan(
    GenerationSession session, {
    required List<String> keepManifestSections,
  }) {
    final plan = session.lessonPlan;
    if (plan == null) return '';

    final lessonPlan = plan['lesson_plan'] as Map<String, dynamic>? ?? {};
    final manifest = plan['content_manifest'] as Map<String, dynamic>? ?? {};
    final glossary = plan['terminology_glossary'] as Map<String, dynamic>? ?? {};

    final buffer = StringBuffer();

    // Title + objectives (compact)
    buffer.writeln('LESSON: ${lessonPlan['title'] ?? session.subject}');
    buffer.writeln('DIFFICULTY: ${lessonPlan['difficulty'] ?? session.difficulty}');

    final objectives = lessonPlan['learning_objectives'];
    if (objectives is List && objectives.isNotEmpty) {
      buffer.writeln('OBJECTIVES: ${objectives.join('; ')}');
    }

    // Glossary — always included, ~20 tokens per term
    if (glossary.isNotEmpty) {
      buffer.writeln('\nTERMINOLOGY GLOSSARY (use these definitions consistently):');
      glossary.forEach((term, def) {
        buffer.writeln('- $term: $def');
      });
    }

    // Only include manifest sections that are still needed
    for (final section in keepManifestSections) {
      final items = manifest[section];
      if (items is List && items.isNotEmpty) {
        buffer.writeln('\nREMAINING MANIFEST ($section):');
        for (final item in items) {
          if (item is Map) {
            final title = item['title'] ?? item['tests_concept'] ?? '';
            final order = item['order'] ?? '';
            buffer.writeln('  $order. $title');
          }
        }
      }
    }

    return buffer.toString();
  }

  /// Full plan context (used for terms phase where plan is small enough).
  static String _fullPlanContext(GenerationSession session) {
    final plan = session.lessonPlan;
    if (plan == null) return '';
    // The plan JSON is typically ~1K tokens — return as-is
    return 'LESSON PLAN:\n${_prettyCompact(plan)}';
  }

  /// Truncate a string to maxLen characters, adding ellipsis.
  static String _truncate(String text, int maxLen) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= maxLen) return clean;
    return '${clean.substring(0, maxLen - 3)}...';
  }

  /// If the text exceeds the token budget, progressively trim it.
  static String _fitTobudget(String text, int maxTokens) {
    if (estimateTokens(text) <= maxTokens) return text;

    // Strategy: split into sections, trim the longest ones
    final lines = text.split('\n');
    while (estimateTokens(lines.join('\n')) > maxTokens && lines.length > 5) {
      // Remove lines from the middle (preserve header + glossary at top)
      final mid = lines.length ~/ 2;
      lines.removeAt(mid);
    }
    return lines.join('\n');
  }

  /// Compact JSON representation without pretty-printing.
  static String _prettyCompact(Map<String, dynamic> json) {
    // Single-level indent for readability, but no deep nesting whitespace
    final buffer = StringBuffer();
    json.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$key:');
        (value).forEach((k, v) {
          if (v is List) {
            buffer.writeln('  $k: [${v.length} items]');
          } else {
            buffer.writeln('  $k: $v');
          }
        });
      } else if (value is List) {
        buffer.writeln('$key: [${value.length} items]');
      } else {
        buffer.writeln('$key: $value');
      }
    });
    return buffer.toString();
  }
}
