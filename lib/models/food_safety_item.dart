/// Models for Food Safety based on the public-domain FDA Food Code (2022).
///
/// NOTE ON TRADEMARKS:
/// "ServSafe" is a registered trademark of the National Restaurant Association.
/// This module is built strictly on open public-domain FDA standards and is
/// independent of any proprietary commercial credentials.
library;

/// Category of food safety concept.
enum FoodSafetyCategory {
  /// Temperature control and danger zones.
  temperatureControl,

  /// Prevention of cross-contamination.
  crossContamination,

  /// The Big 9 food allergens recognized by FDA.
  allergens,

  /// Handwashing and personal hygiene.
  handwashing,
}

/// A food safety concept or guideline.
class FoodSafetyItem {
  final String id;
  final String title;
  final FoodSafetyCategory category;
  final String iconEmoji;
  final String ruleSummary;
  final String spokenExplanation;
  final String criticalStandard;

  const FoodSafetyItem({
    required this.id,
    required this.title,
    required this.category,
    required this.iconEmoji,
    required this.ruleSummary,
    required this.spokenExplanation,
    required this.criticalStandard,
  });
}

/// Six steps of proper food handler handwashing.
class HandwashingStep {
  final int stepNumber;
  final String actionTitle;
  final String iconEmoji;
  final String instructions;
  final int durationSeconds;

  const HandwashingStep({
    required this.stepNumber,
    required this.actionTitle,
    required this.iconEmoji,
    required this.instructions,
    this.durationSeconds = 0,
  });
}

/// Official FDA Food Code standards catalog.
const List<FoodSafetyItem> officialFoodSafetyCatalog = [
  // --- Temperature Control ---
  FoodSafetyItem(
    id: 'temp_danger_zone',
    title: 'Temperature Danger Zone (41°F – 135°F)',
    category: FoodSafetyCategory.temperatureControl,
    iconEmoji: '🌡️',
    ruleSummary:
        'Bacteria multiply rapidly between 41°F and 135°F. Keep cold foods at or below 41°F and hot foods at or above 135°F.',
    spokenExplanation:
        'The Temperature Danger Zone is between 41 and 135 degrees Fahrenheit. Cold food must stay cold, and hot food must stay hot.',
    criticalStandard: 'Throw away perishable food left in this zone for over 2 hours (or 1 hour over 90°F).',
  ),
  FoodSafetyItem(
    id: 'temp_poultry',
    title: 'Poultry Minimum Cooking Temp: 165°F',
    category: FoodSafetyCategory.temperatureControl,
    iconEmoji: '🍗',
    ruleSummary:
        'Chicken, turkey, and stuffed meats must reach 165°F (74°C) for at least 15 seconds to kill Salmonella.',
    spokenExplanation:
        'Cook all chicken and turkey to an internal temperature of 165 degrees Fahrenheit. Check with a probe thermometer in the thickest part.',
    criticalStandard: '165°F for 15 seconds.',
  ),
  FoodSafetyItem(
    id: 'temp_ground_meat',
    title: 'Ground Meat Minimum Cooking Temp: 155°F',
    category: FoodSafetyCategory.temperatureControl,
    iconEmoji: '🍔',
    ruleSummary:
        'Ground beef, pork, and sausage must reach 155°F (68°C) because grinding spreads bacteria throughout the meat.',
    spokenExplanation:
        'Cook hamburger patties and ground beef to 155 degrees Fahrenheit.',
    criticalStandard: '155°F for 17 seconds.',
  ),
  FoodSafetyItem(
    id: 'temp_whole_meat',
    title: 'Whole Cuts of Meat & Fish: 145°F',
    category: FoodSafetyCategory.temperatureControl,
    iconEmoji: '🥩',
    ruleSummary:
        'Whole steaks, chops, roasts, and seafood must reach 145°F (63°C) with a 3-minute rest time.',
    spokenExplanation:
        'Cook beef steaks, pork chops, and fish fillets to at least 145 degrees Fahrenheit.',
    criticalStandard: '145°F for 15 seconds plus 3-minute rest.',
  ),

  // --- Cross-Contamination & Cutting Boards ---
  FoodSafetyItem(
    id: 'cross_cutting_boards',
    title: 'Color-Coded Cutting Boards',
    category: FoodSafetyCategory.crossContamination,
    iconEmoji: '🔪',
    ruleSummary:
        'Red = Raw Beef & Pork. Yellow = Raw Poultry. Green = Fresh Produce. Blue = Cooked Foods. Never mix raw meat juices with salad!',
    spokenExplanation:
        'Use separate cutting boards. Red for raw red meat, Yellow for chicken, and Green for fruits and vegetables.',
    criticalStandard: 'Wash, rinse, and sanitize boards between tasks.',
  ),

  // --- The Big 9 Allergens ---
  FoodSafetyItem(
    id: 'allergens_big_9',
    title: 'The Big 9 Food Allergens',
    category: FoodSafetyCategory.allergens,
    iconEmoji: '🥜',
    ruleSummary:
        'Milk, Eggs, Peanuts, Tree Nuts, Wheat, Soy, Fish, Crustacean Shellfish, and Sesame. Even microscopic trace amounts can cause fatal anaphylaxis.',
    spokenExplanation:
        'The big nine allergens are Milk, Eggs, Peanuts, Tree Nuts, Wheat, Soy, Fish, Shellfish, and Sesame. Never use the same utensils or oil.',
    criticalStandard: 'Clean and sanitize all surfaces before preparing allergen-free orders.',
  ),
];

/// The 6-step FDA handwashing sequence with 20-second active scrub time.
const List<HandwashingStep> officialHandwashingSteps = [
  HandwashingStep(
    stepNumber: 1,
    actionTitle: 'Wet Hands',
    iconEmoji: '🚰',
    instructions: 'Wet hands and exposed arms with warm, clean running water (at least 100°F).',
  ),
  HandwashingStep(
    stepNumber: 2,
    actionTitle: 'Apply Soap',
    iconEmoji: '🧼',
    instructions: 'Apply enough liquid soap to build a generous lather.',
  ),
  HandwashingStep(
    stepNumber: 3,
    actionTitle: 'Scrub for 20 Seconds',
    iconEmoji: '⏱️',
    instructions:
        'Vigorously scrub palms, backs of hands, between fingers, and clean under fingernails for at least 20 seconds.',
    durationSeconds: 20,
  ),
  HandwashingStep(
    stepNumber: 4,
    actionTitle: 'Rinse Thoroughly',
    iconEmoji: '🚿',
    instructions: 'Rinse all soap away under warm, clean running water.',
  ),
  HandwashingStep(
    stepNumber: 5,
    actionTitle: 'Dry with Paper Towel',
    iconEmoji: '🧻',
    instructions: 'Dry hands thoroughly using a clean single-use paper towel or air dryer.',
  ),
  HandwashingStep(
    stepNumber: 6,
    actionTitle: 'Turn Off Faucet',
    iconEmoji: '✋',
    instructions: 'Use the paper towel to turn off the water faucet to avoid re-contaminating clean hands.',
  ),
];
