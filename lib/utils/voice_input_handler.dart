import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/utils/voice_command_router.dart';

class VoiceInputHandler {
  /// Maps a spoken choice (e.g. "Option A", "B", "the third one") to the
  /// canonical authored option index using [presentationOrder] when provided.
  static int? mapSpokenChoiceToIndex(
    String voiceInput, {
    required int optionCount,
    List<int>? presentationOrder,
  }) {
    if (optionCount <= 0) return null;

    final command = VoiceCommandRouter.parseContextAwareCommand(
          voiceInput,
          context: 'mcq',
        ) ??
        VoiceCommand.parseCommand(voiceInput);

    int? slotIndex;
    if (command?.type == VoiceCommandType.answer && command!.value is String) {
      final answerLetter = (command.value as String).toUpperCase().trim();
      if (answerLetter.length == 1) {
        final code = answerLetter.codeUnitAt(0) - 65; // A=0, B=1, C=2, D=3
        if (code >= 0 && code < optionCount) {
          slotIndex = code;
        }
      }
    }

    if (slotIndex == null) {
      final input = voiceInput.toLowerCase().trim();
      if (input.isEmpty) return null;

      if (input.contains('first')) {
        slotIndex = 0;
      } else if (input.contains('second')) {
        slotIndex = 1;
      } else if (input.contains('third')) {
        slotIndex = 2;
      } else if (input.contains('fourth')) {
        slotIndex = 3;
      } else {
        final prefixedMatch = RegExp(
          r'\b(?:option|choice|choose|select|answer|pick)\s+([a-d])\b',
        ).firstMatch(input);
        if (prefixedMatch != null) {
          slotIndex = prefixedMatch.group(1)!.codeUnitAt(0) - 97;
        } else {
          final standaloneMatch = RegExp(r'\b([a-d])\b').firstMatch(input);
          if (standaloneMatch != null) {
            slotIndex = standaloneMatch.group(1)!.codeUnitAt(0) - 97;
          } else if (input.contains('a')) {
            slotIndex = 0;
          } else if (input.contains('b')) {
            slotIndex = 1;
          } else if (input.contains('c')) {
            slotIndex = 2;
          } else if (input.contains('d')) {
            slotIndex = 3;
          }
        }
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
