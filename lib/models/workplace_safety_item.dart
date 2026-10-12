/// Models for Workplace Safety and OSHA Hazard Awareness.
///
/// DISCLAIMER:
/// LearningApp provides hazard awareness education aligned with public-domain
/// OSHA standards. Official OSHA 10-Hour and 30-Hour cards are issued ONLY by
/// OSHA-authorized trainers through an OSHA Training Institute Education Center.
/// LearningApp does not issue OSHA cards or claim to be an authorized OSHA 10 course.
library;

/// Category of workplace safety item.
enum WorkplaceSafetyCategory {
  /// Personal Protective Equipment.
  ppe,

  /// Globally Harmonized System (GHS) chemical hazard pictograms.
  ghsPictogram,

  /// Lockout/Tagout (LOTO) energy control.
  lockoutTagout,

  /// Fall protection and ladder safety.
  fallProtection,
}

/// A workplace safety instructional item.
class WorkplaceSafetyItem {
  final String id;
  final String title;
  final WorkplaceSafetyCategory category;
  final String iconEmoji;
  final String description;
  final String spokenExplanation;
  final String hazardWarning;

  const WorkplaceSafetyItem({
    required this.id,
    required this.title,
    required this.category,
    required this.iconEmoji,
    required this.description,
    required this.spokenExplanation,
    required this.hazardWarning,
  });
}

/// Official statutory card disclaimer for OSHA awareness training.
const String oshaCardDisclaimer =
    'Educational hazard awareness tool only. Official OSHA 10-Hour and 30-Hour '
    'cards are issued solely by OSHA-authorized trainers through an OSHA '
    'Training Institute Education Center. This app does not issue cards.';

