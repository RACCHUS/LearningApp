import 'package:flutter/material.dart';

enum SurvivalCategory {
  safety,
  facility,
  medical,
}

/// A high-stakes environmental survival word that non-readers must recognize
/// immediately for physical safety, dignity, and independence.
class SurvivalWordItem {
  final String word;
  final String meaning;
  final String symbol;
  final SurvivalCategory category;
  final Color backgroundColor;
  final Color textColor;
  final String audioPrompt;

  const SurvivalWordItem({
    required this.word,
    required this.meaning,
    required this.symbol,
    required this.category,
    required this.backgroundColor,
    required this.textColor,
    required this.audioPrompt,
  });
}

/// Core environmental survival words
final List<SurvivalWordItem> survivalWordsCatalog = [
  const SurvivalWordItem(
    word: 'EXIT',
    meaning: 'The door out of the building.',
    symbol: '🚪',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFF1B5E20), // Dark green
    textColor: Colors.white,
    audioPrompt: 'EXIT. This means the door to go out. Look for the glowing green or red sign above the door.',
  ),
  const SurvivalWordItem(
    word: 'STOP',
    meaning: 'Do not go forward.',
    symbol: '🛑',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFFB71C1C), // Deep red
    textColor: Colors.white,
    audioPrompt: 'STOP. Red octagon. Do not go forward. Halt completely.',
  ),
  const SurvivalWordItem(
    word: 'DANGER',
    meaning: 'Severe hazard. Keep away.',
    symbol: '⚠️',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFFB71C1C), // Red
    textColor: Colors.white,
    audioPrompt: 'DANGER. Red and white sign. High hazard. Stay away to stay safe.',
  ),
  const SurvivalWordItem(
    word: 'CAUTION',
    meaning: 'Be careful. Look out.',
    symbol: '⚠️',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFFF57F17), // Yellow/Amber
    textColor: Colors.black,
    audioPrompt: 'CAUTION. Yellow warning sign. Watch your step or be alert.',
  ),
  const SurvivalWordItem(
    word: 'RESTROOM',
    meaning: 'The bathroom or toilet.',
    symbol: '🚻',
    category: SurvivalCategory.facility,
    backgroundColor: Color(0xFF0D47A1), // Deep blue
    textColor: Colors.white,
    audioPrompt: 'RESTROOM. This is the bathroom or toilet in public buildings.',
  ),
  const SurvivalWordItem(
    word: 'MEN',
    meaning: 'Restroom for men.',
    symbol: '🚹',
    category: SurvivalCategory.facility,
    backgroundColor: Color(0xFF1565C0), // Blue
    textColor: Colors.white,
    audioPrompt: 'MEN. Restroom for men.',
  ),
  const SurvivalWordItem(
    word: 'WOMEN',
    meaning: 'Restroom for women.',
    symbol: '🚺',
    category: SurvivalCategory.facility,
    backgroundColor: Color(0xFFAD1457), // Berry / Magenta
    textColor: Colors.white,
    audioPrompt: 'WOMEN. Restroom for women.',
  ),
  const SurvivalWordItem(
    word: 'PHARMACY',
    meaning: 'Where you pick up medicine.',
    symbol: '💊',
    category: SurvivalCategory.medical,
    backgroundColor: Color(0xFF00695C), // Teal
    textColor: Colors.white,
    audioPrompt: 'PHARMACY. The drug store counter where you get your doctor prescriptions.',
  ),
  const SurvivalWordItem(
    word: 'HOSPITAL',
    meaning: 'Emergency medical care.',
    symbol: '🏥',
    category: SurvivalCategory.medical,
    backgroundColor: Color(0xFF0D47A1), // Blue H
    textColor: Colors.white,
    audioPrompt: 'HOSPITAL. Blue sign with a white H. Go here for serious medical emergencies.',
  ),
  const SurvivalWordItem(
    word: 'POISON',
    meaning: 'Harmful chemical. Never drink or touch.',
    symbol: '☠️',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFF212121), // Black
    textColor: Colors.white,
    audioPrompt: 'POISON. Skull and crossbones. Very dangerous chemical. Never swallow or touch.',
  ),
  const SurvivalWordItem(
    word: 'EMERGENCY',
    meaning: 'Immediate danger. Call 911.',
    symbol: '🚨',
    category: SurvivalCategory.safety,
    backgroundColor: Color(0xFFC62828), // Bright Red
    textColor: Colors.white,
    audioPrompt: 'EMERGENCY. Flashing siren. Urgent help needed. Call 9-1-1.',
  ),
];
