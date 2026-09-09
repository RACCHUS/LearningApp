import 'dart:convert';

import '../models/generation_session.dart';
import 'prompt_context_compressor.dart';

/// Service for generating AI prompts for lesson creation.
/// Supports both single-shot prompts (legacy) and phased multi-prompt
/// generation for higher quality and continuity across prompts.
class AiPromptService {

  // ===========================================================================
  // PHASED GENERATION PROMPTS (new — use these for guided generation)
  // ===========================================================================

  /// Phase 1: Generate a curriculum plan / blueprint before any content.
  /// The plan includes a content manifest and a terminology glossary that
  /// are injected into every subsequent prompt to lock terminology.
  static String generateCurriculumPlanPrompt({
    required String subject,
    required String targetAudience,
    required int durationMinutes,
    required String difficulty,
    required String contentFocus,
  }) {
    return '''
<role>You are a curriculum architect for a digital learning platform.</role>

<task>
Create a detailed lesson blueprint for the subject below. Do NOT generate any actual content yet — only the structural plan.
</task>

<parameters>
  <subject>$subject</subject>
  <audience>$targetAudience</audience>
  <duration_minutes>$durationMinutes</duration_minutes>
  <difficulty>$difficulty</difficulty>
  <focus>$contentFocus</focus>
</parameters>

<output_requirements>
Return ONLY valid JSON matching this schema:

{
  "lesson_plan": {
    "title": "Lesson title",
    "description": "2-3 sentence description",
    "difficulty": "beginner|intermediate|advanced",
    "estimated_duration_minutes": number,
    "learning_objectives": ["What the learner will know/do after this lesson"],
    "prerequisite_knowledge": ["What the learner should already know"],
    "key_terminology": ["Core terms that must be defined consistently throughout"]
  },
  "content_manifest": {
    "terms": [
      { "title": "Term name", "purpose": "Why this term is included", "order": 1 }
    ],
    "concepts": [
      { "title": "Concept name", "purpose": "What this concept teaches", "depends_on_terms": ["Term name"], "order": 1 }
    ],
    "mcqs": [
      { "tests_concept": "Concept name", "cognitive_level": "recall|understand|apply|analyze", "order": 1 }
    ]
  },
  "progression_notes": "How content builds from simple to complex",
  "terminology_glossary": {
    "Term name": "Canonical short definition to use consistently in all content"
  }
}
</output_requirements>

<quality_rules>
- Terms should cover foundational vocabulary needed for concepts.
- Concepts must reference the terms they depend on.
- MCQs must map to specific concepts and test understanding, not memorization.
- Aim for: ~30% terms, ~40% concepts, ~30% MCQs.
- Order items by progressive difficulty.
- The terminology_glossary provides canonical definitions to be reused word-for-word in later content generation.
</quality_rules>
''';
  }

  /// Phase 2a: Generate term definitions. Receives the plan so terminology
  /// stays locked. Supports batching for large lessons.
  static String generateTermsPrompt({
    required Map<String, dynamic> lessonPlan,
    required int batchStart,
    required int batchSize,
    required String difficulty,
  }) {
    final planJson = jsonEncode(lessonPlan);
    return '''
<role>You are an expert educational content writer.</role>

<context>
You are generating content for a lesson with the following plan. Follow this plan exactly.
<lesson_plan>$planJson</lesson_plan>
</context>

<task>
Generate the term definitions for items $batchStart through ${batchStart + batchSize - 1} from the content_manifest.terms array (0-indexed).
</task>

<critical_rules>
- Use the EXACT term titles from the content_manifest.
- Use the EXACT definitions from terminology_glossary as the foundation, then expand with examples.
- Each term must include a practical, concrete example.
- Write at a $difficulty level appropriate for the target audience.
- Do NOT add terms not in the manifest. Do NOT skip terms.
</critical_rules>

<output_format>
Return ONLY a JSON array:
[
  {
    "type": "term",
    "title": "Exact title from manifest",
    "content": "Clear definition (use terminology_glossary definition as base)",
    "example": "Practical real-world example",
    "emoji": "A single Unicode emoji that visually represents this term (e.g. 📦 for Variable, 🔢 for Integer)"
  }
]
</output_format>

<quality_checklist>
Before outputting, verify:
- [ ] Every term from the requested batch is present
- [ ] Definitions match the terminology_glossary
- [ ] Examples are specific, not generic
- [ ] No term references concepts not yet defined
</quality_checklist>
''';
  }

