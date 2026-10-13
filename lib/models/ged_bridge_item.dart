/// Models for the GED Pre-Prep Adult Basic Education (ABE) Reading Bridge.
///
/// TRUTHFUL FRAMING & TRADEMARK ATTRIBUTION:
/// GED® is a registered trademark of the American Council on Education (ACE)
/// and administered exclusively by GED Testing Service LLC under license.
/// LearningApp is not affiliated with, sponsored by, or endorsed by ACE or
/// GED Testing Service.
///
/// The real GED® test is a timed, computer-based exam that requires substantial
/// reading comprehension. Audio and screen reader testing is ONLY available
/// through documented formal ADA accommodations approved by GED Testing Service.
/// This module serves as an Adult Basic Education (ABE) bridge that builds
/// foundational decoding and comprehension skills up to GED test readiness.
library;

/// Adult Basic Education (ABE) proficiency levels.
enum AbeLevel {
  /// Level 1: Beginning ABE Literacy (Grade Equivalency 0–1.9).
  /// Focus on phonics, CVC words, sight words, and single decodable sentences.
  level1BeginningLiteracy,

  /// Level 2: Beginning Basic Education (Grade Equivalency 2.0–3.9).
  /// Focus on short workplace notes, daily schedules, and compound sentences.
  level2BasicEducation,

  /// Level 3: Low Intermediate Basic Education (Grade Equivalency 4.0–5.9).
  /// Focus on multi-paragraph functional texts, science, health, and civics.
  level3LowIntermediate,
}

/// A comprehension question testing understanding of a reading passage.
class GedComprehensionQuestion {
  final String id;
  final String question;
  final String spokenQuestion;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const GedComprehensionQuestion({
    required this.id,
    required this.question,
    required this.spokenQuestion,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
  });
}

/// A reading passage in the ABE Bridge with synchronized lines and audio.
class GedBridgePassage {
  final String id;
  final String title;
  final AbeLevel level;
  final String gradeEquivalency;
  final String category;
  final List<String> sentences;
  final List<GedComprehensionQuestion> comprehensionQuestions;

  const GedBridgePassage({
    required this.id,
    required this.title,
    required this.level,
    required this.gradeEquivalency,
    required this.category,
    required this.sentences,
    required this.comprehensionQuestions,
  });

  /// Full text of the passage joined with spaces.
  String get fullText => sentences.join(' ');
}

/// Mandatory statutory trademark notice for GED materials.
const String gedTrademarkAttribution =
    'GED® is a registered trademark of the American Council on Education (ACE) '
    'and administered exclusively by GED Testing Service LLC under license. '
    'LearningApp is not affiliated with, sponsored by, or endorsed by ACE or '
    'GED Testing Service. The actual GED® exam requires independent reading '
    'unless granted formal ADA audio accommodations.';

