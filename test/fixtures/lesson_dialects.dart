// Producer-format fixtures for PR-0b (master plan v2.6 §14.9 / Appendix H.5).
//
// Each fixture follows the exact shape its real producer emits:
//  * quickGenerateResponse — the schema in
//    AiPromptService.generateLessonCreationPrompt (`{lesson, content}`,
//    term `title`/`content`, concept `key_points`/`examples`, MCQ textual
//    `correct_answer`). A test asserts the prompt still documents this shape.
//  * builderOutput — what CreateLessonScreen._createLessonFromBuilder wraps
//    around LessonBuilderWidget items (`correctIndex`, concept `keyPoints`).
//  * flatPersonal — the personal importer's native contract.

const quickGenerateResponse = <String, dynamic>{
  'lesson': {
    'title': 'Percent Change Basics',
    'description':
        'Compute percentage increase and decrease from two values '
        'and read the result correctly in a spreadsheet.',
    'estimated_duration_minutes': 20,
    'difficulty_level': 'beginner',
    'tags': ['math', 'percent'],
  },
  'content': [
    {
      'type': 'term',
      'title': 'Percent change',
      'content':
          'The difference between a new and old value, divided by the '
          'old value, times 100.',
      'example': 'From 50 to 60 is a 20% increase.',
      'emoji': '📈',
      'tags': ['core'],
    },
    {
      'type': 'concept',
      'title': 'Increase versus decrease',
      'content':
          'A positive result is an increase; a negative result is a '
          'decrease.',
      'key_points': ['Always divide by the original value', 'Keep the sign'],
      'examples': ['80 → 60 is −25%'],
    },
    {
      'type': 'mcq',
      'question': 'What is the percent change from 50 to 60?',
      'options': ['20%', '10%', '16.7%', '60%'],
      'correct_answer': '20%',
      'explanation': '(60 − 50) / 50 = 0.2 = 20%.',
    },
    {
      'type': 'mcq',
      'question': 'What is the percent change from 80 to 60?',
      'options': ['+25%', '−20%', '−25%', '+20%'],
      'correct_answer': '−25%',
      'explanation': '(60 − 80) / 80 = −0.25.',
    },
  ],
};

const builderOutput = <String, dynamic>{
  'lesson': {
    'title': 'Spreadsheet Formatting',
    'description': 'Format numbers as percentages.',
    'tags': ['excel'],
    'createdBy': 'user-1',
  },
  'content': [
    {
      'id': 'b-term-1',
      'type': 'term',
      'term': 'Percent format',
      'definition': 'Displays a value multiplied by 100 with a % sign.',
      'example': '0.25 shows as 25%.',
    },
    {
      'id': 'b-mcq-1',
      'type': 'mcq',
      'question': 'How does 0.5 display in percent format?',
      'options': ['50%', '0.5%', '5%'],
      'correctIndex': 0,
      'explanation': '0.5 × 100 = 50.',
    },
    {
      'id': 'b-mcq-2',
      'type': 'mcq',
      'question': 'Which value shows as 125%?',
      'options': ['12.5', '0.125', '1.25'],
      'correctIndex': 2,
    },
    {
      'id': 'b-concept-1',
      'type': 'concept',
      'title': 'Format is not value',
      'description': 'Formatting changes display only, not the stored value.',
      'keyPoints': ['Formulas use the stored value'],
    },
  ],
};

const flatPersonal = <String, dynamic>{
  'title': 'Fractions and Decimals',
  'terms': [
    {'term': 'Fraction', 'definition': 'A part of a whole.'},
  ],
  'questions': [
    {
      'question': '1/4 as a decimal?',
      'options': ['0.25', '0.4', '0.14'],
      'correct_answer': 0,
    },
  ],
};
