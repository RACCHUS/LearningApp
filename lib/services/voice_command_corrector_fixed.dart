import 'package:flutter/foundation.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:string_similarity/string_similarity.dart';

/// Represents a voice command correction suggestion
class CorrectionSuggestion {
  final String originalInput;
  final String suggestedCommand;
  final double confidence;
  final String correctionMethod;
  final Map<String, dynamic> metadata;

  const CorrectionSuggestion({
    required this.originalInput,
    required this.suggestedCommand,
    required this.confidence,
    required this.correctionMethod,
    this.metadata = const {},
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

  bool _isInitialized = false;
  late Fuzzy<String> _fuzzySearcher;

  // Known commands that the system understands
  static const List<String> knownCommands = [
    // Navigation commands
    'home',
    'go home',
    'go back',
    'settings',
    'profile',
    'help',
    
    // Lesson search commands
    'find lesson',
    'search lesson',
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
            getter: (item) => item,
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
    if (!_isInitialized) initialize();

    final normalizedInput = input.toLowerCase().trim();
    
    if (kDebugMode) {
      print('🔧 Analyzing voice input: "$normalizedInput" (confidence: ${(originalConfidence * 100).toStringAsFixed(1)}%)');
    }

    // Step 1: Check for exact matches (high confidence, no correction needed)
    if (knownCommands.contains(normalizedInput)) {
      if (kDebugMode) {
        print('🔧 Exact match found, no correction needed');
      }
      return null;
    }

    // Step 1.5: Check for valid command variations (don't correct valid commands)
    if (_isValidCommandVariation(normalizedInput)) {
      if (kDebugMode) {
        print('🔧 Valid command variation found, no correction needed');
      }
      return null;
    }

    // Step 2: Apply common speech error corrections
    final errorCorrected = _applyCommonErrorCorrections(normalizedInput);
    if (errorCorrected != normalizedInput) {
      if (knownCommands.contains(errorCorrected) || _isValidCommandVariation(errorCorrected)) {
        return CorrectionSuggestion(
          originalInput: input,
          suggestedCommand: errorCorrected,
          confidence: 0.95, // High confidence for known error patterns
          correctionMethod: 'common_error_pattern',
          metadata: {'original_confidence': originalConfidence},
        );
      }
    }

    // Step 3: Check for partial command matches (e.g., "find laptops" -> "find lesson laptops")
    final contextEnhanced = _enhanceWithContext(errorCorrected);
    if (contextEnhanced != errorCorrected && _isValidCommandVariation(contextEnhanced)) {
      return CorrectionSuggestion(
        originalInput: input,
        suggestedCommand: contextEnhanced,
        confidence: 0.85,
        correctionMethod: 'context_enhancement',
        metadata: {'original_confidence': originalConfidence},
      );
    }

    // Step 4: Fuzzy search for similar commands
    final fuzzyResults = _fuzzySearcher.search(normalizedInput);
    if (fuzzyResults.isNotEmpty) {
      final bestMatch = fuzzyResults.first;
      final similarity = StringSimilarity.compareTwoStrings(normalizedInput, bestMatch.item);
      
      // Only suggest if similarity is decent and above confidence threshold
      if (similarity > 0.6) {
        return CorrectionSuggestion(
          originalInput: input,
          suggestedCommand: bestMatch.item,
          confidence: similarity * 0.9, // Slightly lower confidence for fuzzy matches
          correctionMethod: 'fuzzy_match',
          metadata: {
            'original_confidence': originalConfidence,
            'fuzzy_score': bestMatch.score,
            'string_similarity': similarity,
          },
        );
      }
    }

    // Step 5: Check for phonetic similarity using simple soundex-like approach
    final phoneticMatch = _findPhoneticMatch(normalizedInput);
    if (phoneticMatch != null) {
      return CorrectionSuggestion(
        originalInput: input,
        suggestedCommand: phoneticMatch,
        confidence: 0.8, // Increased confidence for phonetic matches
        correctionMethod: 'phonetic_similarity',
        metadata: {'original_confidence': originalConfidence},
      );
    }

    if (kDebugMode) {
      print('🔧 No correction suggestions found for: "$normalizedInput"');
    }

    return null;
  }

  /// Check if input is a valid command variation that doesn't need correction
  bool _isValidCommandVariation(String input) {
    // Check for lesson commands with parameters (e.g., "find lesson laptops")
    final lessonPattern = RegExp(r'\b(find|search|start|begin|show|open) lesson [a-zA-Z][a-zA-Z\s]*\b');
    if (lessonPattern.hasMatch(input)) {
      return true;
    }
    
    // Check for lesson commands without "lesson" keyword but with valid parameters
    final implicitLessonPattern = RegExp(r'\b(find|search|start|begin|show|open) [a-zA-Z][a-zA-Z\s]*\b');
    if (implicitLessonPattern.hasMatch(input)) {
      final words = input.split(' ');
      if (words.length >= 2) {
        final subject = words.skip(1).join(' ');
        // Don't treat navigation terms as lesson names
        if (!['home', 'settings', 'profile', 'help', 'back'].contains(subject)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Apply common speech recognition error corrections
  String _applyCommonErrorCorrections(String input) {
    String corrected = input;
    
    // Apply word-level corrections
    for (final entry in commonSpeechErrors.entries) {
      if (corrected.contains(entry.key)) {
        corrected = corrected.replaceAll(entry.key, entry.value);
      }
    }

    // Handle common phrase patterns
    corrected = corrected.replaceAll(RegExp(r'\bfine\b'), 'find');
    corrected = corrected.replaceAll(RegExp(r'\bstrat\b'), 'start');
    corrected = corrected.replaceAll(RegExp(r'\bsetting\b'), 'settings');
    
    return corrected;
  }

  /// Enhance commands with missing context (e.g., "find laptops" -> "find lesson laptops")
  String _enhanceWithContext(String input) {
    // Pattern: action + subject (likely missing "lesson")
    final actionPattern = RegExp(r'\b(find|search|start|begin|show|open)\s+([a-zA-Z]+(?:\s+[a-zA-Z]+)*)\b');
    final match = actionPattern.firstMatch(input);
    
    if (match != null) {
      final action = match.group(1)!;
      final subject = match.group(2)!;
      
      // Don't enhance if subject is already a known term or navigation command
      if (!['lesson', 'lessons', 'home', 'settings', 'profile', 'help', 'back'].contains(subject)) {
        return '$action lesson $subject';
      }
    }

    return input;
  }

  /// Find phonetically similar commands using simple letter-based similarity
  String? _findPhoneticMatch(String input) {
    double bestSimilarity = 0.0;
    String? bestMatch;

    for (final command in knownCommands) {
      // Simple phonetic similarity: remove vowels and compare consonants
      final inputPhonetic = _getPhoneticKey(input);
      final commandPhonetic = _getPhoneticKey(command);
      
      final similarity = StringSimilarity.compareTwoStrings(inputPhonetic, commandPhonetic);
      
      if (similarity > bestSimilarity && similarity > 0.7) {
        bestSimilarity = similarity;
        bestMatch = command;
      }
    }

    return bestMatch;
  }

  /// Get a simplified phonetic key for comparison
  String _getPhoneticKey(String input) {
    // Remove vowels and common silent letters, keep consonants
    String phonetic = input.toLowerCase()
        .replaceAll(RegExp(r'[aeiou]'), '') // Remove vowels
        .replaceAll(RegExp(r'[hw]'), '') // Remove silent letters
        .replaceAll(RegExp(r'[^a-z]'), ''); // Keep only letters
    
    // Handle common phonetic substitutions
    phonetic = phonetic.replaceAll('ph', 'f');
    phonetic = phonetic.replaceAll('ck', 'k');
    phonetic = phonetic.replaceAll('ch', 'sh');
    
    return phonetic;
  }

  /// Get correction system diagnostics
  Map<String, dynamic> getDiagnostics() {
    return {
      'initialized': _isInitialized,
      'known_commands_count': knownCommands.length,
      'common_errors_count': commonSpeechErrors.length,
      'fuzzy_threshold': _isInitialized ? 0.4 : null,
    };
  }
}
