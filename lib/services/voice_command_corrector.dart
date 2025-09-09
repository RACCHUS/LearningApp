import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:string_similarity/string_similarity.dart';

/// Represents a voice command correction suggestion
class CorrectionSuggestion {
  final String originalInput;
  final String suggestedCommand;
  final double confidence;
  final String correctionMethod;

  const CorrectionSuggestion({
    required this.originalInput,
    required this.suggestedCommand,
    required this.confidence,
    required this.correctionMethod,
  });

  @override
  String toString() {
    return 'CorrectionSuggestion(original: "$originalInput", suggested: "$suggestedCommand", confidence: ${(confidence * 100).toStringAsFixed(1)}%, method: $correctionMethod)';
  }
}

/// Service for correcting voice command recognition errors using phonetic and fuzzy matching
class VoiceCommandCorrector {
  static final VoiceCommandCorrector _instance = VoiceCommandCorrector._internal();
  factory VoiceCommandCorrector() => _instance;
  VoiceCommandCorrector._internal();

  Fuzzy<String>? _fuzzySearcher;
  bool _isInitialized = false;

  // Known valid commands that the system understands
  static const List<String> knownCommands = [
    // Navigation commands
    'home',
    'go home',
    'go back',
    'settings',
    'profile',
    'help',
    'sign in',
    'sign out',
    
    // Lesson search commands
    'find lesson',
    'search lesson',
    'show lesson',
    'open lesson',
    'find',
    'search',
    'show',
    'open',
    'start lesson',
    'begin lesson',
    'my lessons',
    'recent lessons',
    'lesson library',
    'all lessons',
    
    // Lesson control commands
    'next',
    'previous',
    'pause',
    'resume',
    'volume up',
    'volume down',
    'faster',
    'slower',
    'repeat',
    'skip',
    'end lesson',
    'show progress',
  ];

  // Common speech recognition errors (manual patterns for highest accuracy)
  static const Map<String, String> commonSpeechErrors = {
    'fine': 'find',
    'strat': 'start',
    'sine': 'sign',
    'setting': 'settings',
    'less': 'lesson',
    'les': 'lesson',
    'prof': 'profile',
    'sett': 'settings',
    'gome': 'go home',
    'foam': 'home',
    'ome': 'home',
    'sine in': 'sign in',  // Added specific phrase pattern
    'syne': 'sign',
    'syn': 'sign',
  };

  /// Initialize the voice command corrector
  void initialize() {
    if (_isInitialized) return;

    // Create fuzzy searcher with our known commands
    _fuzzySearcher = Fuzzy<String>(
      knownCommands,
      options: FuzzyOptions(
        threshold: 0.4,  // Allow fairly loose matches
        isCaseSensitive: false,
        shouldSort: true,
        shouldNormalize: true,
        minMatchCharLength: 2,
        keys: [
          WeightedKey<String>(
            name: 'command',
            getter: (cmd) => cmd,
            weight: 1.0,
          ),
        ],
      ),
    );

    _isInitialized = true;
    if (kDebugMode) {
      print('🔧 VoiceCommandCorrector initialized with ${knownCommands.length} known commands');
    }
  }