/// Curated ABE reading passages spanning Levels 1, 2, and 3.
const List<GedBridgePassage> officialGedBridgeCatalog = [
  // --- LEVEL 1: Beginning Literacy (Grade 0–1.9) ---
  GedBridgePassage(
    id: 'ged_abe_101',
    title: 'Sam Starts His New Job',
    level: AbeLevel.level1BeginningLiteracy,
    gradeEquivalency: 'Grade 0 – 1.9',
    category: 'Workplace Basics',
    sentences: [
      'Sam has a new job at a shop.',
      'He arrives at eight in the morning.',
      'He puts on his blue work vest.',
      'Sam helps keep the shop clean and safe.',
      'He feels proud of his work today.',
    ],
    comprehensionQuestions: [
      GedComprehensionQuestion(
        id: 'q_abe_101_1',
        question: 'Where does Sam work?',
        spokenQuestion: 'Where does Sam work?',
        options: [
          'At a shop',
          'At a hospital',
          'On a farm',
          'At a school',
        ],
        correctOptionIndex: 0,
        explanation: 'The story says: "Sam has a new job at a shop."',
      ),
      GedComprehensionQuestion(
        id: 'q_abe_101_2',
        question: 'What color is his work vest?',
        spokenQuestion: 'What color is his work vest?',
        options: [
          'Blue',
          'Red',
          'Yellow',
          'Green',
        ],
        correctOptionIndex: 0,
        explanation: 'The story says: "He puts on his blue work vest."',
      ),
    ],
  ),

  GedBridgePassage(
    id: 'ged_abe_102',
    title: 'Taking the City Bus',
    level: AbeLevel.level1BeginningLiteracy,
    gradeEquivalency: 'Grade 0 – 1.9',
    category: 'Daily Living',
    sentences: [
      'Rosa waits at the bus stop.',
      'The bus has the number ten on the front.',
      'Rosa taps her bus pass at the box.',
      'She sits down next to the window.',
      'The bus takes her to the grocery store.',
    ],
    comprehensionQuestions: [
      GedComprehensionQuestion(
        id: 'q_abe_102_1',
        question: 'What number is on Rosa\'s bus?',
        spokenQuestion: 'What number is on Rosa\'s bus?',
        options: [
          'Number 10',
          'Number 5',
          'Number 20',
          'Number 100',
        ],
        correctOptionIndex: 0,
        explanation: 'The story says: "The bus has the number ten on the front."',
      ),
      GedComprehensionQuestion(
        id: 'q_abe_102_2',
        question: 'Where does the bus take Rosa?',
        spokenQuestion: 'Where does the bus take Rosa?',
        options: [
          'To the grocery store',
          'To the airport',
          'To the bank',
          'To the dentist',
        ],
        correctOptionIndex: 0,
        explanation:
            'The story states: "The bus takes her to the grocery store."',
      ),
    ],
  ),

  // --- LEVEL 2: Beginning Basic Education (Grade 2.0–3.9) ---
  GedBridgePassage(
    id: 'ged_abe_201',
    title: 'Reading a Fire Safety Notice',
    level: AbeLevel.level2BasicEducation,
    gradeEquivalency: 'Grade 2.0 – 3.9',
    category: 'Safety & Emergency',
    sentences: [
      'Every workplace has an emergency exit plan posted on the wall.',
      'In case of a fire alarm, do not use the elevator.',
      'Always walk quickly and calmly down the nearest stairs.',
      'Meet your team outside in the parking lot at the safe zone.',
      'Never go back inside the building until the fire chief says it is safe.',
    ],
    comprehensionQuestions: [
      GedComprehensionQuestion(
        id: 'q_abe_201_1',
        question: 'Why should you NOT use the elevator during a fire alarm?',
        spokenQuestion:
            'Why should you not use the elevator during a fire alarm?',
        options: [
          'Elevators can lose power or fill with smoke; always use stairs',
          'Elevators are only for managers',
          'Elevators cost extra money',
          'Elevators are too fast',
        ],
        correctOptionIndex: 0,
        explanation:
            'Elevators are dangerous during fires because electrical power can fail. Always use stairs.',
      ),
      GedComprehensionQuestion(
        id: 'q_abe_201_2',
        question: 'When is it safe to return into the building?',
        spokenQuestion: 'When is it safe to return into the building?',
        options: [
          'Only when the fire chief says it is safe',
          'As soon as the alarm stops ringing',
          'After 5 minutes',
          'When you want to grab your jacket',
        ],
        correctOptionIndex: 0,
        explanation:
            'The notice says: "Never go back inside until the fire chief says it is safe."',
      ),
    ],
  ),

  // --- LEVEL 3: Low Intermediate Basic Education (Grade 4.0–5.9) ---
  GedBridgePassage(
    id: 'ged_abe_301',
    title: 'Understanding How Plants Make Food (Photosynthesis)',
    level: AbeLevel.level3LowIntermediate,
    gradeEquivalency: 'Grade 4.0 – 5.9',
    category: 'Science Foundations',
    sentences: [
      'Green plants produce their own food through a natural process called photosynthesis.',
      'Plant leaves contain chlorophyll, a green chemical that absorbs sunlight.',
      'The plant takes in water through its roots and carbon dioxide gas from the surrounding air.',
      'Using energy from the sun, the plant turns water and carbon dioxide into sugar for energy.',
      'As a vital byproduct, plants release fresh oxygen gas back into the air for humans and animals to breathe.',
    ],
    comprehensionQuestions: [
      GedComprehensionQuestion(
        id: 'q_abe_301_1',
        question:
            'What green chemical in plant leaves absorbs energy from sunlight?',
        spokenQuestion:
            'What green chemical in plant leaves absorbs energy from sunlight?',
        options: [
          'Chlorophyll',
          'Carbon dioxide',
          'Oxygen',
          'Nitrogen',
        ],
        correctOptionIndex: 0,
        explanation:
            'Chlorophyll is the green pigment in leaves that traps sunlight for photosynthesis.',
      ),
      GedComprehensionQuestion(
        id: 'q_abe_301_2',
        question:
            'What vital gas do plants release that humans and animals need to breathe?',
        spokenQuestion:
            'What gas do plants release that humans and animals breathe?',
        options: [
          'Oxygen',
          'Carbon dioxide',
          'Helium',
          'Smoke',
        ],
        correctOptionIndex: 0,
        explanation:
            'Plants release fresh oxygen as a byproduct of photosynthesis.',
      ),
    ],
  ),
];
