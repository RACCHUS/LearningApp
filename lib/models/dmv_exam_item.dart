/// Models for the Florida FLHSMV Driver's License exam & road safety module.
///
/// Based on the official Florida Driver License Handbook (FLHSMV) and
/// Federal Highway Administration (FHWA) Manual on Uniform Traffic Control Devices (MUTCD).
///
/// Features:
/// - MUTCD Road Sign Shape & Color Grammar (Public Domain standards)
/// - Right-of-Way & Intersection Simulator
/// - Florida Class E Knowledge Exam engine (50 questions, 80% / 40 correct passing score)
library;

/// Category of driver exam question.
enum DmvQuestionType {
  /// Road signs, signals, and pavement markings.
  roadSign,

  /// Rules of the road, speed limits, and traffic laws.
  roadRule,

  /// Right-of-way and intersection dynamics.
  rightOfWay,
}

/// An entry in the MUTCD Road Sign Shape & Color Grammar.
class RoadSignGrammarItem {
  final String id;
  final String shape;
  final String color;
  final String meaning;
  final String visualIcon;
  final String audioDescription;
  final String exampleSign;

  const RoadSignGrammarItem({
    required this.id,
    required this.shape,
    required this.color,
    required this.meaning,
    required this.visualIcon,
    required this.audioDescription,
    required this.exampleSign,
  });
}

/// An official Florida Class E driver license question.
class DmvQuestionItem {
  final String id;
  final int number;
  final DmvQuestionType type;
  final String question;
  final String spokenQuestion;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String spokenExplanation;
  final String visualEmoji;

  const DmvQuestionItem({
    required this.id,
    required this.number,
    required this.type,
    required this.question,
    required this.spokenQuestion,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.spokenExplanation,
    required this.visualEmoji,
  });
}

/// The 9 standardized MUTCD sign shape and color rules.
const List<RoadSignGrammarItem> mutcdSignGrammarCatalog = [
  RoadSignGrammarItem(
    id: 'sign_octagon',
    shape: 'Octagon (8 Sides)',
    color: 'Red with White Letters',
    meaning: 'STOP',
    visualIcon: '🛑',
    audioDescription:
        'An eight-sided red octagon always means complete stop. Come to a full stop before the crosswalk or line.',
    exampleSign: 'STOP Sign',
  ),
  RoadSignGrammarItem(
    id: 'sign_triangle',
    shape: 'Downward Triangle (3 Sides)',
    color: 'Red and White',
    meaning: 'YIELD',
    visualIcon: '🔻',
    audioDescription:
        'A downward pointing triangle always means yield. Slow down and let other vehicles and pedestrians go first.',
    exampleSign: 'YIELD Sign',
  ),
  RoadSignGrammarItem(
    id: 'sign_diamond',
    shape: 'Diamond',
    color: 'Yellow with Black Symbols',
    meaning: 'WARNING & ROAD HAZARDS',
    visualIcon: '🔶',
    audioDescription:
        'A yellow diamond warns you of upcoming road hazards, sharp turns, slippery conditions, or lane merges.',
    exampleSign: 'Curves Ahead, Merge, Slippery Road',
  ),
  RoadSignGrammarItem(
    id: 'sign_vert_rectangle',
    shape: 'Vertical Rectangle',
    color: 'White with Black or Red Letters',
    meaning: 'REGULATORY LAW',
    visualIcon: '📋',
    audioDescription:
        'A vertical white rectangle tells you traffic laws you must obey, such as speed limits, one-way streets, or no turns.',
    exampleSign: 'Speed Limit 45, One Way, Do Not Enter',
  ),
  RoadSignGrammarItem(
    id: 'sign_square_blue',
    shape: 'Square or Horizontal Rectangle',
    color: 'Blue with White Symbols',
    meaning: 'MOTORIST SERVICES',
    visualIcon: '🔵',
    audioDescription:
        'A blue square sign shows traveler services nearby: gas, food, lodging, rest areas, or hospitals.',
    exampleSign: 'Hospital, Gas Station, Rest Area',
  ),
  RoadSignGrammarItem(
    id: 'sign_horiz_green',
    shape: 'Horizontal Rectangle',
    color: 'Green with White Letters',
    meaning: 'GUIDE & DISTANCE',
    visualIcon: '🟩',
    audioDescription:
        'A green rectangular sign gives directions, highway exit numbers, and distances to upcoming cities.',
    exampleSign: 'Interstate Exits, City Mileage',
  ),
  RoadSignGrammarItem(
    id: 'sign_orange_diamond',
    shape: 'Diamond',
    color: 'Orange with Black Symbols',
    meaning: 'WORK ZONE & CONSTRUCTION',
    visualIcon: '🚧',
    audioDescription:
        'An orange diamond means road construction or maintenance ahead. Slow down and watch for road workers.',
    exampleSign: 'Road Work Ahead, Detour, Flagger',
  ),
  RoadSignGrammarItem(
    id: 'sign_pentagon',
    shape: 'Pentagon (5 Sides - School House)',
    color: 'Fluorescent Yellow-Green',
    meaning: 'SCHOOL ZONE & CROSSING',
    visualIcon: '🚸',
    audioDescription:
        'A five-sided pentagon shaped like a little school house marks a school zone or children crossing.',
    exampleSign: 'School Crossing, Pedestrian Zone',
  ),
  RoadSignGrammarItem(
    id: 'sign_round',
    shape: 'Round Circle',
    color: 'Yellow with Black Cross & RR',
    meaning: 'RAILROAD ADVANCE WARNING',
    visualIcon: '🚂',
    audioDescription:
        'A round yellow sign with an X and the letters R-R warns you that railroad tracks are ahead. Listen for trains.',
    exampleSign: 'Railroad Crossing Advance Warning',
  ),
];

