import 'package:learning_pwa/models/rubric/long_answer_rubric.dart';

/// Service providing deterministic heuristic rubric evaluation and AI prompt safety.
class LongAnswerEvaluatorService {
  static final LongAnswerEvaluatorService instance =
      LongAnswerEvaluatorService._();

  LongAnswerEvaluatorService._();

  /// Known prompt injection signatures to neutralize (Invariant 4).
  static final List<RegExp> _injectionSignatures = [
    RegExp(r'ignore\s+(all\s+)?(previous|prior)\s+instructions', caseSensitive: false),
    RegExp(r'system\s+prompt', caseSensitive: false),
    RegExp(r'override\s+(all\s+)?rules', caseSensitive: false),
    RegExp(r'give\s+me\s+(full|100%|maximum)\s+(marks|points|score)', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+in\s+dan\s+mode', caseSensitive: false),
    RegExp(r'jailbreak', caseSensitive: false),
    RegExp(r'evaluator:\s*score\s*=', caseSensitive: false),
    RegExp(r'<\s*script[^>]*>', caseSensitive: false),
  ];

  /// Curated long-answer rubrics for vocational and professional education.
  static final List<LongAnswerRubric> defaultRubrics = [
    LongAnswerRubric(
      id: 'rubric-osha-scaffold-01',
      title: 'Scaffold Hazard Abatement & Fall Protection Plan',
      domainTopic: 'Workplace Safety (OSHA 1926)',
      promptQuestion:
          'Draft a comprehensive scaffold safety plan for a 3-tier supported scaffold on an active commercial jobsite. Specify required fall protection, daily inspection protocols, and regulatory citations.',
      minWords: 60,
      maxWords: 400,
      passingScore: 12,
      criteria: [
        RubricCriterion(
          id: 'crit-hazard-id',
          title: 'Hazard Identification & Load Capacity',
          description:
              'Identifies structural hazards, overhead electrocution clearance, load capacities, and plumb/level foundation.',
          weight: 1,
          mandatoryKeywords: ['load capacity', 'overhead power lines', 'base plates', 'mud sills', 'plumb'],
          regulatoryCitations: ['29 CFR 1926.451(a)', '29 CFR 1926.451(b)'],
          levelDescriptors: {
            RubricScoreLevel.exemplary: 'Identifies all structural and site hazards with exact load capacity standards.',
            RubricScoreLevel.proficient: 'Identifies major structural hazards and foundation requirements.',
            RubricScoreLevel.developing: 'Mentions fall hazards but omits foundation or load limits.',
            RubricScoreLevel.emerging: 'Vague hazard awareness without specific structural controls.',
            RubricScoreLevel.unacceptable: 'Fails to identify scaffold hazards.',
          },
        ),
        RubricCriterion(
          id: 'crit-fall-protection',
          title: 'Fall Protection Systems & Guardrails',
          description:
              'Specifies top rails, mid rails, toeboards, and personal fall arrest systems (PFAS) over 10 feet.',
          weight: 1,
          mandatoryKeywords: ['guardrails', 'top rail', 'midrail', 'toeboards', 'personal fall arrest system', '10 feet'],
          regulatoryCitations: ['29 CFR 1926.451(g)', '29 CFR 1926.502'],
          levelDescriptors: {
            RubricScoreLevel.exemplary: 'Detailed guardrail dimensions and PFAS anchor load specifications (5,000 lbs).',
            RubricScoreLevel.proficient: 'Accurately outlines guardrail components and 10-foot PFAS threshold.',
            RubricScoreLevel.developing: 'Mentions harnesses or railings without specifying triggers or components.',
            RubricScoreLevel.emerging: 'General mention of falling without required equipment names.',
            RubricScoreLevel.unacceptable: 'No fall protection plan articulated.',
          },
        ),
        RubricCriterion(
          id: 'crit-competent-person',
          title: 'Competent Person Daily Inspection & Tagout',
          description:
              'Outlines pre-shift inspection by a designated competent person, structural defect identification, and tagout.',
          weight: 1,
          mandatoryKeywords: ['competent person', 'pre-shift inspection', 'tagout', 'defective', 'red tag'],
          regulatoryCitations: ['29 CFR 1926.451(f)(3)'],
          levelDescriptors: {
            RubricScoreLevel.exemplary: 'Defines competent person authority, red/green tag procedures, and weather reinspection.',
            RubricScoreLevel.proficient: 'Specifies pre-shift inspection by competent person and removal of damaged parts.',
            RubricScoreLevel.developing: 'Mentions daily checks but omits competent person designation.',
            RubricScoreLevel.emerging: 'Only mentions looking at scaffold occasionally.',
            RubricScoreLevel.unacceptable: 'Fails to identify inspection requirements.',
          },
        ),
        RubricCriterion(
          id: 'crit-emergency-response',
          title: 'Emergency Rescue & Suspension Trauma Mitigation',
          description:
              'Describes prompt rescue procedures to mitigate suspension trauma following a fall arrest event.',
          weight: 1,
          mandatoryKeywords: ['prompt rescue', 'suspension trauma', 'emergency response', 'first aid'],
          regulatoryCitations: ['29 CFR 1926.502(d)(20)'],
          levelDescriptors: {
            RubricScoreLevel.exemplary: 'Actionable rescue timeline (<15 min) and physiological suspension trauma care.',
            RubricScoreLevel.proficient: 'Clear prompt rescue plan and emergency contact sequence.',
            RubricScoreLevel.developing: 'Mentions calling 911 without site-specific rescue gear.',
            RubricScoreLevel.emerging: 'Brief emergency mention without clear procedure.',
            RubricScoreLevel.unacceptable: 'Omits post-fall emergency rescue.',
          },
        ),
      ],
    ),
    LongAnswerRubric(
      id: 'rubric-florida-real-estate-02',
      title: 'Florida Brokerage Relationship & Fiduciary Disclosure',
      domainTopic: 'Florida Real Estate Law (F.S. Chapter 475)',
      promptQuestion:
          'Explain the three statutory brokerage relationship options available in Florida residential transactions under F.S. 475.278. Describe the required disclosures and specific fiduciary duties of a Single Agent.',
      minWords: 60,
      maxWords: 400,
      passingScore: 10,
      criteria: [
        RubricCriterion(
          id: 'crit-statutory-roles',
          title: 'Statutory Brokerage Relationships',
          description:
              'Correctly distinguishes Single Agent, Transaction Broker (presumed default), and No Brokerage Relationship.',
          weight: 1,
          mandatoryKeywords: ['single agent', 'transaction broker', 'no brokerage relationship', 'presumed'],
          regulatoryCitations: ['F.S. 475.278(1)', 'F.S. 475.278(2)'],
        ),
        RubricCriterion(
          id: 'crit-single-agent-duties',
          title: 'Single Agent Fiduciary Duties',
          description:
              'Details loyalty, confidentiality, obedience, full disclosure, and accounting for funds (COLD).',
          weight: 1,
          mandatoryKeywords: ['loyalty', 'confidentiality', 'obedience', 'full disclosure', 'fiduciary'],
          regulatoryCitations: ['F.S. 475.278(3)'],
        ),
        RubricCriterion(
          id: 'crit-disclosure-timing',
          title: 'Mandatory Written Disclosure Timing',
          description:
              'Specifies required written disclosure timing before entering into an agreement or showing property.',
          weight: 1,
          mandatoryKeywords: ['written disclosure', 'prior to', 'showing property', 'written notice'],
          regulatoryCitations: ['F.S. 475.278(4)'],
        ),
      ],
    ),
  ];

  /// Detects potential adversarial prompt injections and returns sanitized text.
  ({bool detected, String sanitized}) sanitizeStudentInput(String text) {
    bool detected = false;
    String sanitized = text;

    for (final pattern in _injectionSignatures) {
      if (pattern.hasMatch(sanitized)) {
        detected = true;
        sanitized = sanitized.replaceAll(pattern, '[FLAGGED INPUT REMOVED]');
      }
    }

    return (detected: detected, sanitized: sanitized);
  }

  /// Calculates word count of a submission.
  int countWords(String text) {
    final tokens = text.trim().split(RegExp(r'\s+'));
    return tokens.where((t) => t.isNotEmpty).length;
  }

  /// Evaluates an open-ended essay response against an analytic rubric.
  /// Combines deterministic keyword/citation pattern matching with rubric performance levels.
  LongAnswerEvaluationResult evaluateSubmission({
    required LongAnswerRubric rubric,
    required String studentText,
    bool simulateAiRefinement = false,
  }) {
    final sanitization = sanitizeStudentInput(studentText);
    final wordCount = countWords(studentText);
    final normalizedText = studentText.toLowerCase();

    final Map<String, CriterionScoreResult> criterionResults = {};
    int totalScore = 0;

    for (final criterion in rubric.criteria) {
      // 1. Identify matched keywords
      final matchedKeywords = <String>[];
      final missingKeywords = <String>[];

      for (final kw in criterion.mandatoryKeywords) {
        if (normalizedText.contains(kw.toLowerCase())) {
          matchedKeywords.add(kw);
        } else {
          missingKeywords.add(kw);
        }
      }

      // 2. Identify matched regulatory citations
      final matchedCitations = <String>[];
      final missingCitations = <String>[];

      for (final citation in criterion.regulatoryCitations) {
        // Strip out non-alphanumeric for flexible citation matching
        final normCit = citation.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final cleanText = normalizedText.replaceAll(RegExp(r'[^a-z0-9]'), '');

        if (cleanText.contains(normCit) || normalizedText.contains(citation.toLowerCase())) {
          matchedCitations.add(citation);
        } else {
          missingCitations.add(citation);
        }
      }

      // 3. Compute score ratios
      final double keywordRatio = criterion.mandatoryKeywords.isEmpty
          ? 1.0
          : (matchedKeywords.length / criterion.mandatoryKeywords.length);

      final double citationRatio = criterion.regulatoryCitations.isEmpty
          ? 1.0
          : (matchedCitations.length / criterion.regulatoryCitations.length);

      final double combinedRatio = (keywordRatio * 0.7) + (citationRatio * 0.3);

      // 4. Determine score level
      RubricScoreLevel level;
      if (wordCount < 10) {
        level = RubricScoreLevel.unacceptable;
      } else if (combinedRatio >= 0.85 && wordCount >= rubric.minWords) {
        level = RubricScoreLevel.exemplary;
      } else if (combinedRatio >= 0.55 && wordCount >= (rubric.minWords * 0.7).round()) {
        level = RubricScoreLevel.proficient;
      } else if (combinedRatio >= 0.25 || wordCount >= (rubric.minWords * 0.5).round()) {
        level = RubricScoreLevel.developing;
      } else if (matchedKeywords.isNotEmpty) {
        level = RubricScoreLevel.emerging;
      } else {
        level = RubricScoreLevel.unacceptable;
      }

      // Length penalty: if significantly below min words, cap at developing
      if (wordCount < rubric.minWords && level.points > RubricScoreLevel.developing.points) {
        level = RubricScoreLevel.developing;
      }

      final earnedPoints = level.points * criterion.weight;
      totalScore += earnedPoints;

      // 5. Generate constructive feedback
      String rationale;
      String tip;

      if (level == RubricScoreLevel.exemplary) {
        rationale =
            'Excellent coverage. Mastered key technical concepts including ${matchedKeywords.take(3).join(', ')}'
            '${matchedCitations.isNotEmpty ? ' with proper regulatory citations (${matchedCitations.join(', ')})' : ''}.';
        tip = 'Strong professional response. Maintain this rigor on certification examinations.';
      } else if (level == RubricScoreLevel.proficient) {
        rationale =
            'Meets required standard. Correctly incorporated ${matchedKeywords.join(', ')}.'
            '${missingKeywords.isNotEmpty ? ' Omitted secondary elements: ${missingKeywords.join(', ')}.' : ''}';
        tip = missingKeywords.isNotEmpty
            ? 'Strengthen your analysis by directly discussing ${missingKeywords.first}.'
            : 'Good work. Include explicit statutory references for maximum clarity.';
      } else if (level == RubricScoreLevel.developing) {
        rationale =
            'Partial understanding shown. Found: ${matchedKeywords.isNotEmpty ? matchedKeywords.join(', ') : 'minimal required terminology'}.'
            '${missingKeywords.isNotEmpty ? ' Missing essential concepts: ${missingKeywords.join(', ')}.' : ''}';
        tip = 'Explicitly define and apply required terminology: ${missingKeywords.take(2).join(', ')}.';
      } else if (level == RubricScoreLevel.emerging) {
        rationale =
            'Initial attempt with limited technical depth. Response lacked most required criteria.';
        tip = 'Review the rubric criteria and include required vocabulary and regulatory sections.';
      } else {
        rationale =
            'Response does not sufficiently address this criterion or is too brief.';
        tip = 'Review the lesson material on ${criterion.title} and re-attempt.';
      }

      criterionResults[criterion.id] = CriterionScoreResult(
        criterionId: criterion.id,
        level: level,
        points: earnedPoints,
        matchedKeywords: matchedKeywords,
        missingKeywords: missingKeywords,
        matchedCitations: matchedCitations,
        missingCitations: missingCitations,
        rationale: rationale,
        improvementTip: tip,
      );
    }

    final maxScore = rubric.maxScore;
    final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;
    final passed = totalScore >= rubric.passingScore;

    // Overall summary
    String summary;
    if (sanitization.detected) {
      summary =
          'Note: Potential prompt injection phrases were flagged and neutralized. '
          'Grading proceeded strictly via rubric heuristics.';
    } else if (passed) {
      summary = percentage >= 90.0
          ? 'Outstanding mastery! Your submission comprehensively addresses all regulatory and procedural standards.'
          : 'Passing submission. You demonstrated solid understanding across the rubric criteria with room for slight refinement.';
    } else {
      summary =
          'Developing submission. Your response requires additional technical specifics and regulatory citations to meet the passing threshold (${rubric.passingScore}/$maxScore pts).';
    }

    return LongAnswerEvaluationResult(
      rubricId: rubric.id,
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: double.parse(percentage.toStringAsFixed(1)),
      passed: passed,
      wordCount: wordCount,
      criterionResults: criterionResults,
      summaryFeedback: summary,
      usedAi: simulateAiRefinement,
      flagPotentialPromptInjection: sanitization.detected,
    );
  }
}