  /// Phase 2b: Generate concept explanations. Receives the plan AND the
  /// previously generated terms so concepts can reference them accurately.
  /// When [compressedContext] is provided, it replaces the raw JSON dumps
  /// to keep prompt size within token budgets.
  static String generateConceptsPrompt({
    required Map<String, dynamic> lessonPlan,
    required List<Map<String, dynamic>> generatedTerms,
    required int batchStart,
    required int batchSize,
    required String difficulty,
    String? compressedContext,
  }) {
    final contextBlock = compressedContext != null && compressedContext.isNotEmpty
        ? compressedContext
        : '<lesson_plan>${jsonEncode(lessonPlan)}</lesson_plan>\n<previously_generated_terms>${jsonEncode(generatedTerms)}</previously_generated_terms>';
    return '''
<role>You are an expert educational content writer.</role>

<context>
$contextBlock
</context>

<task>
Generate concept explanations for items $batchStart through ${batchStart + batchSize - 1} from content_manifest.concepts (0-indexed).
</task>

<critical_rules>
- Use the EXACT concept titles from the manifest.
- Reference the previously generated terms BY NAME (use the exact terminology).
- Each concept must have 2-4 key_points and at least 1 concrete example.
- Build on prior concepts — later concepts may reference earlier ones.
- Write at a $difficulty level appropriate for the stated audience.
</critical_rules>

<output_format>
Return ONLY a JSON array:
[
  {
    "type": "concept",
    "title": "Exact title from manifest",
    "content": "Detailed explanation referencing defined terms",
    "key_points": ["Point 1", "Point 2", "Point 3"],
    "examples": ["Concrete real-world example"],
    "emoji": "A single Unicode emoji that visually represents this concept (e.g. 🧠 for Mental Model, 🔄 for Loop)"
  }
]
</output_format>

<quality_checklist>
Before outputting, verify:
- [ ] Every concept from the requested batch is present
- [ ] Terms are referenced using their canonical definitions
- [ ] Key points are substantive, not vague
- [ ] Examples are specific and realistic
- [ ] Later concepts reference earlier ones where the manifest indicates dependencies
</quality_checklist>
''';
  }

  /// Phase 2c: Generate MCQ questions. Receives plan, terms, AND concepts
  /// so that questions align with the actual generated content.
  /// When [compressedContext] is provided, it replaces the raw JSON dumps
  /// to keep prompt size within token budgets.
  static String generateMcqsPrompt({
    required Map<String, dynamic> lessonPlan,
    required List<Map<String, dynamic>> generatedTerms,
    required List<Map<String, dynamic>> generatedConcepts,
    required int batchStart,
    required int batchSize,
    String? compressedContext,
  }) {
    final contextBlock = compressedContext != null && compressedContext.isNotEmpty
        ? compressedContext
        : '<lesson_plan>${jsonEncode(lessonPlan)}</lesson_plan>\n<lesson_terms>${jsonEncode(generatedTerms)}</lesson_terms>\n<lesson_concepts>${jsonEncode(generatedConcepts)}</lesson_concepts>';
    return '''
<role>You are an expert assessment designer.</role>

<context>
$contextBlock
</context>

<task>
Generate MCQ questions for items $batchStart through ${batchStart + batchSize - 1} from content_manifest.mcqs (0-indexed).
</task>

<critical_rules>
- Each MCQ must test the specific concept listed in "tests_concept".
- Match the cognitive_level specified in the manifest:
  - recall: testing definitions/facts
  - understand: testing comprehension of concepts
  - apply: testing ability to use knowledge in scenarios
  - analyze: testing ability to break down and evaluate
- WRONG answers (distractors) must be plausible but clearly incorrect.
- Explanations must teach — explain WHY the correct answer is right AND why each wrong answer is wrong.
- Use the exact terminology from the lesson (same words as terms and concepts).
</critical_rules>

<output_format>
Return ONLY a JSON array:
[
  {
    "type": "mcq",
    "question": "Clear question testing the mapped concept",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correct_answer": "The correct option text (must match exactly)",
    "explanation": "Why correct + brief note on why each distractor is wrong",
    "tests_concept": "Concept title from manifest",
    "cognitive_level": "recall|understand|apply|analyze"
  }
]
</output_format>

<quality_checklist>
Before outputting, verify:
- [ ] Each MCQ maps to its specified concept
- [ ] Cognitive levels match the manifest
- [ ] All 4 options are plausible
- [ ] correct_answer exactly matches one of the options
- [ ] Explanation addresses all options
- [ ] Terminology matches the lesson's glossary
</quality_checklist>
''';
  }

