import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/ai/generated_content_models.dart';
import 'package:learning_pwa/services/ai/item_evaluator.dart';

void main() {
  group('Automated BYOK Evaluation Suite (ARCH-4, §5)', () {
    late ItemEvaluator evaluator;

    setUp(() {
      evaluator = ItemEvaluator();
    });

    test('scoring >= 20 generated items: 0 answer leaks, >=90% citations, balanced lengths', () {
      final goldenItems = <GeneratedAssessmentItem>[
        // --- SECTOR 1: FLORIDA CONTRACTOR (FBC, OSHA, LIEN LAW) ---
        const GeneratedAssessmentItem(
          prompt:
              'Under the Florida Building Code, what is the minimum required ground slope away from foundation walls for the first 10 feet?',
          options: [
            '6 inches fall within 10 feet (5% grade)',
            '2 inches fall within 10 feet (1.7% grade)',
            '12 inches fall within 10 feet (10% grade)',
            '3 inches fall within 10 feet (2.5% grade)',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: FBC §1804.4 requires at least 6 inches fall in the first 10 feet. Options B, C, and D are incorrect grade percentages.',
          sourceCitation: 'Florida Building Code (Building) §1804.4',
          bloomLevel: 'apply',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'According to OSHA 29 CFR 1926.501, at what elevation must construction workers be protected by fall protection systems?',
          options: [
            '6 feet or more above lower levels',
            '4 feet or more above lower levels',
            '8 feet or more above lower levels',
            '10 feet or more above lower levels',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: OSHA 1926.501(b)(1) requires fall protection at 6 feet for construction. 4 feet applies to general industry.',
          sourceCitation: '29 CFR 1926.501(b)(1)',
          bloomLevel: 'remember',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'Within how many days after commencing work must a sub-subcontractor serve a Notice to Owner under Florida Statute 713?',
          options: [
            '45 days from first furnishing labor/materials',
            '30 days from first furnishing labor/materials',
            '60 days from first furnishing labor/materials',
            '90 days from first furnishing labor/materials',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: F.S. §713.06(2)(a) mandates that Notice to Owner must be served before commencing or not later than 45 days after commencing work.',
          sourceCitation: 'Florida Statutes §713.06(2)(a)',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What is the maximum allowable slump for structural concrete placed without water-reducing admixtures under standard FBC guidelines?',
          options: [
            '4 inches maximum measured slump',
            '2 inches maximum measured slump',
            '6 inches maximum measured slump',
            '8 inches maximum measured slump',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Standard Florida specifications cap structural concrete slump at 4 inches unless plasticizers are specified.',
          sourceCitation: 'ACI 301 / FBC Chapter 19 §1904',
          bloomLevel: 'apply',
          difficulty: 'advanced',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What is the minimum overlap required for reinforcing steel lap splices in tension under FBC structural requirements?',
          options: [
            'At least 48 bar diameters or 12 inches',
            'At least 24 bar diameters or 6 inches',
            'At least 36 bar diameters or 9 inches',
            'At least 60 bar diameters or 18 inches',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Standard tension lap splice requirements require Class B splices of at least 48 bar diameters.',
          sourceCitation: 'ACI 318-14 §25.5 / FBC §1908',
          bloomLevel: 'apply',
          difficulty: 'advanced',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'How long does a contractor have to record a Claim of Lien after final furnishing of labor or materials in Florida?',
          options: [
            'Not later than 90 days from final work',
            'Not later than 45 days from final work',
            'Not later than 60 days from final work',
            'Not later than 120 days from final work',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Florida Statute §713.08(5) sets a strict 90-day recording deadline after final performance.',
          sourceCitation: 'Florida Statutes §713.08(5)',
          bloomLevel: 'remember',
          difficulty: 'intermediate',
        ),

        // --- SECTOR 2: FLORIDA INSURANCE & FINANCIAL SERVICES ---
        const GeneratedAssessmentItem(
          prompt:
              'Under Florida Insurance Code, what is the statutory grace period for paying an individual life insurance premium?',
          options: [
            '30 days from the scheduled due date',
            '14 days from the scheduled due date',
            '45 days from the scheduled due date',
            '60 days from the scheduled due date',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: F.S. §627.453 requires a grace period of not less than 30 days (or one month) for individual life policies.',
          sourceCitation: 'Florida Statutes §627.453',
          bloomLevel: 'remember',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What primary entity regulates the licensing of insurance agents, agencies, and adjusters in the state of Florida?',
          options: [
            'Florida Department of Financial Services (DFS)',
            'Florida Office of Insurance Regulation (OIR)',
            'National Association of Insurance Commissioners',
            'Federal Insurance Administration (FIA)',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: The DFS regulates agent licensing and education; the OIR oversees company solvency and rates.',
          sourceCitation: 'Florida Statutes Title XXXVII §624.307',
          bloomLevel: 'understand',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What unlawful practice occurs when an agent makes incomplete policy comparisons to induce a client to lapse existing insurance?',
          options: [
            'Twisting under Florida Unfair Practices law',
            'Rebating of agent premium commission fees',
            'Coercion of consumer credit loan rights',
            'Defamation of competing insurance carriers',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: F.S. §626.9541(1)(l) defines twisting as fraudulent or incomplete comparison to induce policy surrender.',
          sourceCitation: 'Florida Statutes §626.9541(1)(l)',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'When must an insurable interest exist for a valid property insurance contract to be legally enforceable in Florida?',
          options: [
            'At the time the covered property loss occurs',
            'Only when the initial policy contract is signed',
            'Continuously without any brief interruption',
            'At policy renewal anniversary dates exclusively',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Under F.S. §627.405(1), insurable interest in property must exist at the time of loss.',
          sourceCitation: 'Florida Statutes §627.405(1)',
          bloomLevel: 'apply',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What is the maximum fine per willful violation of the Florida Unfair Insurance Trade Practices Act?',
          options: [
            'Up to \$40,000 per willful statutory violation',
            'Up to \$10,000 per willful statutory violation',
            'Up to \$25,000 per willful statutory violation',
            'Up to \$75,000 per willful statutory violation',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Willful violations carry fines up to \$40,000 each under F.S. §626.9521.',
          sourceCitation: 'Florida Statutes §626.9521',
          bloomLevel: 'remember',
          difficulty: 'advanced',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What type of insurance policy provides liability coverage above underlying limits with broader coverage for uncovered losses?',
          options: [
            'Commercial umbrella liability policy protection',
            'Excess liability insurance policy coverage',
            'Standard commercial general liability policy',
            'Inland marine transit floater policy form',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Umbrella policies provide both excess limits and drop-down coverage over retained limits.',
          sourceCitation: 'Florida General Lines Study Manual Chapter 10',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),

        // --- SECTOR 3: LITERACY & ADULT PHONICS (SUBLEXICAL ORTHOGRAPHIC) ---
        const GeneratedAssessmentItem(
          prompt:
              'In the Science of Reading framework, what term describes the ability to hear and manipulate individual sounds in spoken words?',
          options: [
            'Phonemic awareness sound manipulation ability',
            'Phonics grapheme-to-phoneme decoding skills',
            'Orthographic orthographic word mapping memory',
            'Morphological root-and-affix structural parsing',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Phonemic awareness specifically refers to isolating and blending spoken phonemes without print.',
          sourceCitation: 'National Reading Panel Report (NICHD, 2000) §2',
          bloomLevel: 'remember',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'Which syllable type contains a single vowel followed by one or more consonants, causing the vowel to make its short sound?',
          options: [
            'Closed syllable pattern such as "cat" or "nap"',
            'Open syllable pattern such as "he" or "go"',
            'Vowel team pattern such as "boat" or "meat"',
            'Vowel-consonant-e pattern such as "hope" or "gate"',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: In closed syllables, the vowel is closed in by consonants and typically produces a short sound.',
          sourceCitation: 'Moats (2020) Speech to Print: Language Essentials',
          bloomLevel: 'understand',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What spelling rule explains why the final consonant is doubled in words like "hop" becoming "hopping"?',
          options: [
            '1-1-1 rule: one syllable, one vowel, one final stop',
            'Drop-e rule: drop final silent e before vowel affixes',
            'Change-y rule: change final y to i before vowel endings',
            'Floss rule: double f, l, s, or z after single short vowels',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: The 1-1-1 rule doubles the final consonant when adding a vowel suffix to a 1-syllable CVC base.',
          sourceCitation: 'Moats (2020) Speech to Print Chapter 8',
          bloomLevel: 'apply',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'In English orthography, what phoneme is typically produced by the digraph "ch" in words of Greek etymology such as "chorus"?',
          options: [
            'The /k/ sound as heard in the word "character"',
            'The /ch/ sound as heard in the word "church"',
            'The /sh/ sound as heard in the word "chef"',
            'The /s/ sound as heard in the word "city"',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Greek roots with "ch" (chorus, ache, chemist) represent the Greek letter Chi, pronounced /k/.',
          sourceCitation: 'Venezky (1999) The American Way of Spelling',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What cognitive process permanently bonds a word’s pronunciation, spelling, and meaning in memory for instantaneous retrieval?',
          options: [
            'Orthographic mapping into lexical retrieval memory',
            'Visual sight memorization by overall silhouette shape',
            'Auditory repetition chanting through oral recitation',
            'Contextual guessing using surrounding sentence syntax',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Ehri’s orthographic mapping theory establishes that phoneme-grapheme connections store sight words in lexical memory.',
          sourceCitation: 'Ehri, L. C. (2014) Scientific Studies of Reading 18(1)',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),

        // --- SECTOR 4: HEALTHCARE & CIVICS ---
        const GeneratedAssessmentItem(
          prompt:
              'Under the HIPAA Privacy Rule, what standard requires covered entities to limit protected health information to only what is necessary?',
          options: [
            'Minimum necessary rule standards protocol',
            'Full medical disclosure mandate directive',
            'Treatment continuity exceptions protocol',
            'Designated record set retention standards',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: 45 CFR §164.502(b) mandates that entities must make reasonable efforts to use or disclose only the minimum necessary PHI.',
          sourceCitation: '45 CFR §164.502(b)',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'According to the United States Constitution, what is the primary constitutional duty of the Executive Branch?',
          options: [
            'Enforce and administer the laws passed by Congress',
            'Write and pass federal statutory legislative codes',
            'Interpret the constitutional validity of statutes',
            'Ratify international trade treaties independently',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Article II Section 3 directs the President to "take Care that the Laws be faithfully executed".',
          sourceCitation: 'U.S. Constitution Article II §3',
          bloomLevel: 'remember',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'In clinical practice, what legal standard must be satisfied before performing an invasive procedure on a competent adult patient?',
          options: [
            'Informed consent explaining risks, benefits, and options',
            'Implied emergency necessity assumption protocol approval',
            'Family surrogate authorization affidavit signature form',
            'Hospital administrative ethics committee clearance review',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: Informed consent requires adequate disclosure of diagnosis, risks, benefits, and reasonable alternatives.',
          sourceCitation: 'American Medical Association Code of Ethics 2.1.1',
          bloomLevel: 'apply',
          difficulty: 'intermediate',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'What constitutional amendment guarantees citizens the right against unreasonable searches and seizures without a warrant?',
          options: [
            'The Fourth Amendment to the United States Constitution',
            'The Fifth Amendment to the United States Constitution',
            'The Sixth Amendment to the United States Constitution',
            'The Eighth Amendment to the United States Constitution',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: The Fourth Amendment protects persons, houses, papers, and effects against unreasonable searches.',
          sourceCitation: 'U.S. Constitution Amendment IV',
          bloomLevel: 'remember',
          difficulty: 'beginner',
        ),
        const GeneratedAssessmentItem(
          prompt:
              'Under Florida emergency medical statutes, what document directs healthcare providers regarding life-prolonging procedures?',
          options: [
            'Living will declaration for end-of-life medical care',
            'Durable financial power of attorney appointment form',
            'Hospital admission financial agreement contract form',
            'General medical power of attorney without directions',
          ],
          correctIndex: 0,
          explanation:
              'Option A is correct: F.S. §765.302 provides statutory authority for living wills directing the withholding or withdrawal of life-prolonging procedures.',
          sourceCitation: 'Florida Statutes §765.302',
          bloomLevel: 'understand',
          difficulty: 'intermediate',
        ),
      ];

      expect(goldenItems.length, greaterThanOrEqualTo(20));

      final batchReport = evaluator.evaluateBatch(goldenItems);

      // 1. Strict Answer Leakage Requirement: Exactly 0 leaks across all items
      expect(batchReport.answerLeaksCount, equals(0),
          reason: 'Automated eval suite requires 0 answer leaks');
      expect(batchReport.leakRate, equals(0.0));

      // 2. Strict Citation Presence Requirement: >= 90%
      expect(batchReport.citationRate, greaterThanOrEqualTo(0.90),
          reason: 'Automated eval suite requires >= 90% citation presence');
      expect(batchReport.citationsPresentCount, equals(goldenItems.length));

      // 3. Strict Distractor Length Balance Requirement: within 1.5x
      expect(batchReport.lengthBalanceRate, greaterThanOrEqualTo(0.90),
          reason: 'Distractor lengths must be balanced within 1.5x of the key');

      // 4. Batch Quality & Pass Rate:
      expect(batchReport.passRate, greaterThanOrEqualTo(0.95),
          reason: 'Overall batch pass rate must meet psychometric standards');
      expect(batchReport.averageScore, greaterThanOrEqualTo(85.0),
          reason: 'Average score must be high quality');
    });
  });
}

