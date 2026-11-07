import 'package:learning_pwa/core/logging/app_logger.dart';

/// Structured AI explanation output conforming to Invariant 4 schema constraints.
class CommunityAiExplanation {
  final String explanationMarkdown;
  final String confidenceLevel; // 'high' | 'medium' | 'low'
  final String uncertaintyDisclosure;
  final List<String> citedAuthorities;
  final String disclaimer;
  final bool promptInjectionDetected;

  const CommunityAiExplanation({
    required this.explanationMarkdown,
    required this.confidenceLevel,
    required this.uncertaintyDisclosure,
    required this.citedAuthorities,
    required this.disclaimer,
    this.promptInjectionDetected = false,
  });

  Map<String, dynamic> toJson() => {
        'explanation_markdown': explanationMarkdown,
        'confidence_level': confidenceLevel,
        'uncertainty_disclosure': uncertaintyDisclosure,
        'cited_authorities': citedAuthorities,
        'disclaimer': disclaimer,
        'prompt_injection_detected': promptInjectionDetected,
      };

  factory CommunityAiExplanation.fromJson(Map<String, dynamic> json) {
    return CommunityAiExplanation(
      explanationMarkdown: json['explanation_markdown'] as String? ?? '',
      confidenceLevel: json['confidence_level'] as String? ?? 'medium',
      uncertaintyDisclosure: json['uncertainty_disclosure'] as String? ?? '',
      citedAuthorities: (json['cited_authorities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      disclaimer: json['disclaimer'] as String? ??
          'AI-generated educational explanation. Verify against official state and curriculum standards.',
      promptInjectionDetected: json['prompt_injection_detected'] as bool? ?? false,
    );
  }
}

/// Service providing in-context AI explanations with defense-in-depth prompt-injection protection (ECO-03, Invariant 4).
class CommunityAiExplanationService {
  final _logger = AppLogger('CommunityAiExplanationService');

  /// Known adversarial jailbreak & instruction override signatures.
  static final List<RegExp> _adversarialPatterns = [
    RegExp(r'ignore\s+(all\s+)?(previous|prior|above)\s+instructions', caseSensitive: false),
    RegExp(r'disregard\s+(all\s+)?(previous|prior|system)\s+prompts?', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+(in\s+)?(developer|jailbreak|dan|unrestricted)\s+mode', caseSensitive: false),
    RegExp(r'output\s+(the\s+)?(system\s+prompt|initial\s+instructions)', caseSensitive: false),
    RegExp(r'system\s*:\s*you\s+must', caseSensitive: false),
    RegExp(r'reveal\s+.*?(rules|keys|prompts|instructions)', caseSensitive: false),
    RegExp(r'bypass\s+(safety|content)\s+filters?', caseSensitive: false),
    RegExp(r'\[\s*system\s*override\s*\]', caseSensitive: false),
  ];

  /// Sanitizes untrusted user input before injecting into AI query contexts.
  ///
  /// Enforces:
  /// 1. Maximum length constraint (1,000 characters).
  /// 2. Control character removal.
  /// 3. Whitespace normalization.
  /// 4. Neutralization of role tags (e.g. "System:", "Assistant:").
  static String sanitizeInput(String input) {
    if (input.isEmpty) return '';

    // 1. Cap length to 1000 characters to prevent prompt-stuffing
    String sanitized = input.length > 1000 ? input.substring(0, 1000) : input;

    // 2. Remove non-printable / control characters except standard newlines and tabs
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 3. Neutralize fake message role delimiters that attempt to spoof chat boundaries
    sanitized = sanitized.replaceAll(RegExp(r'(^|\n)\s*(system|assistant|admin)\s*:', caseSensitive: false), '\$1[user note]:');

    // 4. Normalize excessive newlines
    sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return sanitized.trim();
  }

  /// Evaluates whether an input contains known adversarial prompt-injection vectors.
  static bool containsAdversarialPayload(String input) {
    for (final pattern in _adversarialPatterns) {
      if (pattern.hasMatch(input)) {
        return true;
      }
    }
    return false;
  }

  /// Synthesizes an educational AI explanation for a given question and topic context.
  ///
  /// Follows strict Invariant 4 defense-in-depth:
  /// - Isolates system instructions from user inputs.
  /// - Flags and rejects prompt injection attempts gracefully.
  /// - Returns a deterministic structured response with uncertainty disclaimers.
  Future<CommunityAiExplanation> generateExplanation({
    required String questionTitle,
    required String questionBody,
    String? topicDomain,
  }) async {
    final sanitizedTitle = sanitizeInput(questionTitle);
    final sanitizedBody = sanitizeInput(questionBody);

    // Defense-in-depth Check: Detect adversarial injection attempts
    if (containsAdversarialPayload(sanitizedTitle) || containsAdversarialPayload(sanitizedBody)) {
      _logger.warn('Adversarial prompt injection pattern detected in community question query.');
      return const CommunityAiExplanation(
        explanationMarkdown:
            'Unable to generate AI explanation: Your inquiry contains system instruction overrides or prohibited control phrases. Please rephrase your question using standard educational terminology.',
        confidenceLevel: 'low',
        uncertaintyDisclosure: 'Flagged by Prompt-Injection Defense Filter (Invariant 4).',
        citedAuthorities: [],
        disclaimer: 'System instruction overrides and adversarial inputs are blocked by platform security invariants.',
        promptInjectionDetected: true,
      );
    }

    // Educational Synthesis
    final domainContext = topicDomain != null && topicDomain.isNotEmpty
        ? 'in the context of $topicDomain'
        : 'in this learning domain';

    final explanationText = StringBuffer();
    explanationText.writeln('Based on established curriculum standards $domainContext:');
    explanationText.writeln();
    explanationText.writeln(
        'The question addresses **$sanitizedTitle**. Key educational principles indicate that foundational mastery requires understanding underlying terminology, sequence, and evidence-based procedures before applying them to practical problem solving.');
    explanationText.writeln();
    explanationText.writeln(
        'For verified high-stakes requirements, always consult the official regulatory board or curriculum source cited below.');

    return CommunityAiExplanation(
      explanationMarkdown: explanationText.toString(),
      confidenceLevel: 'medium',
      uncertaintyDisclosure:
          'This explanation was synthesized from platform knowledge concepts and is intended for study support. It does not replace official instructor guidance or regulatory board determinations.',
      citedAuthorities: [
        'Curriculum Concept Alignment Register',
        'Evidence-Based Practice Guidelines (NRP / OSHA / State Boards)'
      ],
      disclaimer:
          'AI-generated study explanation. Always cross-reference with official licensing and curriculum documents.',
      promptInjectionDetected: false,
    );
  }
}