  /// Phase 3: Self-review prompt. The AI reviews all generated content
  /// against the original plan and returns corrections + a summary.
  static String generateSelfReviewPrompt({
    required Map<String, dynamic> lessonPlan,
    required List<Map<String, dynamic>> allContent,
  }) {
    final planJson = jsonEncode(lessonPlan);
    final contentJson = jsonEncode(allContent);
    return '''
<role>You are a senior educational content reviewer.</role>

<context>
<original_plan>$planJson</original_plan>
<generated_content>$contentJson</generated_content>
</context>

<task>
Review the generated content against the original plan and quality standards. Return a corrected version of any items that fail review, plus a summary.
</task>

<review_criteria>
1. TERMINOLOGY CONSISTENCY: Do all items use terms exactly as defined in the glossary?
2. PROGRESSIVE DIFFICULTY: Does content build logically from simple to complex?
3. COMPLETENESS: Is every item from the manifest present?
4. MCQ QUALITY:
   - Are all correct_answer values exact matches of an option?
   - Are distractors plausible but clearly wrong?
   - Do explanations teach rather than just state the answer?
5. EXAMPLE QUALITY: Are examples specific and realistic, not generic?
6. REDUNDANCY: Is any content repeated or substantially overlapping?
</review_criteria>

<output_format>
Return ONLY valid JSON:
{
  "review_summary": {
    "total_items": 0,
    "items_passed": 0,
    "items_revised": 0,
    "issues_found": ["Brief description of each issue"]
  },
  "revised_content": [
  ]
}

If all items pass review, revised_content should be an empty array.
Each revised item must include a "_revision_note" field explaining the change, plus all original fields with corrections applied.
</output_format>
''';
  }

  // ===========================================================================
  // RESUME PROMPT — for continuing in a new AI chat / different AI tool
  // ===========================================================================

  /// Generates a compact handoff prompt that lets the user continue their
  /// generation session in a new AI conversation (different chat, different
  /// AI tool, next day, etc.). Uses compressed context to fit token limits.
  static String generateResumePrompt({
    required GenerationSession session,
  }) {
    final compressedContext = PromptContextCompressor.buildContext(
      session: session,
      forPhase: session.currentPhase,
      maxTokens: 2000,
    );

    final phaseInstruction = _resumePhaseInstruction(session);

    return '''
<role>You are continuing a lesson generation session that was started in a previous conversation. Follow the plan and maintain consistency with all previously generated content.</role>

<session_state>
  <phase>${session.currentPhase.name}</phase>
  <subject>${session.subject}</subject>
  <difficulty>${session.difficulty}</difficulty>
  <audience>${session.targetAudience}</audience>
  <duration>${session.durationMinutes} minutes</duration>
  <focus>${session.contentFocus}</focus>
  <progress>${session.terms.length} terms, ${session.concepts.length} concepts, ${session.mcqs.length} MCQs generated so far</progress>
</session_state>

<context>
$compressedContext
</context>

$phaseInstruction
''';
  }

