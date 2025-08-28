enum VoiceCommandType {
  navigation,
  answer,
  control,
  mode,
}

enum NavigationCommand {
  next,
  previous,
  first,
  last,
  back,
}

enum ControlCommand {
  play,
  pause,
  stop,
  repeat,
  faster,
  slower,
}

enum ModeCommand {
  flashcards,
  questions,
  concepts,
  mixed,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String phrase;
  final List<String> alternatives;
  final dynamic value;
  final double confidence;

  const VoiceCommand({
    required this.type,
    required this.phrase,
    this.alternatives = const [],
    this.value,
    this.confidence = 0.0,
  });

  static const Map<String, NavigationCommand> navigationCommands = {
    'next': NavigationCommand.next,
    'forward': NavigationCommand.next,
    'continue': NavigationCommand.next,
    'previous': NavigationCommand.previous,
    'back': NavigationCommand.previous,
    'go back': NavigationCommand.previous,
    'first': NavigationCommand.first,
    'beginning': NavigationCommand.first,
    'start': NavigationCommand.first,
    'last': NavigationCommand.last,
    'end': NavigationCommand.last,
    'finish': NavigationCommand.last,
  };

  static const Map<String, ControlCommand> controlCommands = {
    'play': ControlCommand.play,
    'start': ControlCommand.play,
    'resume': ControlCommand.play,
    'pause': ControlCommand.pause,
    'stop': ControlCommand.stop,
    'halt': ControlCommand.stop,
    'repeat': ControlCommand.repeat,
    'again': ControlCommand.repeat,
    'say again': ControlCommand.repeat,
    'faster': ControlCommand.faster,
    'speed up': ControlCommand.faster,
    'slower': ControlCommand.slower,
    'slow down': ControlCommand.slower,
  };

  static const Map<String, ModeCommand> modeCommands = {
    'flashcards': ModeCommand.flashcards,
    'flash cards': ModeCommand.flashcards,
    'cards': ModeCommand.flashcards,
    'questions': ModeCommand.questions,
    'quiz': ModeCommand.questions,
    'test': ModeCommand.questions,
    'concepts': ModeCommand.concepts,
    'concept': ModeCommand.concepts,
    'theory': ModeCommand.concepts,
    'mixed': ModeCommand.mixed,
    'mixed mode': ModeCommand.mixed,
    'all': ModeCommand.mixed,
  };

  static const Map<String, String> mcqAnswers = {
    'a': 'A',
    'option a': 'A',
    'first': 'A',
    'first option': 'A',
    'b': 'B',
    'option b': 'B',
    'second': 'B',
    'second option': 'B',
    'c': 'C',
    'option c': 'C',
    'third': 'C',
    'third option': 'C',
    'd': 'D',
    'option d': 'D',
    'fourth': 'D',
    'fourth option': 'D',
  };

  static const Map<String, bool> trueFalseAnswers = {
    'true': true,
    'yes': true,
    'correct': true,
    'right': true,
    'false': false,
    'no': false,
    'incorrect': false,
    'wrong': false,
  };

  static VoiceCommand? parseCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    
    // Check navigation commands
    for (final entry in navigationCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.navigation,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check control commands
    for (final entry in controlCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.control,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check mode commands
    for (final entry in modeCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.mode,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check MCQ answers
    for (final entry in mcqAnswers.entries) {
      if (normalizedText == entry.key || normalizedText.endsWith(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check True/False answers
    for (final entry in trueFalseAnswers.entries) {
      if (normalizedText.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'VoiceCommand(type: $type, phrase: $phrase, value: $value, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceCommand &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          phrase == other.phrase &&
          value == other.value;

  @override
  int get hashCode => type.hashCode ^ phrase.hashCode ^ value.hashCode;
}