/// Curated official Florida Class E knowledge exam questions.
const List<DmvQuestionItem> floridaDmvQuestionsCatalog = [
  // 1. Move Over Law
  DmvQuestionItem(
    id: 'fl_dmv_001',
    number: 1,
    type: DmvQuestionType.roadRule,
    question:
        'Under Florida law, what must you do when approaching an emergency vehicle or tow truck stopped on the two-lane shoulder with flashing lights?',
    spokenQuestion:
        'Under Florida law, what must you do when approaching an emergency vehicle with flashing lights on the shoulder of a two-lane road?',
    options: [
      'Slow down to 20 mph below the speed limit',
      'Honk your horn to warn the officer',
      'Speed up to pass quickly',
      'Come to a complete stop in the driving lane',
    ],
    correctOptionIndex: 0,
    explanation:
        'Florida\'s Move Over Law requires drivers to move over a lane on multi-lane roads, or slow down to 20 mph below the posted speed limit on two-lane roads.',
    spokenExplanation:
        'On a two-lane road, slow down to 20 miles per hour below the speed limit. On a multi-lane highway, vacate the lane closest to the stopped emergency vehicle.',
    visualEmoji: '🚓',
  ),

  // 2. 4-Way Stop Right of Way
  DmvQuestionItem(
    id: 'fl_dmv_002',
    number: 2,
    type: DmvQuestionType.rightOfWay,
    question:
        'At a 4-way stop intersection, two vehicles arrive and stop at the exact same time. Who has the right-of-way?',
    spokenQuestion:
        'At a four-way stop, two cars arrive at the exact same time. Who goes first?',
    options: [
      'The driver on the right goes first',
      'The driver on the left goes first',
      'The larger vehicle goes first',
      'Whoever honks their horn first',
    ],
    correctOptionIndex: 0,
    explanation:
        'When two vehicles arrive at a four-way stop at the same time, the driver on the left must yield to the driver on the right.',
    spokenExplanation:
        'Yield to the vehicle on your right. The car on the right has the right of way.',
    visualEmoji: '🛑',
  ),

  // 3. Flashing Red Light
  DmvQuestionItem(
    id: 'fl_dmv_003',
    number: 3,
    type: DmvQuestionType.roadSign,
    question: 'What does a flashing red traffic light mean?',
    spokenQuestion: 'What does a flashing red traffic light mean?',
    options: [
      'Stop completely, then proceed when safe (like a stop sign)',
      'Slow down and proceed without stopping',
      'The traffic signal is broken; ignore it',
      'Wait for the light to turn solid green',
    ],
    correctOptionIndex: 0,
    explanation:
        'A flashing red light must be treated exactly like a stop sign: come to a complete stop, look in all directions, and proceed only when clear.',
    spokenExplanation:
        'A flashing red light means stop completely, yield to traffic and pedestrians, and proceed when safe.',
    visualEmoji: '🚨',
  ),

  // 4. Flashing Yellow Light
  DmvQuestionItem(
    id: 'fl_dmv_004',
    number: 4,
    type: DmvQuestionType.roadSign,
    question: 'What does a flashing yellow traffic signal mean?',
    spokenQuestion: 'What does a flashing yellow light mean?',
    options: [
      'Slow down and proceed with caution',
      'Stop completely and wait for green',
      'Pedestrians have right-of-way only',
      'Speed up before the light turns red',
    ],
    correctOptionIndex: 0,
    explanation:
        'A flashing yellow light warns drivers of a hazard or intersection: slow down, be alert, and proceed with caution.',
    spokenExplanation:
        'A flashing yellow light means slow down and proceed with caution.',
    visualEmoji: '⚠️',
  ),

  // 5. Solid Yellow Line
  DmvQuestionItem(
    id: 'fl_dmv_005',
    number: 5,
    type: DmvQuestionType.roadRule,
    question:
        'What does a solid yellow line on your side of the road\'s center line mean?',
    spokenQuestion:
        'What does a solid yellow line on your side of the center line mean?',
    options: [
      'Passing is prohibited on your side',
      'Passing is allowed if clear',
      'The speed limit is 25 miles per hour',
      'You are driving on a one-way street',
    ],
    correctOptionIndex: 0,
    explanation:
        'A solid yellow line on your side indicates a no-passing zone. You may not cross it to pass other vehicles.',
    spokenExplanation:
        'A solid yellow line on your side means you cannot pass.',
    visualEmoji: '🟡',
  ),

  // 6. Florida School Zone Speed
  DmvQuestionItem(
    id: 'fl_dmv_006',
    number: 6,
    type: DmvQuestionType.roadRule,
    question:
        'In Florida, what is the maximum speed limit in an active school zone?',
    spokenQuestion:
        'In Florida, what is the maximum speed limit in an active school zone?',
    options: [
      '20 mph',
      '30 mph',
      '15 mph',
      '25 mph',
    ],
    correctOptionIndex: 0,
    explanation:
        'Florida law sets the speed limit in active school zones at 20 mph unless posted otherwise.',
    spokenExplanation:
        'In Florida, the maximum speed in an active school zone is 20 miles per hour.',
    visualEmoji: '🚸',
  ),

  // 7. Roundabout Right of Way
  DmvQuestionItem(
    id: 'fl_dmv_007',
    number: 7,
    type: DmvQuestionType.rightOfWay,
    question: 'When entering a roundabout (traffic circle), who must you yield to?',
    spokenQuestion: 'When entering a roundabout, who must you yield to?',
    options: [
      'Traffic already circulating inside the roundabout and pedestrians',
      'Vehicles entering from the left only',
      'Vehicles behind you',
      'No one; entering vehicles have priority',
    ],
    correctOptionIndex: 0,
    explanation:
        'Drivers entering a roundabout must yield right-of-way to circulating traffic already inside the circle and to pedestrians in crosswalks.',
    spokenExplanation:
        'Always yield to vehicles already inside the circular roadway.',
    visualEmoji: '🔄',
  ),

  // 8. Headlights in Florida Weather
  DmvQuestionItem(
    id: 'fl_dmv_008',
    number: 8,
    type: DmvQuestionType.roadRule,
    question:
        'In Florida, when must your vehicle headlights be turned on?',
    spokenQuestion:
        'In Florida, when must your headlights be turned on?',
    options: [
      'From sunset to sunrise, and whenever it is raining, foggy, or smoky',
      'Only after 9:00 PM at night',
      'Only on interstate highways',
      'During thunder and lightning only',
    ],
    correctOptionIndex: 0,
    explanation:
        'Headlights must be on from sunset to sunrise, and whenever rain, smoke, or fog requires the use of windshield wipers.',
    spokenExplanation:
        'Turn on headlights between sunset and sunrise, and whenever rain or fog requires your windshield wipers.',
    visualEmoji: '💡',
  ),

  // 9. Truck Blind Spots ("No-Zone")
  DmvQuestionItem(
    id: 'fl_dmv_009',
    number: 9,
    type: DmvQuestionType.roadRule,
    question:
        'Large commercial trucks have blind spots called "No-Zones". If you cannot see the truck driver in their side mirror, what does that mean?',
    spokenQuestion:
        'If you cannot see a truck driver in their side mirror, what does that mean?',
    options: [
      'The truck driver cannot see you (you are in their blind spot)',
      'The truck driver is speeding',
      'The truck is about to turn right',
      'You are safely outside their blind spot',
    ],
    correctOptionIndex: 0,
    explanation:
        'If you cannot see the truck driver\'s face in their side view mirror, you are in their blind spot (No-Zone) and they cannot see you.',
    spokenExplanation:
        'If you can\'t see the truck driver in their mirror, they cannot see you.',
    visualEmoji: '🚛',
  ),

  // 10. Florida Seat Belt Law
  DmvQuestionItem(
    id: 'fl_dmv_010',
    number: 10,
    type: DmvQuestionType.roadRule,
    question:
        'Who is required to wear a seat belt in a passenger car in Florida?',
    spokenQuestion:
        'Who must wear a seat belt in Florida?',
    options: [
      'The driver and all front-seat passengers, plus all passengers under age 18',
      'Only the driver',
      'Only children under age 6',
      'Only on highways over 55 mph',
    ],
    correctOptionIndex: 0,
    explanation:
        'In Florida, the driver, all front-seat passengers, and all passengers under 18 years old anywhere in the vehicle must wear seat belts.',
    spokenExplanation:
        'The driver, front seat passengers, and all passengers under 18 must buckle up.',
    visualEmoji: '🔒',
  ),
];