  static String _resumePhaseInstruction(GenerationSession session) {
    switch (session.currentPhase) {
      case GenerationPhase.planning:
        return '''
<task>Generate a curriculum plan for this lesson. Return ONLY valid JSON with: lesson_plan (title, description, difficulty, estimated_duration_minutes, learning_objectives, prerequisite_knowledge, key_terminology), content_manifest (terms array with title/purpose/order, concepts array with title/purpose/depends_on_terms/order, mcqs array with tests_concept/cognitive_level/order), progression_notes, and terminology_glossary.</task>''';

      case GenerationPhase.generatingTerms:
        final remaining = session.expectedTermCount - session.terms.length;
        final batchSize = remaining.clamp(1, 8);
        return '''
<task>Generate term definitions for items ${session.terms.length} through ${session.terms.length + batchSize - 1} from the content manifest terms array (0-indexed). Return ONLY a JSON array of objects with: type ("term"), title, content (definition), example, emoji (single Unicode emoji representing the term).</task>''';

      case GenerationPhase.generatingConcepts:
        final remaining = session.expectedConceptCount - session.concepts.length;
        final batchSize = remaining.clamp(1, 4);
        return '''
<task>Generate concept explanations for items ${session.concepts.length} through ${session.concepts.length + batchSize - 1} from the content manifest concepts array (0-indexed). Return ONLY a JSON array of objects with: type ("concept"), title, content (explanation), key_points (array), examples (array), emoji (single Unicode emoji representing the concept). Reference the previously generated terms by their exact names.</task>''';

      case GenerationPhase.generatingMcqs:
        final remaining = session.expectedMcqCount - session.mcqs.length;
        final batchSize = remaining.clamp(1, 5);
        return '''
<task>Generate MCQ questions for items ${session.mcqs.length} through ${session.mcqs.length + batchSize - 1} from the content manifest mcqs array (0-indexed). Return ONLY a JSON array of objects with: type ("mcq"), question, options (4 strings), correct_answer (matching one option exactly), explanation, tests_concept, cognitive_level. Use the exact terminology from the generated terms and concepts.</task>''';

      case GenerationPhase.reviewing:
        return '''
<task>Review all generated content against the plan. Return JSON with: review_summary (total_items, items_passed, items_revised, issues_found array), revised_content (array of corrected items with _revision_note field, or empty array if all pass).</task>''';

      case GenerationPhase.complete:
        return '<task>Session is complete. No further generation needed.</task>';
    }
  }

  // ===========================================================================
  // COURSE & CAREER STRUCTURE PROMPTS (skeleton only — content reuses lesson pipeline)
  // ===========================================================================

  /// Generates a course structure / skeleton. This does NOT generate lesson
  /// content — just the ordered list of lessons, their descriptions, and
  /// suggested content counts. Each lesson is then generated individually
  /// using the phased lesson pipeline.
  static String generateCourseStructurePrompt({
    required String topicArea,
    required String targetAudience,
    required String difficultyProgression,
    required int estimatedTotalHours,
  }) {
    return '''
<role>You are a curriculum designer creating a structured course outline.</role>

<task>
Design a course structure for the topic below. Generate ONLY the skeleton — lesson titles, descriptions, ordering, and suggested content counts. Do NOT generate actual lesson content.
</task>

<parameters>
  <topic>$topicArea</topic>
  <audience>$targetAudience</audience>
  <difficulty_progression>$difficultyProgression</difficulty_progression>
  <total_hours>$estimatedTotalHours</total_hours>
</parameters>

<output_format>
Return ONLY valid JSON:
{
  "course": {
    "title": "Course title",
    "description": "2-3 sentence course description",
    "category": "e.g. programming, IT, science",
    "difficulty": "beginner-to-intermediate",
    "estimated_hours": $estimatedTotalHours,
    "tags": ["tag1", "tag2"]
  },
  "lessons": [
    {
      "order": 1,
      "title": "Lesson title",
      "description": "What this lesson covers (2-3 sentences)",
      "difficulty": "beginner",
      "estimated_minutes": 30,
      "prerequisites": ["Lesson title that must come first"],
      "learning_objectives": ["What the learner will be able to do"],
      "suggested_content": { "terms": 6, "concepts": 4, "mcqs": 5 }
    }
  ],
  "progression_notes": "How difficulty and complexity build across the course"
}
</output_format>

<quality_rules>
- Create 4-12 lessons depending on topic breadth and total hours.
- Each lesson should be 15-60 minutes.
- Lessons must have a clear prerequisite chain — no circular dependencies.
- Difficulty should progress gradually (unless the audience is advanced).
- Later lessons should reference and build on earlier ones.
- suggested_content counts should reflect lesson complexity (longer/harder = more items).
</quality_rules>
''';
  }