/// Curated workplace safety catalog aligned with OSHA standards.
const List<WorkplaceSafetyItem> officialWorkplaceSafetyCatalog = [
  // --- PPE (Personal Protective Equipment) ---
  WorkplaceSafetyItem(
    id: 'ppe_hard_hat',
    title: 'Hard Hat',
    category: WorkplaceSafetyCategory.ppe,
    iconEmoji: '🪖',
    description: 'Protects head from falling objects, bumps, and electrical hazards.',
    spokenExplanation:
        'Hard hat: Wear this at all times in construction areas to protect your head from falling tools and materials.',
    hazardWarning: 'Never work under overhead loads or cranes without a hard hat.',
  ),
  WorkplaceSafetyItem(
    id: 'ppe_safety_glasses',
    title: 'Safety Glasses',
    category: WorkplaceSafetyCategory.ppe,
    iconEmoji: '🥽',
    description: 'Protects eyes from flying dust, debris, sparks, and chemical splashes.',
    spokenExplanation:
        'Safety glasses: Wear impact-rated eye protection when cutting, grinding, or handling chemicals.',
    hazardWarning: 'Regular eyeglasses are NOT safety glasses.',
  ),
  WorkplaceSafetyItem(
    id: 'ppe_hearing',
    title: 'Hearing Protection (Earplugs / Muffs)',
    category: WorkplaceSafetyCategory.ppe,
    iconEmoji: '🎧',
    description: 'Protects ears from loud machinery and hearing loss over 85 decibels.',
    spokenExplanation:
        'Hearing protection: Wear earplugs or ear muffs whenever working around loud equipment.',
    hazardWarning: 'Hearing damage is permanent and cannot be reversed.',
  ),
  WorkplaceSafetyItem(
    id: 'ppe_steel_toe_boots',
    title: 'Steel-Toe Work Boots',
    category: WorkplaceSafetyCategory.ppe,
    iconEmoji: '🥾',
    description: 'Protects feet from falling heavy objects, punctures, and slips.',
    spokenExplanation:
        'Steel-toe boots: Crush-resistant boots protect your feet from heavy dropped items and punctures.',
    hazardWarning: 'Never wear sneakers or open-toed shoes on a worksite.',
  ),
  WorkplaceSafetyItem(
    id: 'ppe_high_vis',
    title: 'High-Visibility Vest',
    category: WorkplaceSafetyCategory.ppe,
    iconEmoji: '🦺',
    description: 'Ensures forklift operators and vehicle drivers can see you clearly.',
    spokenExplanation:
        'High-vis vest: Fluorescent yellow or orange vest keeps you visible to equipment operators.',
    hazardWarning: 'Stay out of forklift blind spots even when wearing high-vis.',
  ),

  // --- GHS Chemical Pictograms ---
  WorkplaceSafetyItem(
    id: 'ghs_flammable',
    title: 'GHS: Flammable (Fire)',
    category: WorkplaceSafetyCategory.ghsPictogram,
    iconEmoji: '🔥',
    description: 'Catches fire easily. Keep away from sparks, flames, and heat.',
    spokenExplanation:
        'Flame symbol: This chemical is flammable. Never smoke or create sparks nearby.',
    hazardWarning: 'Store in approved fire-rated yellow safety cabinets.',
  ),
  WorkplaceSafetyItem(
    id: 'ghs_toxic',
    title: 'GHS: Toxic / Poison (Skull & Crossbones)',
    category: WorkplaceSafetyCategory.ghsPictogram,
    iconEmoji: '☠️',
    description: 'Can cause severe illness or death if swallowed, breathed, or absorbed.',
    spokenExplanation:
        'Skull and crossbones: Severe acute toxicity or poison. Handle only with protective gear in well-ventilated areas.',
    hazardWarning: 'Seek immediate emergency medical help if exposed.',
  ),
  WorkplaceSafetyItem(
    id: 'ghs_corrosive',
    title: 'GHS: Corrosive (Acid Burns)',
    category: WorkplaceSafetyCategory.ghsPictogram,
    iconEmoji: '🧪',
    description: 'Burns skin, destroys eye tissue, and eats through metals.',
    spokenExplanation:
        'Corrosive symbol: Strong acids or caustic chemicals that will burn skin and eyes on contact.',
    hazardWarning: 'Always wear chemical gloves and face shields. Know where the eyewash station is.',
  ),
  WorkplaceSafetyItem(
    id: 'ghs_explosive',
    title: 'GHS: Explosive (Bomb Bursting)',
    category: WorkplaceSafetyCategory.ghsPictogram,
    iconEmoji: '💥',
    description: 'Can explode from shock, friction, fire, or heat.',
    spokenExplanation:
        'Exploding bomb symbol: Unstable chemical that can violently explode. Do not drop or heat.',
    hazardWarning: 'Keep away from all ignition sources.',
  ),
  WorkplaceSafetyItem(
    id: 'ghs_health_hazard',
    title: 'GHS: Health Hazard (Human Silhouette)',
    category: WorkplaceSafetyCategory.ghsPictogram,
    iconEmoji: '🫁',
    description: 'Causes chronic organ damage, respiratory illness, or cancer over time.',
    spokenExplanation:
        'Health hazard symbol: Long-term health damage to lungs, nerves, or organs from repeated exposure.',
    hazardWarning: 'Always use proper respirator cartridges, not simple dust masks.',
  ),

  // --- Lockout / Tagout (LOTO) ---
  WorkplaceSafetyItem(
    id: 'loto_lock',
    title: 'Lockout / Tagout (LOTO)',
    category: WorkplaceSafetyCategory.lockoutTagout,
    iconEmoji: '🔒',
    description: 'Red padlock and warning tag installed before servicing machinery.',
    spokenExplanation:
        'Lockout Tagout: Never remove someone else\'s red safety lock. It means someone is inside working on that machine.',
    hazardWarning: 'Removing a LOTO lock can fatally crush or electrocute a coworker.',
  ),

  // --- Fall Protection & Ladder Safety ---
  WorkplaceSafetyItem(
    id: 'fall_ladder_rule',
    title: 'Ladder 4-to-1 Rule & 3 Points of Contact',
    category: WorkplaceSafetyCategory.fallProtection,
    iconEmoji: '🪜',
    description: 'Place ladder base 1 foot out for every 4 feet of height. Keep 3 points of contact.',
    spokenExplanation:
        'Ladder safety: For every 4 feet up, place the base 1 foot out. Always keep two hands and one foot, or two feet and one hand on the ladder.',
    hazardWarning: 'Falls are the leading cause of construction deaths.',
  ),
];
