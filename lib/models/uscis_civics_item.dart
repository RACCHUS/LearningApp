/// Models for the USCIS Naturalization & Citizenship Test simulator.
///
/// Complies with the 2025 Revised Civics Test standard (effective for N-400
/// applications filed on or after October 20, 2025: 128 questions pool,
/// 20 questions asked, 12 correct to pass, officer stops testing at 12 correct
/// or 9 incorrect), the legacy 2008 test standard (100 questions, 10 asked,
/// 6 correct to pass), and the 65/20 special exemption subset.
///
/// Also provides Form N-400 oral interview questions and legal disclaimers.
library;

/// Mode for USCIS Civics Test practice.
enum UscisTestMode {
  /// 2025 Revised Civics Test: 128-question pool, 20 asked, 12 to pass.
  test2025,

  /// 2008 Legacy Civics Test: 100-question pool, 10 asked, 6 to pass.
  test2008,

  /// 65/20 Special Exemption: Age 65+ with 20+ years permanent residency.
  /// 20 designated asterisk questions, 10 asked, 6 to pass.
  exemption65_20,

  /// Oral Form N-400 interview questions asked during the naturalization interview.
  n400Interview,
}

/// Official question in the USCIS civics test.
class UscisCivicsItem {
  final String id;
  final int number;
  final String question;
  final String spokenQuestion;
  final List<String> acceptableAnswers;
  final List<String> options;
  final int correctOptionIndex;
  final String category;
  final bool is2025Test;
  final bool is2008Test;
  final bool is65_20Exemption;
  final String explanation;

  const UscisCivicsItem({
    required this.id,
    required this.number,
    required this.question,
    required this.spokenQuestion,
    required this.acceptableAnswers,
    required this.options,
    required this.correctOptionIndex,
    required this.category,
    this.is2025Test = true,
    this.is2008Test = true,
    this.is65_20Exemption = false,
    required this.explanation,
  });
}

/// An oral question from Form N-400 asked during the interview.
class OralN400Question {
  final String id;
  final String section;
  final String officerQuestion;
  final String spokenPrompt;
  final String guidanceAudio;
  final String sampleAnswer;

  const OralN400Question({
    required this.id,
    required this.section,
    required this.officerQuestion,
    required this.spokenPrompt,
    required this.guidanceAudio,
    required this.sampleAnswer,
  });
}

/// Statutory disclaimer for USCIS materials.
const String uscisLegalDisclaimer =
    'Educational practice tool only. LearningApp does NOT provide legal advice. '
    'For immigration legal assistance, please consult a DOJ-recognized organization '
    '(EOIR) or a licensed immigration attorney.';