  /// Generates a career path structure. This is the highest-level skeleton:
  /// which courses to take, what skills they map to, and in what order.
  /// Each course is then expanded via [generateCourseStructurePrompt],
  /// and each lesson via the phased lesson pipeline.
  static String generateCareerPathPrompt({
    required String careerGoal,
    required String currentLevel,
    required String timeCommitment,
  }) {
    return '''
<role>You are a career development and curriculum strategist.</role>

<task>
Design a career learning path for the goal below. Generate ONLY the structure — which courses and skills are needed, in what order, and how they connect. Do NOT generate lesson or course content.
</task>

<parameters>
  <career_goal>$careerGoal</career_goal>
  <current_level>$currentLevel</current_level>
  <time_commitment>$timeCommitment</time_commitment>
</parameters>

<output_format>
Return ONLY valid JSON:
{
  "career_path": {
    "title": "Path title (e.g. 'Junior Web Developer')",
    "description": "What this path prepares you for",
    "estimated_months": 6,
    "target_role": "Job title this leads to"
  },
  "skills": [
    {
      "name": "Skill name",
      "importance": "core|intermediate|supplementary",
      "description": "What this skill enables"
    }
  ],
  "courses": [
    {
      "order": 1,
      "title": "Course title",
      "description": "What this course covers",
      "is_required": true,
      "estimated_hours": 20,
      "skills_covered": ["Skill name"],
      "suggested_lesson_count": 8,
      "prerequisites": []
    }
  ],
  "milestones": [
    {
      "after_course": 2,
      "achievement": "What you can do at this point",
      "skills_unlocked": ["Skill name"]
    }
  ]
}
</output_format>

<quality_rules>
- Create 3-8 courses depending on career complexity.
- Skills should map to industry-standard competencies.
- Courses should have clear prerequisite relationships.
- includemilestones every 1-3 courses so learners see progress.
- Mark supplementary courses as is_required: false.
- Time estimates should be realistic for the stated time commitment.
</quality_rules>
''';
  }

  // ===========================================================================
  // LEGACY SINGLE-SHOT PROMPTS (kept for Quick Generate flow)
  // ===========================================================================

