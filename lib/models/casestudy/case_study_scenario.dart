/// Evidence exhibit attached to a professional case study (P8-5).
class CaseStudyExhibit {
  final String id;
  final String title;
  final String type; // 'document', 'log', 'warning', 'citation'
  final String contentMarkdown;

  const CaseStudyExhibit({
    required this.id,
    required this.title,
    required this.type,
    required this.contentMarkdown,
  });

  factory CaseStudyExhibit.fromJson(Map<String, dynamic> json) {
    return CaseStudyExhibit(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'document',
      contentMarkdown: json['content_markdown'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'content_markdown': contentMarkdown,
      };
}

/// A branching decision choice at a scenario fork point.
class CaseStudyDecisionChoice {
  final String id;
  final String text;
  final bool isOptimal;
  final String feedback;
  final String? regulatoryCitation;

  const CaseStudyDecisionChoice({
    required this.id,
    required this.text,
    required this.isOptimal,
    required this.feedback,
    this.regulatoryCitation,
  });

  factory CaseStudyDecisionChoice.fromJson(Map<String, dynamic> json) {
    return CaseStudyDecisionChoice(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isOptimal: json['is_optimal'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? '',
      regulatoryCitation: json['regulatory_citation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'is_optimal': isOptimal,
        'feedback': feedback,
        if (regulatoryCitation != null)
          'regulatory_citation': regulatoryCitation,
      };
}

/// A progressive step within a scenario-based case study.
class CaseStudyStep {
  final String id;
  final int stepNumber;
  final String narrative;
  final List<CaseStudyExhibit> exhibits;
  final List<CaseStudyDecisionChoice> choices;

  const CaseStudyStep({
    required this.id,
    required this.stepNumber,
    required this.narrative,
    this.exhibits = const [],
    this.choices = const [],
  });

  factory CaseStudyStep.fromJson(Map<String, dynamic> json) {
    return CaseStudyStep(
      id: json['id'] as String? ?? '',
      stepNumber: json['step_number'] as int? ?? 1,
      narrative: json['narrative'] as String? ?? '',
      exhibits: (json['exhibits'] as List<dynamic>?)
              ?.map((e) => CaseStudyExhibit.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      choices: (json['choices'] as List<dynamic>?)
              ?.map((c) =>
                  CaseStudyDecisionChoice.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'step_number': stepNumber,
        'narrative': narrative,
        'exhibits': exhibits.map((e) => e.toJson()).toList(),
        'choices': choices.map((c) => c.toJson()).toList(),
      };
}

/// Complete scenario-based professional case study (P8-5).
class CaseStudyScenario {
  final String id;
  final String title;
  final String domain;
  final String difficulty;
  final String overview;
  final List<CaseStudyStep> steps;

  const CaseStudyScenario({
    required this.id,
    required this.title,
    required this.domain,
    this.difficulty = 'Intermediate',
    required this.overview,
    required this.steps,
  });

  factory CaseStudyScenario.fromJson(Map<String, dynamic> json) {
    return CaseStudyScenario(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      domain: json['domain'] as String? ?? 'General',
      difficulty: json['difficulty'] as String? ?? 'Intermediate',
      overview: json['overview'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => CaseStudyStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'domain': domain,
        'difficulty': difficulty,
        'overview': overview,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

