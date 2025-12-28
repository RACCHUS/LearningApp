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
  jumpToPage,
}

enum ControlCommand {
  play,
  pause,
  stop,
  repeat,
  faster,
  slower,
  skip,
  endLesson,
  volumeUp,
  volumeDown,
  showProgress,
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
    'skip': ControlCommand.skip,
    'skip this': ControlCommand.skip,
    'next item': ControlCommand.skip,
    'end lesson': ControlCommand.endLesson,
    'stop lesson': ControlCommand.endLesson,
    'finish lesson': ControlCommand.endLesson,
    'exit lesson': ControlCommand.endLesson,
    'volume up': ControlCommand.volumeUp,
    'louder': ControlCommand.volumeUp,
    'increase volume': ControlCommand.volumeUp,
    'volume down': ControlCommand.volumeDown,
    'quieter': ControlCommand.volumeDown,
    'decrease volume': ControlCommand.volumeDown,
    'show progress': ControlCommand.showProgress,
    'my progress': ControlCommand.showProgress,
    'progress report': ControlCommand.showProgress,
    'where am i': ControlCommand.showProgress,
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

  /// Helper method to check if a phrase matches using word boundaries
  /// Prevents false positives like "no" matching in "know" or "start" in "restart"
  static bool _matchesWithWordBoundary(String text, String phrase) {
    // Exact match
    if (text == phrase) return true;
    
    // Word boundary match using regex
    final pattern = RegExp(
      r'(^|\s)' + RegExp.escape(phrase) + r'($|\s|[.,!?])',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  /// Sort entries by key length (longest first) to prioritize specific matches
  static List<MapEntry<String, T>> _sortByLengthDescending<T>(Map<String, T> map) {
    final entries = map.entries.toList();
    entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    return entries;
  }

  static VoiceCommand? parseCommand(String text, {double confidence = 1.0}) {
    final normalizedText = text.toLowerCase().trim();
    
    // Reject very low confidence input
    if (confidence < 0.4) {
      return null;
    }
    
    // Check for "go to page [number]" command
    final pagePattern = RegExp(r'go to page (\d+)|page (\d+)|jump to page (\d+)');
    final pageMatch = pagePattern.firstMatch(normalizedText);
    if (pageMatch != null) {
      final pageNumber = int.tryParse(pageMatch.group(1) ?? pageMatch.group(2) ?? pageMatch.group(3) ?? '');
      if (pageNumber != null) {
        return VoiceCommand(
          type: VoiceCommandType.navigation,
          phrase: 'go to page $pageNumber',
          value: NavigationCommand.jumpToPage,
          alternatives: [pageNumber.toString()], // Store page number in alternatives
          confidence: confidence,
        );
      }
    }
    
    // Check navigation commands (sorted by length - longest first)
    for (final entry in _sortByLengthDescending(navigationCommands)) {
      if (_matchesWithWordBoundary(normalizedText, entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.navigation,
          phrase: entry.key,
          value: entry.value,
          confidence: confidence,
        );
      }
    }

    // Check control commands (sorted by length - longest first)
    for (final entry in _sortByLengthDescending(controlCommands)) {
      if (_matchesWithWordBoundary(normalizedText, entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.control,
          phrase: entry.key,
          value: entry.value,
          confidence: confidence,
        );
      }
    }

    // Check mode commands (sorted by length - longest first)
    for (final entry in _sortByLengthDescending(modeCommands)) {
      if (_matchesWithWordBoundary(normalizedText, entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.mode,
          phrase: entry.key,
          value: entry.value,
          confidence: confidence,
        );
      }
    }

    // Check MCQ answers (require higher confidence for answers)
    if (confidence >= 0.6) {
      for (final entry in _sortByLengthDescending(mcqAnswers)) {
        // For MCQ answers, check exact match or word boundary
        if (normalizedText == entry.key || 
            _matchesWithWordBoundary(normalizedText, entry.key)) {
          return VoiceCommand(
            type: VoiceCommandType.answer,
            phrase: entry.key,
            value: entry.value,
            confidence: confidence,
          );
        }
      }
    }

    // Check True/False answers (require higher confidence and use word boundaries)
    if (confidence >= 0.6) {
      for (final entry in _sortByLengthDescending(trueFalseAnswers)) {
        if (_matchesWithWordBoundary(normalizedText, entry.key)) {
          return VoiceCommand(
            type: VoiceCommandType.answer,
            phrase: entry.key,
            value: entry.value,
            confidence: confidence,
          );
        }
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