  /// Generates a comprehensive prompt for AI-assisted lesson creation
  static String generateLessonCreationPrompt({
    required String subject,
    required String targetAudience,
    required int durationMinutes,
    required String difficulty,
    required String contentFocus,
  }) {
    return '''
You are an expert educational content creator specializing in creating comprehensive, well-structured lessons for digital learning platforms. Your task is to create a complete lesson in JSON format based on the provided subject and parameters.

IMPORTANT: Always create a complete lesson regardless of topic scope. If the subject is too broad, create the best possible lesson while warning the user and providing suggestions.

LESSON STRUCTURE REQUIREMENTS:
- Title: Clear, descriptive, engaging
- Description: 2-3 sentences explaining what learners will gain
- Content Mix: Balance of terms (30%), concepts (40%), and assessments (30%)
- Progression: Logical flow from basic definitions to complex applications
- Assessment: MCQs that test understanding, not just memorization

CONTENT QUALITY STANDARDS:
- Terms: Clear definitions with practical examples
- Concepts: Detailed explanations with key points and real-world applications  
- MCQs: 4 options, clear correct answer, educational explanations
- Examples: Relevant, current, and relatable to target audience

OUTPUT FORMAT:
If the subject is too broad, first provide a warning, then the JSON:

⚠️ **SCOPE WARNING**: This topic is very broad for a single lesson. Consider creating focused sub-lessons instead:

**Suggested Focused Topics:**
1. **Topic Name 1** (30 min) - Brief description of what this would cover
2. **Topic Name 2** (45 min) - Brief description of what this would cover  
3. **Topic Name 3** (60 min) - Brief description of what this would cover

**However, here's a comprehensive introduction lesson:**

---

If the subject is appropriately scoped, provide only the JSON.

Always return valid JSON following this exact schema:

{
  "lesson": {
    "title": "string (required, 5-100 characters)",
    "description": "string (required, 50-500 characters)",
    "estimated_duration_minutes": number (required, 15-120),
    "difficulty_level": "string (required: beginner/intermediate/advanced)",
    "tags": ["array", "of", "strings"] (optional, for categorization)
  },
  "content": [
    {
      "type": "term",
      "title": "string (required)",
      "content": "string (required, clear definition)",
      "example": "string (optional, practical example)",
      "emoji": "string (optional, single Unicode emoji representing this term)",
      "tags": ["optional", "categorization", "tags"]
    },
    {
      "type": "concept",
      "title": "string (required)",
      "content": "string (required, detailed explanation)",
      "key_points": ["bullet", "point", "list"] (optional),
      "examples": ["practical", "examples"] (optional),
      "emoji": "string (optional, single Unicode emoji representing this concept)",
      "tags": ["optional", "categorization", "tags"]
    },
    {
      "type": "mcq",
      "question": "string (required, clear question)",
      "options": ["option A", "option B", "option C", "option D"] (required, exactly 4),
      "correct_answer": "string (required, must match one option exactly)",
      "explanation": "string (required, why this answer is correct)",
      "tags": ["optional", "categorization", "tags"]
    }
  ]
}

SCOPE ANALYSIS EXAMPLES:
For broad topics like "Programming": 
- Provide warning with focused suggestions before the JSON
- Create comprehensive introduction lesson covering fundamental concepts
- Keep the JSON clean without embedded warnings

For appropriately scoped topics like "Python Variable Types": 
- Provide only the clean JSON lesson
- No warning needed

PARAMETERS:
Subject: $subject
Target Audience: $targetAudience
Duration: $durationMinutes minutes
Difficulty: $difficulty
Content Focus: $contentFocus

Remember: Always create a complete, functional lesson. If the topic is broad, warn first, then provide clean JSON. Create engaging, educational content that progresses logically from basic concepts to practical applications. Ensure all MCQs test understanding rather than just memorization.
''';
  }

  /// Generates a prompt for content improvement suggestions
  static String generateContentImprovementPrompt(String existingContent) {
    return '''
You are an educational content quality expert. Please analyze the following lesson content and provide specific improvement suggestions:

CONTENT TO ANALYZE:
$existingContent

Please provide feedback on:

1. CONTENT QUALITY:
   - Clarity and readability
   - Educational effectiveness
   - Completeness of explanations
   - Use of examples and practical applications

2. STRUCTURE & FLOW:
   - Logical progression of concepts
   - Balance between different content types
   - Difficulty progression
   - Missing prerequisite knowledge

3. ASSESSMENT QUALITY:
   - MCQ effectiveness (testing understanding vs memorization)
   - Distractor quality in multiple choice options
   - Explanation clarity for correct answers

4. SPECIFIC RECOMMENDATIONS:
   - Content that should be added
   - Content that should be simplified or clarified
   - Better examples or analogies
   - Accessibility improvements

5. ENGAGEMENT FACTORS:
   - Ways to make content more engaging
   - Interactive elements that could be added
   - Real-world applications and relevance

Please provide specific, actionable suggestions for improvement.
''';
  }