/// Curated official USCIS questions spanning American Democracy,
/// System of Government, Rights & Responsibilities, History, and 65/20 questions.
const List<UscisCivicsItem> officialUscisCivicsCatalog = [
  // 1. Supreme Law
  UscisCivicsItem(
    id: 'uscis_001',
    number: 1,
    question: 'What is the supreme law of the land?',
    spokenQuestion: 'What is the supreme law of the land?',
    acceptableAnswers: ['the Constitution'],
    options: [
      'The Constitution',
      'The Declaration of Independence',
      'The Bill of Rights',
      'The Articles of Confederation',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The Constitution is the highest law in the United States. All laws must follow it.',
  ),

  // 2. What does the Constitution do?
  UscisCivicsItem(
    id: 'uscis_002',
    number: 2,
    question: 'What does the Constitution do?',
    spokenQuestion: 'What does the Constitution do?',
    acceptableAnswers: [
      'sets up the government',
      'defines the government',
      'protects basic rights of Americans',
    ],
    options: [
      'Sets up and defines the government',
      'Declares independence from Great Britain',
      'Collects federal income taxes',
      'Chooses the President every year',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'The Constitution establishes our branches of government and protects our fundamental rights.',
  ),

  // 3. Self-government ("We the People")
  UscisCivicsItem(
    id: 'uscis_003',
    number: 3,
    question:
        'The idea of self-government is in the first three words of the Constitution. What are these words?',
    spokenQuestion:
        'The idea of self-government is in the first three words of the Constitution. What are these words?',
    acceptableAnswers: ['We the People'],
    options: [
      'We the People',
      'In God We Trust',
      'Four score and seven',
      'Congress shall make no law',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'The words "We the People" mean that the government gets its power from the citizens.',
  ),

  // 4. What is an amendment?
  UscisCivicsItem(
    id: 'uscis_004',
    number: 4,
    question: 'What is an amendment?',
    spokenQuestion: 'What is an amendment?',
    acceptableAnswers: [
      'a change to the Constitution',
      'an addition to the Constitution',
    ],
    options: [
      'A change or addition to the Constitution',
      'The introduction to a law',
      'A speech given by the President',
      'A decision by the Supreme Court',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'An amendment is an official change or addition made to the US Constitution.',
  ),

  // 5. Bill of Rights
  UscisCivicsItem(
    id: 'uscis_005',
    number: 5,
    question: 'What do we call the first ten amendments to the Constitution?',
    spokenQuestion:
        'What do we call the first ten amendments to the Constitution?',
    acceptableAnswers: ['the Bill of Rights'],
    options: [
      'The Bill of Rights',
      'The Declaration of Independence',
      'The Federalist Papers',
      'The Gettysburg Address',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The Bill of Rights guarantees basic freedoms such as speech, religion, and the press.',
  ),

  // 6. First Amendment rights
  UscisCivicsItem(
    id: 'uscis_006',
    number: 6,
    question: 'What is one right or freedom from the First Amendment?',
    spokenQuestion:
        'What is one right or freedom from the First Amendment?',
    acceptableAnswers: [
      'speech',
      'religion',
      'assembly',
      'press',
      'petition the government',
    ],
    options: [
      'Freedom of Speech',
      'Right to bear arms',
      'Trial by jury',
      'Right to vote at age 18',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The First Amendment protects speech, religion, assembly, press, and petitioning the government.',
  ),

  // 7. Declaration of Independence
  UscisCivicsItem(
    id: 'uscis_008',
    number: 8,
    question: 'What did the Declaration of Independence do?',
    spokenQuestion: 'What did the Declaration of Independence do?',
    acceptableAnswers: [
      'announced our independence from Great Britain',
      'declared our independence from Great Britain',
      'said that the United States is free from Great Britain',
    ],
    options: [
      'Declared our independence from Great Britain',
      'Created the United States Constitution',
      'Freed the slaves in the South',
      'Ended World War II',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'The Declaration of Independence announced that the 13 American colonies were free from British rule.',
  ),

  // 8. Economic system
  UscisCivicsItem(
    id: 'uscis_011',
    number: 11,
    question: 'What is the economic system in the United States?',
    spokenQuestion: 'What is the economic system in the United States?',
    acceptableAnswers: [
      'capitalist economy',
      'market economy',
    ],
    options: [
      'Capitalist or market economy',
      'Socialist economy',
      'Command economy',
      'Traditional economy',
    ],
    correctOptionIndex: 0,
    category: 'Principles of American Democracy',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The US has a capitalist or free-market economy where private businesses compete.',
  ),

  // 9. Three branches of government
  UscisCivicsItem(
    id: 'uscis_013',
    number: 13,
    question: 'Name one branch or part of the government.',
    spokenQuestion: 'Name one branch or part of the government.',
    acceptableAnswers: [
      'Congress',
      'legislative',
      'President',
      'executive',
      'the courts',
      'judicial',
    ],
    options: [
      'Congress (Legislative)',
      'The United Nations',
      'The Military',
      'The Federal Reserve',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The three branches of US government are Legislative (Congress), Executive (President), and Judicial (Courts).',
  ),

  // 10. Separation of powers
  UscisCivicsItem(
    id: 'uscis_014',
    number: 14,
    question: 'What stops one branch of government from becoming too powerful?',
    spokenQuestion:
        'What stops one branch of government from becoming too powerful?',
    acceptableAnswers: [
      'checks and balances',
      'separation of powers',
    ],
    options: [
      'Checks and balances',
      'The police',
      'The Prime Minister',
      'State governors',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'Checks and balances and separation of powers prevent any single branch from dominating the government.',
  ),

  // 11. Who is in charge of executive branch?
  UscisCivicsItem(
    id: 'uscis_015',
    number: 15,
    question: 'Who is in charge of the executive branch?',
    spokenQuestion: 'Who is in charge of the executive branch?',
    acceptableAnswers: ['the President'],
    options: [
      'The President',
      'The Speaker of the House',
      'The Chief Justice',
      'The Secretary of State',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The President of the United States leads the executive branch.',
  ),

  // 12. Who makes federal laws?
  UscisCivicsItem(
    id: 'uscis_016',
    number: 16,
    question: 'Who makes federal laws?',
    spokenQuestion: 'Who makes federal laws?',
    acceptableAnswers: [
      'Congress',
      'Senate and House of Representatives',
      'U.S. or national legislature',
    ],
    options: [
      'Congress (Senate and House)',
      'The Supreme Court',
      'The President alone',
      'The Governors of all 50 states',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'Congress makes federal laws for the whole nation.',
  ),

  // 13. Two parts of US Congress
  UscisCivicsItem(
    id: 'uscis_017',
    number: 17,
    question: 'What are the two parts of the U.S. Congress?',
    spokenQuestion: 'What are the two parts of the U.S. Congress?',
    acceptableAnswers: ['the Senate and House of Representatives'],
    options: [
      'The Senate and House of Representatives',
      'The President and Cabinet',
      'The Supreme Court and Federal Courts',
      'The Democrats and Republicans',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'Congress has two houses: the Senate (100 senators) and the House of Representatives (435 voting members).',
  ),

  // 14. How many US Senators?
  UscisCivicsItem(
    id: 'uscis_018',
    number: 18,
    question: 'How many U.S. Senators are there?',
    spokenQuestion: 'How many U.S. Senators are there?',
    acceptableAnswers: ['one hundred', '100'],
    options: [
      '100 (2 per state)',
      '435',
      '50',
      '9',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'There are 100 US Senators, exactly 2 from each of the 50 states.',
  ),

  // 15. We elect a US Senator for how many years?
  UscisCivicsItem(
    id: 'uscis_019',
    number: 19,
    question: 'We elect a U.S. Senator for how many years?',
    spokenQuestion: 'We elect a U.S. Senator for how many years?',
    acceptableAnswers: ['six', '6'],
    options: [
      '6 years',
      '2 years',
      '4 years',
      '8 years',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'US Senators are elected for 6-year terms.',
  ),

  // 16. We elect a President for how many years?
  UscisCivicsItem(
    id: 'uscis_026',
    number: 26,
    question: 'We elect a President for how many years?',
    spokenQuestion: 'We elect a President for how many years?',
    acceptableAnswers: ['four', '4'],
    options: [
      '4 years',
      '2 years',
      '6 years',
      'For life',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The President of the United States is elected for a 4-year term.',
  ),

  // 17. In what month do we vote for President?
  UscisCivicsItem(
    id: 'uscis_027',
    number: 27,
    question: 'In what month do we vote for President?',
    spokenQuestion: 'In what month do we vote for President?',
    acceptableAnswers: ['November'],
    options: [
      'November',
      'January',
      'July',
      'October',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'Federal presidential elections take place on the Tuesday after the first Monday in November.',
  ),

  // 18. Who is the Commander in Chief of the military?
  UscisCivicsItem(
    id: 'uscis_032',
    number: 32,
    question: 'Who is the Commander in Chief of the military?',
    spokenQuestion: 'Who is the Commander in Chief of the military?',
    acceptableAnswers: ['the President'],
    options: [
      'The President',
      'The Secretary of Defense',
      'The Chairman of the Joint Chiefs',
      'The Vice President',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'The President is the civilian Commander in Chief of the armed forces.',
  ),

  // 19. Highest court in the US
  UscisCivicsItem(
    id: 'uscis_038',
    number: 38,
    question: 'What is the highest court in the United States?',
    spokenQuestion: 'What is the highest court in the United States?',
    acceptableAnswers: ['the Supreme Court'],
    options: [
      'The Supreme Court',
      'The Court of Appeals',
      'The District Court',
      'The International Court of Justice',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The Supreme Court is the highest court in the nation.',
  ),

  // 20. How many justices on the Supreme Court?
  UscisCivicsItem(
    id: 'uscis_039',
    number: 39,
    question: 'How many justices are on the Supreme Court?',
    spokenQuestion: 'How many justices are on the Supreme Court?',
    acceptableAnswers: ['nine', '9'],
    options: [
      '9 justices',
      '7 justices',
      '12 justices',
      '10 justices',
    ],
    correctOptionIndex: 0,
    category: 'System of Government',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'Under current federal law, there are 9 Supreme Court justices.',
  ),

  // 21. Capital of the United States
  UscisCivicsItem(
    id: 'uscis_094',
    number: 94,
    question: 'What is the capital of the United States?',
    spokenQuestion: 'What is the capital of the United States?',
    acceptableAnswers: ['Washington, D.C.'],
    options: [
      'Washington, D.C.',
      'New York City',
      'Philadelphia',
      'Los Angeles',
    ],
    correctOptionIndex: 0,
    category: 'Integrated Civics',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'Washington, District of Columbia, is the national capital of the United States.',
  ),

  // 22. Statue of Liberty location
  UscisCivicsItem(
    id: 'uscis_095',
    number: 95,
    question: 'Where is the Statue of Liberty?',
    spokenQuestion: 'Where is the Statue of Liberty?',
    acceptableAnswers: [
      'New York Harbor',
      'Liberty Island',
    ],
    options: [
      'New York Harbor (Liberty Island)',
      'Boston Harbor',
      'San Francisco Bay',
      'Washington, D.C.',
    ],
    correctOptionIndex: 0,
    category: 'Integrated Civics',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'The Statue of Liberty is in New York Harbor on Liberty Island.',
  ),

  // 23. Independence Day
  UscisCivicsItem(
    id: 'uscis_099',
    number: 99,
    question: 'When do we celebrate Independence Day?',
    spokenQuestion: 'When do we celebrate Independence Day?',
    acceptableAnswers: ['July 4', 'July fourth'],
    options: [
      'July 4th',
      'June 19th',
      'December 25th',
      'January 1st',
    ],
    correctOptionIndex: 0,
    category: 'Integrated Civics',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'Independence Day is celebrated every July 4th to commemorate the 1776 Declaration.',
  ),

  // 24. 2025 Test Specific Addition: Why did colonists fight the British?
  UscisCivicsItem(
    id: 'uscis_061',
    number: 61,
    question: 'Why did the colonists fight the British?',
    spokenQuestion: 'Why did the colonists fight the British?',
    acceptableAnswers: [
      'because of high taxes (taxation without representation)',
      'because the British army stayed in their houses (boarding, quartering)',
      'because they did not have self-government',
    ],
    options: [
      'High taxes without representation',
      'Disagreements about religion',
      'To conquer Canadian territory',
      'Because of the Civil War',
    ],
    correctOptionIndex: 0,
    category: 'American History',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: false,
    explanation:
        'The colonists protested taxation without representation and unwanted quartering of British soldiers.',
  ),

  // 25. Who wrote the Declaration of Independence?
  UscisCivicsItem(
    id: 'uscis_062',
    number: 62,
    question: 'Who wrote the Declaration of Independence?',
    spokenQuestion: 'Who wrote the Declaration of Independence?',
    acceptableAnswers: ['Thomas Jefferson'],
    options: [
      'Thomas Jefferson',
      'George Washington',
      'Abraham Lincoln',
      'Benjamin Franklin',
    ],
    correctOptionIndex: 0,
    category: 'American History',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'Thomas Jefferson was the principal author of the Declaration of Independence.',
  ),

  // 26. Who was the first President?
  UscisCivicsItem(
    id: 'uscis_070',
    number: 70,
    question: 'Who is the "Father of Our Country" and first President?',
    spokenQuestion:
        'Who is the Father of Our Country and the first President of the United States?',
    acceptableAnswers: ['George Washington'],
    options: [
      'George Washington',
      'John Adams',
      'Alexander Hamilton',
      'Thomas Jefferson',
    ],
    correctOptionIndex: 0,
    category: 'American History',
    is2025Test: true,
    is2008Test: true,
    is65_20Exemption: true,
    explanation:
        'George Washington was the commander of the Continental Army and the first US President.',
  ),
];

/// Sample oral Form N-400 interview questions asked by USCIS officers.
const List<OralN400Question> officialN400InterviewCatalog = [
  OralN400Question(
    id: 'n400_001',
    section: 'Oaths & Biographical',
    officerQuestion:
        'Do you promise to tell the truth, the whole truth, and nothing but the truth?',
    spokenPrompt:
        'Listen carefully: The officer will administer the oath at the start of your interview.',
    guidanceAudio:
        'Stand, raise your right hand, and say clearly: "Yes, I do."',
    sampleAnswer: 'Yes, I do.',
  ),
  OralN400Question(
    id: 'n400_002',
    section: 'Oaths & Biographical',
    officerQuestion: 'What is your current legal name and your date of birth?',
    spokenPrompt:
        'The officer will check your identification documents against your application.',
    guidanceAudio:
        'Speak your first and last name clearly, followed by your month, day, and year of birth.',
    sampleAnswer: 'My name is [Your Name] and I was born on [Your Birthday].',
  ),
  OralN400Question(
    id: 'n400_003',
    section: 'Travel & Residence',
    officerQuestion:
        'Have you taken any trips outside the United States that lasted 6 months or longer?',
    spokenPrompt:
        'Continuous residence requires maintaining your primary home in the US.',
    guidanceAudio:
        'Answer truthfully. If all your trips were short vacations, say "No, officer."',
    sampleAnswer: 'No, officer.',
  ),
  OralN400Question(
    id: 'n400_004',
    section: 'Moral Character',
    officerQuestion:
        'Have you ever claimed to be a U.S. citizen in writing or any other way?',
    spokenPrompt:
        'Claiming to be a citizen before naturalization is a serious legal violation.',
    guidanceAudio:
        'If you have never falsely registered to vote or claimed citizenship, answer: "No, officer."',
    sampleAnswer: 'No, officer.',
  ),
  OralN400Question(
    id: 'n400_005',
    section: 'Moral Character',
    officerQuestion:
        'Have you ever failed to file your federal, state, or local taxes?',
    spokenPrompt:
        'Good moral character requires paying all required taxes or having an approved IRS payment plan.',
    guidanceAudio:
        'If you filed every year, answer: "No, officer. I always file my taxes."',
    sampleAnswer: 'No, officer. I always file my taxes.',
  ),
  OralN400Question(
    id: 'n400_006',
    section: 'Allegiance & Constitution',
    officerQuestion:
        'Do you support the Constitution and form of government of the United States?',
    spokenPrompt:
        'Naturalization requires loyalty to the democratic Constitution of the United States.',
    guidanceAudio:
        'Answer firmly and proudly: "Yes, I do."',
    sampleAnswer: 'Yes, I do.',
  ),
  OralN400Question(
    id: 'n400_007',
    section: 'Allegiance & Constitution',
    officerQuestion:
        'Are you willing to take the full Oath of Allegiance to the United States?',
    spokenPrompt:
        'The final step to citizenship is taking the Oath of Allegiance at your ceremony.',
    guidanceAudio:
        'Answer clearly: "Yes, I am."',
    sampleAnswer: 'Yes, I am.',
  ),
];