  /// Analyze a voice input and suggest corrections if needed
  CorrectionSuggestion? analyzeCommand(String input, double originalConfidence) {
    if (!_isInitialized) {
      initialize();
    }

    if (kDebugMode) {
      print('🔧 Analyzing voice input: "$input" (confidence: ${(originalConfidence * 100).toStringAsFixed(1)}%)');
    }

    final normalizedInput = input.toLowerCase().trim();
    
    // Step 1: Check for exact matches (high confidence, no correction needed)
    if (_isExactMatch(normalizedInput)) {
      if (kDebugMode) {
        print('🔧 Exact match found, no correction needed');
      }
      return null; // No correction needed
    }

    // Step 2: Apply common speech error corrections
    final errorCorrected = _applyCommonErrorCorrections(normalizedInput);
    if (errorCorrected != normalizedInput) {
      if (_isValidCommand(errorCorrected)) {
        return CorrectionSuggestion(
          originalInput: input,
          suggestedCommand: errorCorrected,
          confidence: 0.95, // High confidence for known error patterns
          correctionMethod: 'common_errors',
        );
      }
    }

    // Step 3: Try context enhancement (add missing words like "lesson")
    final contextEnhanced = _enhanceWithContext(errorCorrected);
    if (contextEnhanced != errorCorrected && _isValidCommand(contextEnhanced)) {
      return CorrectionSuggestion(
        originalInput: input,
        suggestedCommand: contextEnhanced,
        confidence: 0.85,
        correctionMethod: 'context_enhancement',
      );
    }

    // Step 4: Fuzzy matching for similar commands
    final fuzzyMatch = _findFuzzyMatch(normalizedInput);
    if (fuzzyMatch != null) {
      return CorrectionSuggestion(
        originalInput: input,
        suggestedCommand: fuzzyMatch.item,
        confidence: fuzzyMatch.score > 0.7 ? 0.8 : 0.7,
        correctionMethod: 'fuzzy_matching',
      );
    }

    // Step 5: Phonetic similarity for sound-alike words
    final phoneticMatch = _findPhoneticMatch(normalizedInput);
    if (phoneticMatch != null) {
      return CorrectionSuggestion(
        originalInput: input,
        suggestedCommand: phoneticMatch,
        confidence: 0.75,
        correctionMethod: 'phonetic_similarity',
      );
    }

    if (kDebugMode) {
      print('🔧 No correction suggestions found for: "$input"');
    }
    return null;
  }

  /// Check if the input exactly matches a known command
  bool _isExactMatch(String input) {
    return knownCommands.contains(input) || _isValidCommand(input);
  }

  /// Check if a command is valid (either exact match or valid lesson command pattern)
  bool _isValidCommand(String command) {
    // Check exact matches first
    if (knownCommands.contains(command)) {
      return true;
    }

    // Check for valid lesson command patterns
    final lessonPatterns = [
      RegExp(r'^(find|search|show|open)\s+lesson\s+\w+.*$'),
      RegExp(r'^(start|begin|launch|play)\s+lesson\s+\w+.*$'),
      RegExp(r'^(find|search|show|open)\s+\w+.*$'), // Implicit lesson commands
    ];

    return lessonPatterns.any((pattern) => pattern.hasMatch(command));
  }

  /// Apply common speech recognition error corrections
  String _applyCommonErrorCorrections(String input) {
    String corrected = input;
    
    // Apply word-level corrections
    for (final entry in commonSpeechErrors.entries) {
      final errorWord = entry.key;
      final correctWord = entry.value;
      
      // Replace whole words only
      corrected = corrected.replaceAll(RegExp(r'\b' + RegExp.escape(errorWord) + r'\b'), correctWord);
    }
    
    return corrected;
  }

  /// Enhance commands with missing context (like adding "lesson")
  String _enhanceWithContext(String input) {
    // Pattern: "find/search/show/open [word]" -> "find/search/show/open lesson [word]"
    final findPattern = RegExp(r'^(find|search|show|open)\s+(?!lesson\s)(\w+.*)$');
    final findMatch = findPattern.firstMatch(input);
    if (findMatch != null) {
      final action = findMatch.group(1)!;
      final target = findMatch.group(2)!;
      return '$action lesson $target';
    }

    // Pattern: "start/begin [word]" -> "start/begin lesson [word]"
    final startPattern = RegExp(r'^(start|begin|launch|play)\s+(?!lesson\s)(\w+.*)$');
    final startMatch = startPattern.firstMatch(input);
    if (startMatch != null) {
      final action = startMatch.group(1)!;
      final target = startMatch.group(2)!;
      return '$action lesson $target';
    }

    return input;
  }

  /// Find fuzzy matches using the Fuzzy library
  dynamic _findFuzzyMatch(String input) {
    if (_fuzzySearcher == null) return null;

    final results = _fuzzySearcher!.search(input);
    if (results.isNotEmpty && results.first.score > 0.4) {
      return results.first;
    }
    
    return null;
  }

  /// Find phonetic matches for sound-alike commands
  String? _findPhoneticMatch(String input) {
    double bestSimilarity = 0.0;
    String? bestMatch;

    for (final command in knownCommands) {
      // Use string similarity for phonetic-like matching
      final similarity = StringSimilarity.compareTwoStrings(input, command);
      
      if (similarity > 0.6 && similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = command;
      }
    }

    return bestMatch;
  }
}