  /// Generates a prompt for creating lesson series from broad topics
  static String generateSeriesSplittingPrompt(String broadTopic) {
    return '''
You are an educational curriculum designer. The topic "$broadTopic" is too broad for a single lesson. Please create a structured lesson series that breaks this topic into focused, manageable lessons.

REQUIREMENTS:
1. Create 3-7 focused lessons that together cover the broad topic
2. Each lesson should be 15-60 minutes in duration
3. Establish clear prerequisites and learning progression
4. Ensure logical flow from foundational to advanced concepts

OUTPUT FORMAT:
{
  "series": {
    "title": "Series name for the broad topic",
    "description": "Overview of what the entire series covers",
    "total_estimated_duration": "Total minutes for all lessons",
    "target_audience": "beginner/intermediate/advanced",
    "prerequisites": "What learners should know before starting"
  },
  "lessons": [
    {
      "order": 1,
      "title": "First lesson title",
      "description": "What this specific lesson covers",
      "estimated_duration": 30,
      "prerequisites": ["Any specific prerequisites for this lesson"],
      "learning_objectives": ["What learners will be able to do after this lesson"],
      "key_concepts": ["Main concepts covered"],
      "suggested_content_types": {
        "terms": 5,
        "concepts": 3,
        "mcqs": 4
      }
    }
  ],
  "learning_progression": {
    "foundational_concepts": "What must be learned first",
    "building_blocks": "How concepts build upon each other",
    "capstone_applications": "Final practical applications"
  },
  "cross_references": [
    {
      "from_lesson": 1,
      "to_lesson": 2,
      "relationship": "Lesson 2 builds on concepts from Lesson 1"
    }
  ]
}

TOPIC TO ANALYZE: $broadTopic

Please provide a comprehensive lesson series breakdown that would effectively teach this broad topic through focused, sequential lessons.
''';
  }

  /// Generates a prompt for validating lesson JSON structure
  static String generateValidationPrompt(String jsonContent) {
    return '''
You are a JSON schema validator and educational content reviewer. Please validate the following lesson JSON and provide feedback:

LESSON JSON TO VALIDATE:
$jsonContent

VALIDATION CHECKLIST:

1. JSON STRUCTURE:
   - Valid JSON syntax
   - All required fields present
   - Correct data types for all fields
   - Proper array structures

2. CONTENT REQUIREMENTS:
   - Title: 5-100 characters, descriptive
   - Description: 50-500 characters, informative
   - Duration: 15-120 minutes, realistic
   - Difficulty level: beginner/intermediate/advanced
   - Content array: At least 5 items, good mix of types

3. CONTENT QUALITY:
   - Terms: Clear definitions with examples
   - Concepts: Detailed explanations with key points
   - MCQs: 4 options, clear correct answer, good explanations
   - Logical progression from basic to advanced

4. EDUCATIONAL STANDARDS:
   - Age-appropriate content
   - Clear learning objectives
   - Practical examples and applications
   - Assessment alignment with content

Please provide:
- ✅ VALID ELEMENTS: What is correct and well-structured
- ❌ ERRORS: Critical issues that must be fixed
- ⚠️ WARNINGS: Suggestions for improvement
- 💡 RECOMMENDATIONS: Ways to enhance educational effectiveness

If there are errors, provide the corrected JSON structure.
''';
  }

  /// Generates a template selection prompt
  static String generateTemplatePrompt(String subjectArea) {
    return '''
You are an educational template designer. Create lesson templates for the subject area: "$subjectArea"

Please provide 3-5 different lesson templates that would be commonly used in this subject area. Each template should include:

1. Template name and description
2. Typical content structure
3. Recommended content types and quantities
4. Sample titles and topics
5. Target audience and difficulty level

OUTPUT FORMAT:
{
  "subject_area": "$subjectArea",
  "templates": [
    {
      "name": "Template Name",
      "description": "What this template is best used for",
      "structure": {
        "terms": "Number and type of terms typically needed",
        "concepts": "Number and type of concepts typically needed", 
        "mcqs": "Number and type of MCQs typically needed",
        "text": "Any additional text content needed"
      },
      "sample_topics": ["Example Topic 1", "Example Topic 2"],
      "target_audience": "beginner/intermediate/advanced",
      "typical_duration": "15-120 minutes",
      "best_practices": ["Tip 1", "Tip 2", "Tip 3"]
    }
  ]
}

Focus on creating practical, reusable templates that would help educators quickly structure lessons in this subject area.
''';
  }
}
