import 'package:flutter/foundation.dart';

/// Maps speech recognition variants to standard command phrases.
/// 
/// Speech recognition can produce many variations of the same intent.
/// This class normalizes those variants to recognized command forms.
class CommandSynonymMapper {
  /// Map of standard commands to their recognized variants
  static const Map<String, List<String>> _synonymMap = {
    // Navigation synonyms
    'go home': ['home', 'main', 'dashboard', 'start'],
    'settings': ['setting', 'preferences', 'config', 'configuration'],
    'profile': ['my profile', 'user profile', 'account'],
    
    // Lesson management synonyms
    'find lesson': ['search lesson', 'look for lesson', 'show lesson', 'open lesson'],
    'start lesson': ['begin lesson', 'launch lesson', 'play lesson', 'run lesson'],
    'my lessons': ['lessons', 'lesson list', 'all lessons', 'lesson library'],
    'recent lessons': ['recent', 'last lessons', 'recently viewed'],
    
    // Action synonyms
    'find': ['search', 'look for', 'show', 'open', 'display'],
    'start': ['begin', 'launch', 'play', 'run', 'open'],
  };

  /// Normalize an input phrase by applying synonym mappings.
  /// 
  /// Returns the normalized phrase with synonyms replaced by standard forms.
  String normalize(String input) {
    String normalized = input.toLowerCase().trim();
    
    // Apply full phrase synonyms first (longer matches take priority)
    for (final entry in _synonymMap.entries) {
      final standardForm = entry.key;
      final variants = entry.value;
      
      for (final variant in variants) {
        if (normalized.contains(variant)) {
          normalized = normalized.replaceAll(variant, standardForm);
          break;
        }
      }
    }
    
    // Handle implicit lesson commands (e.g., "find laptops" -> "find lesson laptops")
    normalized = _expandImplicitLessonCommands(normalized);
    
    if (kDebugMode && normalized != input.toLowerCase().trim()) {
      print('🔄 Applied synonyms: "$input" -> "$normalized"');
    }
    
    return normalized;
  }

  /// Expand implicit lesson commands where "lesson" keyword is missing.
  String _expandImplicitLessonCommands(String input) {
    // Only expand if "lesson" is already mentioned somewhere
    if (!input.contains('lesson')) {
      return input;
    }
    
    String result = input;
    
    // Handle patterns like "find laptops" -> "find lesson laptops"
    final findPattern = RegExp(r'\b(find|search|show|open)\s+(?!lesson)(\w+)');
    result = result.replaceAllMapped(findPattern, (match) {
      return '${match.group(1)} lesson ${match.group(2)}';
    });
    
    // Handle patterns like "start laptops" -> "start lesson laptops"
    final startPattern = RegExp(r'\b(start|begin|launch|play|run)\s+(?!lesson)(\w+)');
    result = result.replaceAllMapped(startPattern, (match) {
      return '${match.group(1)} lesson ${match.group(2)}';
    });
    
    return result;
  }

  /// Get all recognized synonyms for a standard command.
  static List<String> getSynonymsFor(String standardCommand) {
    return _synonymMap[standardCommand] ?? [];
  }

  /// Get all standard commands that this mapper recognizes.
  static List<String> get standardCommands => _synonymMap.keys.toList();
}
