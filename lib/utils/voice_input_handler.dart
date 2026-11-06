import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/utils/voice_command_router.dart';

class VoiceInputHandler {
  static const Map<String, int> _standaloneSlotMap = {
    // Standalone letters
    'a': 0,
    'b': 1,
    'c': 2,
    'd': 3,
    // Unambiguous standalone letter homophones
    'ay': 0,
    'aye': 0,
    'eh': 0,
    'bee': 1,
    'be': 1,
    'sea': 2,
    'dee': 3,
    // Standalone digits
    '1': 0,
    '2': 1,
    '3': 2,
    '4': 3,
    // Standalone number words
    'one': 0,
    'two': 1,
    'three': 2,
    'four': 3,
    // Standalone ordinals
    'first': 0,
    '1st': 0,
    'second': 1,
    '2nd': 1,
    'third': 2,
    '3rd': 2,
    'fourth': 3,
    '4th': 3,
  };

  static const Map<String, int> _tokenSlotMap = {
    // Letters & homophones (valid when preceded by an explicit choice keyword)
    'a': 0,
    'ay': 0,
    'aye': 0,
    'hey': 0,
    'eh': 0,
    'b': 1,
    'be': 1,
    'bee': 1,
    'bea': 1,
    'c': 2,
    'see': 2,
    'sea': 2,
    'si': 2,
    'd': 3,
    'dee': 3,
    'de': 3,
    // Digits & number words
    '1': 0,
    'one': 0,
    '2': 1,
    'two': 1,
    '3': 2,
    'three': 2,
    '4': 3,
    'four': 3,
    // Ordinals
    'first': 0,
    '1st': 0,
    'second': 1,
    '2nd': 1,
    'third': 2,
    '3rd': 2,
    'fourth': 3,
    '4th': 3,
  };

  static const Map<String, int> _ordinalPhraseSlotMap = {
    'the first one': 0,
    'the second one': 1,
    'the third one': 2,
    'the fourth one': 3,
    'first one': 0,
    'second one': 1,
    'third one': 2,
    'fourth one': 3,
    'the first option': 0,
    'the second option': 1,
    'the third option': 2,
    'the fourth option': 3,
    'first option': 0,
    'second option': 1,
    'third option': 2,
    'fourth option': 3,
    'first choice': 0,
    'second choice': 1,
    'third choice': 2,
    'fourth choice': 3,
  };

  /// Maps a spoken choice (e.g. "Option A", "B", "1", "number two", "the third one")
  /// to the canonical authored option index using [presentationOrder] when provided.
  ///
  /// Only accepts explicit choice commands, recognized letter homophones,
  /// valid ordinals, valid numeric commands (1–4 / one–four), or standalone
  /// letters. Never infers an answer from arbitrary characters in a sentence.
  static int? mapSpokenChoiceToIndex(
    String voiceInput, {
    required int optionCount,
    List<int>? presentationOrder,
  }) {
    if (optionCount <= 0) return null;

    final cleaned = voiceInput
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;

    // 1. Check context-aware MCQ command parser first (rejects navigation commands
    // such as "next", "previous", "pause", "repeat").
    final command = VoiceCommandRouter.parseContextAwareCommand(
      voiceInput,
      context: 'mcq',
    );
    if (command != null && command.type != VoiceCommandType.answer) {
      return null;
    }

    int? slotIndex;
    if (command?.type == VoiceCommandType.answer && command!.value is String) {
      final answerLetter = (command.value as String).toUpperCase().trim();
      if (answerLetter.length == 1) {
        final code = answerLetter.codeUnitAt(0) - 65; // A=0, B=1, C=2, D=3
        if (code >= 0 && code < 4) {
          slotIndex = code;
        }
      }
    }

    // 2. Exact standalone match (single letter, digit 1-4, number word, ordinal,
    // or unambiguous standalone homophone).
    slotIndex ??= _standaloneSlotMap[cleaned];

    // 3. Explicit ordinal phrases (e.g. "the first one", "second option").
    if (slotIndex == null) {
      for (final entry in _ordinalPhraseSlotMap.entries) {
        if (cleaned == entry.key ||
            cleaned.startsWith('${entry.key} ') ||
            cleaned.endsWith(' ${entry.key}')) {
          slotIndex = entry.value;
          break;
        }
      }
    }

    // 4. Explicit choice prefix + target token (e.g. "option a", "number two",
    // "choice 3", "select b", "answer is d", "option number 1").
    if (slotIndex == null) {
      final prefixMatch = RegExp(
        r'^(?:please\s+|i\s+think\s+|my\s+)?'
        r'(?:option|choice|choose|select|answer|pick|number|letter)'
        r'(?:\s+(?:is|number|letter))?\s+'
        r'([a-z0-9]+)'
        r'(?:\s+(?:please|thanks|thank\s+you))?$',
      ).firstMatch(cleaned);
      if (prefixMatch != null) {
        final token = prefixMatch.group(1)!;
        slotIndex = _tokenSlotMap[token];
      }
    }

    if (slotIndex != null && slotIndex >= 0 && slotIndex < optionCount) {
      if (presentationOrder != null && slotIndex < presentationOrder.length) {
        return presentationOrder[slotIndex];
      }
      return slotIndex;
    }

    return null;
  }

  /// Handles voice input for MCQ questions
  /// Returns the selected answer index (0-3) or null if no valid answer found
  static int? handleMcqVoiceInput(
    String voiceInput,
    QuestionContent content, {
    List<int>? presentationOrder,
  }) {
    return mapSpokenChoiceToIndex(
      voiceInput,
      optionCount: content.options.length,
      presentationOrder: presentationOrder,
    );
  }

  /// Handles voice input for True/False questions
  /// Returns true, false, or null if no valid answer found
  static bool? handleTrueFalseVoiceInput(String voiceInput) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);

    if (command?.type == VoiceCommandType.answer && command!.value is bool) {
      return command.value as bool;
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();

      if (input.contains('true') ||
          input.contains('yes') ||
          input.contains('correct')) {
        return true;
      } else if (input.contains('false') ||
          input.contains('no') ||
          input.contains('incorrect')) {
        return false;
      }
    }

    return null;
  }

  /// Handles voice input for short answer questions
  /// Returns the voice input as text
  static String handleShortAnswerVoiceInput(String voiceInput) {
    return voiceInput.trim();
  }
}
