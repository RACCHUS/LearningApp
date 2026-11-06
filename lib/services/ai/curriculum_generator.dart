import 'dart:convert';
import 'byok_provider.dart';
import 'generated_content_models.dart';
import 'item_evaluator.dart';
import 'llm_client.dart';

/// Service orchestrating curriculum generation using BYOK LLMs with Haladyna grounding (ARCH-4, §5).
class CurriculumGenerator {
  final ByokConfig config;
  final LlmClient _llmClient;
  final ItemEvaluator _evaluator;

  CurriculumGenerator({
    required this.config,
    LlmClient? llmClient,
    ItemEvaluator? evaluator,
  })  : _llmClient = llmClient ?? LlmClient.create(config),
        _evaluator = evaluator ?? ItemEvaluator();

  static const String systemInstruction = '''
You are an expert psychometrician and instructional curriculum designer for LearningApp.
Your task is to generate high-quality assessment items and lessons following the empirical item-writing rules of Haladyna, Downing, & Rodriguez (2002):
1. Focus the stem on a single, clear, central problem.
2. Avoid negative stems ("NOT", "EXCEPT", "LEAST") unless specifically testing exception identification.
3. Provide exactly 4 plausible choices of approximately equal grammatical structure and character length.
4. Ensure distractors reflect genuine misconceptions or plausible alternatives; avoid silly or giveaway options.
5. Never use "all of the above" or "none of the above".
6. Never leak the correct answer or test-taking cues in the prompt stem.
7. Base all facts strictly on the provided authoritative source excerpt. Always provide a specific source citation.
8. Provide elaborative feedback explaining both why the key is correct and why each distractor is incorrect.
''';

  /// Generates a single Haladyna-compliant assessment item grounded in an authoritative excerpt.
  Future<GeneratedAssessmentItem> generateAssessmentItem({
    required String topic,
    required String sourceExcerpt,
    String bloomLevel = 'understand',
    String difficulty = 'intermediate',
  }) async {
    final prompt = '''
Generate one rigorous multiple-choice assessment question for the following topic:
TOPIC: $topic

AUTHORITATIVE SOURCE EXCERPT:
"""
$sourceExcerpt
"""

TARGET SPECIFICATIONS:
- Bloom Taxonomy Level: $bloomLevel
- Target Difficulty: $difficulty
- Exactly 4 plausible options
- 1 single objectively correct key
- Elaborative rationale feedback explaining correct option and all distractors
- Authoritative source citation matching the excerpt
''';

    final jsonStr = await _llmClient.generateStructuredJson(
      prompt: prompt,
      jsonSchema: GeneratedAssessmentItem.jsonSchema,
      systemPrompt: systemInstruction,
    );

    final rawMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final item = GeneratedAssessmentItem.fromJson(rawMap);

    // Evaluate against deterministic quality rubric
    final report = _evaluator.evaluate(item);
    return item.copyWith(
      haladynaViolations: report.violations.map((v) => v.message).toList(),
    );
  }

  /// Generates a full structured lesson containing multiple curated assessment items.
  Future<GeneratedLesson> generateLesson({
    required String topic,
    required String sourceExcerpt,
    int itemCount = 3,
  }) async {
    final prompt = '''
Generate a structured, evidence-based lesson module for the following topic with exactly $itemCount assessment items:
TOPIC: $topic

AUTHORITATIVE SOURCE EXCERPT:
"""
$sourceExcerpt
"""

REQUIREMENTS:
- Title and educational description
- Estimated completion time in minutes
- Key concepts covered
- Exactly $itemCount multiple-choice questions adhering strictly to Haladyna guidelines
''';

    final jsonStr = await _llmClient.generateStructuredJson(
      prompt: prompt,
      jsonSchema: GeneratedLesson.jsonSchema,
      systemPrompt: systemInstruction,
    );

    final rawMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    return GeneratedLesson.fromJson(rawMap);
  }

  /// Evaluates an existing or generated item and returns the quality report.
  ItemEvaluationReport evaluateItem(GeneratedAssessmentItem item) {
    return _evaluator.evaluate(item);
  }
}

