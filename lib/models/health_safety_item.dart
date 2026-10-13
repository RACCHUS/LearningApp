/// Models for Healthcare Literacy, Prescription (Rx) Label recognition,
/// and Emergency First Aid.
///
/// MEDICAL ADVICE DISCLAIMER:
/// LearningApp is an educational tool for label recognition and emergency basic
/// safety. It does NOT provide medical advice. Never alter physician dosages.
/// Always consult your doctor or pharmacist.
library;

/// Category of health or safety concept.
enum HealthSafetyCategory {
  /// Prescription label parts and warning stickers.
  prescriptionLabel,

  /// Auxiliary warning sticker on medication.
  warningSticker,

  /// Emergency first aid protocols (burns, bleeding, 911).
  firstAid,
}

/// A component of a prescription medicine bottle label.
class RxLabelComponent {
  final String id;
  final String fieldName;
  final String iconEmoji;
  final String sampleValue;
  final String purposeExplanation;
  final String spokenGuidance;

  const RxLabelComponent({
    required this.id,
    required this.fieldName,
    required this.iconEmoji,
    required this.sampleValue,
    required this.purposeExplanation,
    required this.spokenGuidance,
  });
}

/// An emergency first aid guideline or procedure.
class FirstAidGuideline {
  final String id;
  final String title;
  final String iconEmoji;
  final String criticalRule;
  final String dangerousMythWarning;
  final String spokenProtocol;
  final List<String> actionSteps;

  const FirstAidGuideline({
    required this.id,
    required this.title,
    required this.iconEmoji,
    required this.criticalRule,
    required this.dangerousMythWarning,
    required this.spokenProtocol,
    required this.actionSteps,
  });
}

/// Medical disclaimer constant.
const String medicalAdviceDisclaimer =
    'Educational practice tool only. LearningApp does NOT provide medical advice. '
    'Never alter prescription dosages without consulting your doctor. '
    'Whenever unsure, always take your medicine bottle to your pharmacist.';

/// The 5 key components of a prescription label.
const List<RxLabelComponent> officialRxLabelComponents = [
  RxLabelComponent(
    id: 'rx_patient_name',
    fieldName: 'Patient Name',
    iconEmoji: '👤',
    sampleValue: 'JOHN DOE',
    purposeExplanation:
        'Verify your first and last name. Never take medicine with someone else\'s name on the bottle.',
    spokenGuidance:
        'Always check the name on the bottle. If it is not your name, do not take it. Taking another person\'s prescription can be fatal.',
  ),
  RxLabelComponent(
    id: 'rx_medication_name',
    fieldName: 'Medication Name & Strength',
    iconEmoji: '💊',
    sampleValue: 'Amoxicillin 500mg',
    purposeExplanation:
        'The name of the drug and dosage strength. Keep this bottle when seeing doctors.',
    spokenGuidance:
        'Medication name. This tells you which medicine is in the bottle. Show this bottle to your doctor or EMT in an emergency.',
  ),
  RxLabelComponent(
    id: 'rx_pharmacy_phone',
    fieldName: 'Pharmacy Phone Number',
    iconEmoji: '📞',
    sampleValue: '(555) 123-4567',
    purposeExplanation:
        'Call this phone number whenever you need a refill or have questions about how to take your medicine.',
    spokenGuidance:
        'Pharmacy phone number. Call this number anytime you are confused about your medicine. Pharmacists are trained to help you for free.',
  ),
  RxLabelComponent(
    id: 'rx_warning_stickers',
    fieldName: 'Warning Stickers (Auxiliary Labels)',
    iconEmoji: '⚠️',
    sampleValue: 'Take with food • No alcohol • May cause drowsiness',
    purposeExplanation:
        'Colored stickers on the side giving critical food and safety warnings.',
    spokenGuidance:
        'Warning stickers. Look for stickers: a fork and knife means take with food. A red slash over alcohol means do not drink beer or wine.',
  ),
  RxLabelComponent(
    id: 'rx_refills_expiry',
    fieldName: 'Refills & Expiration Date',
    iconEmoji: '📅',
    sampleValue: 'Refills: 2 before 12/31/2027',
    purposeExplanation:
        'Tells how many times you can get more medicine and when the pill expires.',
    spokenGuidance:
        'Refills remaining. When this says zero, your doctor must authorize a new prescription before you run out.',
  ),
];

/// Curated emergency first aid guidelines.
const List<FirstAidGuideline> officialFirstAidGuidelines = [
  // 1. Burn Protocol (Cool Water, Never Ice)
  FirstAidGuideline(
    id: 'first_aid_burns',
    title: 'Burn First Aid: Cool Running Water (Never Ice)',
    iconEmoji: '🚰',
    criticalRule:
        'Hold the burn under cool, gentle running tap water for 10 to 20 minutes immediately.',
    dangerousMythWarning:
        'NEVER apply ice, butter, grease, or toothpaste to burns! Ice destroys skin tissue and causes hypothermia. Butter traps heat and causes infection.',
    spokenProtocol:
        'Burn emergency: Cool the burn immediately with cool, gentle running tap water for 10 to 20 minutes. Never put ice, butter, or grease on a burn.',
    actionSteps: [
      '1. Remove the heat source immediately.',
      '2. Cool with clean, cool running water for 10 to 20 minutes.',
      '3. Remove tight jewelry or rings before swelling begins.',
      '4. Cover loosely with clean plastic wrap or sterile gauze.',
      '5. Never pop or peel blisters.',
    ],
  ),

  // 2. Severe Bleeding
  FirstAidGuideline(
    id: 'first_aid_bleeding',
    title: 'Severe Bleeding: Firm Direct Pressure',
    iconEmoji: '🩹',
    criticalRule:
        'Press firmly directly on the wound with a clean cloth or gauze. Do not remove the cloth if it bleeds through; add another on top.',
    dangerousMythWarning:
        'Never remove blood-soaked cloths, as this tears away the forming clot. Just keep adding more cloth and pressing firmly.',
    spokenProtocol:
        'Severe bleeding: Apply continuous firm direct pressure with a clean cloth. If bleeding through, add another cloth on top and call 911.',
    actionSteps: [
      '1. Place a clean cloth or gauze directly over the cut.',
      '2. Press firmly with both hands.',
      '3. Maintain continuous pressure without lifting to peek.',
      '4. If blood soaks through, add another layer on top.',
      '5. Call 911 if bleeding does not stop after 5 minutes.',
    ],
  ),

  // 3. Calling 911 Spoken Practice
  FirstAidGuideline(
    id: 'first_aid_911',
    title: 'Calling 911: The Three Vital Questions',
    iconEmoji: '🚨',
    criticalRule:
        'Stay on the phone. Answer: 1. Where are you? 2. Who is hurt? 3. Are they awake and breathing?',
    dangerousMythWarning:
        'Never hang up first. The 911 operator will tell you exactly what to do and dispatch the ambulance while speaking to you.',
    spokenProtocol:
        'Calling 911: Stay calm and do not hang up. Tell the operator your exact address, what happened, and if the person is awake and breathing.',
    actionSteps: [
      '1. Dial 9-1-1 and put on speakerphone.',
      '2. State your location: "I am at [Street Address / Room / Landmark]."',
      '3. State the emergency: "A person fell and is bleeding."',
      '4. State their condition: "They are awake and breathing."',
      '5. Follow all operator instructions until paramedics arrive.',
    ],
  ),
];
