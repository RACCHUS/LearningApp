import 'learning_data_source.dart';

class McpPromptArgument {
  final String name;
  final String description;
  final bool required;

  McpPromptArgument({
    required this.name,
    required this.description,
    this.required = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'required': required,
    };
  }
}

class McpPromptDefinition {
  final String name;
  final String description;
  final List<McpPromptArgument> arguments;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> args) generator;

  McpPromptDefinition({
    required this.name,
    required this.description,
    required this.arguments,
    required this.generator,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'arguments': arguments.map((a) => a.toJson()).toList(),
    };
  }
}

class McpPromptsRegistry {
  final LearningDataSource dataSource;
  final Map<String, McpPromptDefinition> _prompts = {};

  McpPromptsRegistry({required this.dataSource}) {
    _registerAllPrompts();
  }

  List<Map<String, dynamic>> listPrompts() {
    return _prompts.values.map((p) => p.toJson()).toList();
  }

  Future<Map<String, dynamic>> getPrompt(String name, Map<String, dynamic> arguments) async {
    final prompt = _prompts[name];
    if (prompt == null) {
      throw FormatException('Prompt not found: $name');
    }
    return await prompt.generator(arguments);
  }

  void _registerAllPrompts() {
    // 1. study_weak_concepts
    _prompts['study_weak_concepts'] = McpPromptDefinition(
      name: 'study_weak_concepts',
      description: 'Generate a focused practice set targeting the learner\'s weakest concepts on a learning target.',
      arguments: [
        McpPromptArgument(
          name: 'target_slug',
          description: 'The slug of the learning target (e.g. cert-comptia-security-plus).',
          required: true,
        ),
        McpPromptArgument(
          name: 'concept_limit',
          description: 'Maximum number of weak concepts to target (default 3).',
          required: false,
        ),
      ],
      generator: (args) async {
        final targetSlug = args['target_slug'] as String;
        final outline = await dataSource.getTargetOutline(targetSlug);
        final title = outline?['target']?['title'] ?? targetSlug;

        return {
          'description': 'Targeted retrieval practice for weak concepts in $title',
          'messages': [
            {
              'role': 'user',
              'content': {
                'type': 'text',
                'text': '''You are an expert tutor in "$title".
The learner has identified weak retention and low accuracy in their recent study sessions.

Please follow these evidence-based instruction steps:
1. First call `get_learner_state` for this target to inspect their specific weak concepts and retention probabilities.
2. Formulate 3 scenario-based application questions adhering to Haladyna (2002) item-writing rules:
   - Positive phrasing in stems (no "NOT" or "EXCEPT").
   - Plausible distractors representing common misconceptions.
   - Four options of similar length.
   - Grounded citations for each explanation.
3. Present each question one at a time and ask the learner to select their answer before providing the explanation.
''',
              },
            }
          ],
        };
      },
    );

    // 2. socratic_tutor
    _prompts['socratic_tutor'] = McpPromptDefinition(
      name: 'socratic_tutor',
      description: 'Act as a Socratic tutor guiding the learner through a complex concept without giving away answers.',
      arguments: [
        McpPromptArgument(
          name: 'concept_slug',
          description: 'The concept to teach (e.g. zero-trust-architecture, public-key-cryptography).',
          required: true,
        ),
        McpPromptArgument(
          name: 'learner_level',
          description: 'Learner proficiency level (beginner, intermediate, advanced).',
          required: false,
        ),
      ],
      generator: (args) async {
        final concept = args['concept_slug'] as String;
        final level = (args['learner_level'] as String?) ?? 'intermediate';

        return {
          'description': 'Socratic dialogue on $concept ($level level)',
          'messages': [
            {
              'role': 'user',
              'content': {
                'type': 'text',
                'text': '''You are a master Socratic educator specializing in "$concept". The learner is currently at a "$level" level.

Pedagogical rules:
1. Never lecture or provide full direct definitions upfront.
2. Ask one probing, scenario-based question at a time to lead the learner to discover the underlying principles.
3. If the learner makes a mistake, acknowledge what parts are intuitive, introduce a counter-example scenario, and ask them to reconsider.
4. Conclude only after the learner successfully synthesizes the concept in their own words.
''',
              },
            }
          ],
        };
      },
    );

    // 3. exam_readiness_coaching
    _prompts['exam_readiness_coaching'] = McpPromptDefinition(
      name: 'exam_readiness_coaching',
      description: 'Analyze learner readiness and blueprint weights to produce an actionable study schedule.',
      arguments: [
        McpPromptArgument(
          name: 'target_slug',
          description: 'The target certification or course slug.',
          required: true,
        ),
        McpPromptArgument(
          name: 'exam_date',
          description: 'Target exam date (e.g. 2026-12-15).',
          required: false,
        ),
      ],
      generator: (args) async {
        final targetSlug = args['target_slug'] as String;
        final examDate = args['exam_date'] as String? ?? 'in 30 days';

        return {
          'description': 'Exam readiness coaching and study schedule for $targetSlug',
          'messages': [
            {
              'role': 'user',
              'content': {
                'type': 'text',
                'text': '''You are an evidence-based learning coach preparing a learner for "$targetSlug" scheduled for "$examDate".

Please execute the following plan:
1. Query `get_exam_blueprint` for "$targetSlug" to understand the domain weights and passing score threshold.
2. Query `get_learner_state` to obtain the learner's current calibrated retrievability, readiness band, and weakest concepts.
3. Synthesize the findings into an actionable, prioritized weekly study schedule:
   - Allocate daily review time proportionally to domain weight multiplied by weakness gap.
   - Incorporate interleaved practice and spaced retrieval (FSRS).
   - Set intermediate retention milestones leading up to "$examDate".
''',
              },
            }
          ],
        };
      },
    );
  }
}
