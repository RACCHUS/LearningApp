/// Service for generating AI prompts for lesson creation
/// Users can copy these prompts to use with external AI tools
class AiPromptService {
  
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
      "tags": ["optional", "categorization", "tags"]
    },
    {
      "type": "concept",
      "title": "string (required)",
      "content": "string (required, detailed explanation)",
      "key_points": ["bullet", "point", "list"] (optional),
      "examples": ["practical", "examples"] (optional),
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
