import 'dart:math';

/// Service for analyzing and improving lesson content quality
class ContentQualityService {
  
  /// Analyze lesson content and provide quality assessment
  static ContentQualityReport analyzeLesson(Map<String, dynamic> lessonData) {
    final lesson = lessonData['lesson'] ?? {};
    final content = List<Map<String, dynamic>>.from(lessonData['content'] ?? []);
    
    return ContentQualityReport(
      overallScore: _calculateOverallScore(lesson, content),
      readabilityAnalysis: _analyzeReadability(lesson, content),
      accessibilityChecks: _checkAccessibility(lesson, content),
      contentStructure: _analyzeContentStructure(content),
      terminologyConsistency: _checkTerminologyConsistency(content),
      suggestions: _generateSuggestions(lesson, content),
      detailedMetrics: _calculateDetailedMetrics(lesson, content),
    );
  }

  /// Generate improvement suggestions for lesson content
  static List<ContentSuggestion> generateSuggestions(Map<String, dynamic> lessonData) {
    final lesson = lessonData['lesson'] ?? {};
    final content = List<Map<String, dynamic>>.from(lessonData['content'] ?? []);
    
    List<ContentSuggestion> suggestions = [];
    
    // Check lesson metadata
    suggestions.addAll(_suggestMetadataImprovements(lesson));
    
    // Check content structure
    suggestions.addAll(_suggestStructureImprovements(content));
    
    // Check content quality
    suggestions.addAll(_suggestContentImprovements(content));
    
    // Check accessibility
    suggestions.addAll(_suggestAccessibilityImprovements(content));
    
    return suggestions..sort((a, b) => b.priority.value.compareTo(a.priority.value));
  }

  // Private helper methods
  static double _calculateOverallScore(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    double score = 0.0;
    int factors = 0;
    
    // Metadata completeness (20%)
    if (lesson['title']?.toString().isNotEmpty == true) score += 20;
    if (lesson['description']?.toString().isNotEmpty == true) score += 20;
    if (lesson['tags']?.isNotEmpty == true) score += 10;
    factors += 50;
    
    // Content diversity (30%)
    final contentTypes = content.map((item) => item['type']).toSet();
    score += (contentTypes.length / 3) * 30; // Max 3 types: term, concept, mcq
    factors += 30;
    
    // Content quality (50%)
    for (final item in content) {
      final itemScore = _scoreContentItem(item);
      score += itemScore * (50 / content.length);
    }
    factors += 50;
    
    return (score / factors) * 100;
  }

  static double _scoreContentItem(Map<String, dynamic> item) {
    double score = 0.0;
    
    // Has title/question
    if (item['title']?.toString().isNotEmpty == true || 
        item['question']?.toString().isNotEmpty == true) {
      score += 25;
    }
    
    // Has content
    if (item['content']?.toString().isNotEmpty == true) {
      score += 25;
    }
    
    // Has example (for terms/concepts)
    if (item['example']?.toString().isNotEmpty == true || 
        item['key_points']?.isNotEmpty == true) {
      score += 25;
    }
    
    // Quality indicators
    final text = (item['content'] ?? '').toString();
    if (text.length > 50) score += 10; // Substantial content
    if (text.contains('.')) score += 10; // Proper sentences
    if (RegExp(r'[A-Z]').hasMatch(text)) score += 5; // Proper capitalization
    
    return score;
  }

  static ReadabilityAnalysis _analyzeReadability(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    final allText = _getAllText(lesson, content);
    
    return ReadabilityAnalysis(
      fleschKincaidGrade: _calculateFleschKincaidGrade(allText),
      averageSentenceLength: _calculateAverageSentenceLength(allText),
      averageWordLength: _calculateAverageWordLength(allText),
      complexWordPercentage: _calculateComplexWordPercentage(allText),
      readabilityLevel: _determineReadabilityLevel(allText),
      suggestions: _generateReadabilitySuggestions(allText),
    );
  }

  static AccessibilityReport _checkAccessibility(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    List<AccessibilityIssue> issues = [];
    
    // Check for alt text on images (placeholder - would need actual implementation)
    for (final item in content) {
      if (item['content']?.toString().contains('image') == true) {
        // Check if image has alt text description
        if (!item['content'].toString().contains('alt') && 
            !item['content'].toString().contains('description')) {
          issues.add(AccessibilityIssue(
            type: AccessibilityIssueType.missingAltText,
            severity: AccessibilitySeverity.high,
            description: 'Image content should include alternative text descriptions',
            location: 'Content item: ${item['title'] ?? 'Untitled'}',
            suggestion: 'Add descriptive alt text for visual content',
          ));
        }
      }
    }
    
    // Check color contrast (simulated)
    issues.addAll(_checkColorContrast(content));
    
    // Check heading structure
    issues.addAll(_checkHeadingStructure(content));
    
    // Check text complexity
    issues.addAll(_checkTextComplexity(content));
    
    return AccessibilityReport(
      overallRating: _calculateAccessibilityRating(issues),
      issues: issues,
      complianceLevel: _determineComplianceLevel(issues),
      recommendations: _generateAccessibilityRecommendations(issues),
    );
  }

  static ContentStructureAnalysis _analyzeContentStructure(List<Map<String, dynamic>> content) {
    final typeDistribution = <String, int>{};
    for (final item in content) {
      final type = item['type']?.toString() ?? 'unknown';
      typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
    }
    
    return ContentStructureAnalysis(
      totalItems: content.length,
      typeDistribution: typeDistribution,
      hasBalancedStructure: _checkBalancedStructure(typeDistribution),
      missingTypes: _findMissingTypes(typeDistribution),
      structureScore: _calculateStructureScore(typeDistribution),
      recommendations: _generateStructureRecommendations(typeDistribution),
    );
  }

  static TerminologyReport _checkTerminologyConsistency(List<Map<String, dynamic>> content) {
    final terms = <String, List<String>>{};
    final definitions = <String, Set<String>>{};
    
    for (final item in content) {
      if (item['type'] == 'term') {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final definition = item['content']?.toString() ?? '';
        
        if (title.isNotEmpty) {
          terms[title] = (terms[title] ?? [])..add(definition);
          definitions[title] = (definitions[title] ?? {})..add(definition);
        }
      }
    }
    
    final inconsistencies = <TerminologyInconsistency>[];
    for (final entry in definitions.entries) {
      if (entry.value.length > 1) {
        inconsistencies.add(TerminologyInconsistency(
          term: entry.key,
          definitions: entry.value.toList(),
          severity: InconsistencySeverity.medium,
          suggestion: 'Standardize the definition for "${entry.key}"',
        ));
      }
    }
    
    return TerminologyReport(
      totalTerms: terms.length,
      inconsistencies: inconsistencies,
      consistencyScore: _calculateConsistencyScore(inconsistencies, terms.length),
      recommendations: _generateTerminologyRecommendations(inconsistencies),
    );
  }

  static List<ContentSuggestion> _generateSuggestions(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    List<ContentSuggestion> suggestions = [];
    
    // Check lesson length
    if (content.length < 5) {
      suggestions.add(ContentSuggestion(
        type: SuggestionType.structure,
        priority: SuggestionPriority.medium,
        title: 'Add More Content',
        description: 'Consider adding more content items for a comprehensive lesson',
        actionable: true,
        estimatedImpact: 'Improves lesson depth and learning outcomes',
      ));
    }
    
    // Check for examples
    final itemsWithoutExamples = content.where((item) => 
        item['type'] == 'term' && 
        (item['example']?.toString().isEmpty ?? true)).length;
    
    if (itemsWithoutExamples > 0) {
      suggestions.add(ContentSuggestion(
        type: SuggestionType.content,
        priority: SuggestionPriority.high,
        title: 'Add Examples to Terms',
        description: '$itemsWithoutExamples terms are missing examples',
        actionable: true,
        estimatedImpact: 'Enhances understanding and retention',
      ));
    }
    
    return suggestions;
  }

  static Map<String, dynamic> _calculateDetailedMetrics(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    final allText = _getAllText(lesson, content);
    
    return {
      'wordCount': _countWords(allText),
      'characterCount': allText.length,
      'sentenceCount': _countSentences(allText),
      'paragraphCount': _countParagraphs(allText),
      'estimatedReadingTime': _estimateReadingTime(allText),
      'difficultyKeywords': _findDifficultyKeywords(allText),
      'technicalTerms': _findTechnicalTerms(content),
    };
  }

  // Helper methods for text analysis
  static String _getAllText(Map<String, dynamic> lesson, List<Map<String, dynamic>> content) {
    final buffer = StringBuffer();
    buffer.write(lesson['title'] ?? '');
    buffer.write(' ');
    buffer.write(lesson['description'] ?? '');
    buffer.write(' ');
    
    for (final item in content) {
      buffer.write(item['title'] ?? '');
      buffer.write(' ');
      buffer.write(item['content'] ?? '');
      buffer.write(' ');
      buffer.write(item['question'] ?? '');
      buffer.write(' ');
      
      if (item['key_points'] is List) {
        for (final point in item['key_points']) {
          buffer.write(point.toString());
          buffer.write(' ');
        }
      }
    }
    
    return buffer.toString();
  }

  static double _calculateFleschKincaidGrade(String text) {
    final sentences = _countSentences(text);
    final words = _countWords(text);
    final syllables = _countSyllables(text);
    
    if (sentences == 0 || words == 0) return 0.0;
    
    return 0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59;
  }

  static double _calculateAverageSentenceLength(String text) {
    final sentences = _countSentences(text);
    final words = _countWords(text);
    return sentences > 0 ? words / sentences : 0.0;
  }

  static double _calculateAverageWordLength(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;
    
    final totalChars = words.fold(0, (sum, word) => sum + word.replaceAll(RegExp(r'[^\w]'), '').length);
    return totalChars / words.length;
  }

  static double _calculateComplexWordPercentage(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return 0.0;
    
    final complexWords = words.where((word) => _countSyllablesInWord(word) >= 3).length;
    return (complexWords / words.length) * 100;
  }

  static int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  static int _countSentences(String text) {
    return text.split(RegExp(r'[.!?]+'))
        .where((sentence) => sentence.trim().isNotEmpty)
        .length;
  }

  static int _countParagraphs(String text) {
    return text.split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .length;
  }

  static int _countSyllables(String text) {
    return text.split(RegExp(r'\s+'))
        .fold(0, (sum, word) => sum + _countSyllablesInWord(word));
  }

  static int _countSyllablesInWord(String word) {
    word = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (word.isEmpty) return 0;
    
    int syllables = 0;
    bool previousWasVowel = false;
    
    for (int i = 0; i < word.length; i++) {
      final isVowel = 'aeiou'.contains(word[i]);
      if (isVowel && !previousWasVowel) {
        syllables++;
      }
      previousWasVowel = isVowel;
    }
    
    // Adjust for silent e
    if (word.endsWith('e') && syllables > 1) {
      syllables--;
    }
    
    return max(1, syllables);
  }

  static String _determineReadabilityLevel(String text) {
    final grade = _calculateFleschKincaidGrade(text);
    
    if (grade <= 6) return 'Elementary';
    if (grade <= 8) return 'Middle School';
    if (grade <= 12) return 'High School';
    if (grade <= 16) return 'College';
    return 'Graduate';
  }

  static List<String> _generateReadabilitySuggestions(String text) {
    final suggestions = <String>[];
    final avgSentenceLength = _calculateAverageSentenceLength(text);
    final complexWordPercentage = _calculateComplexWordPercentage(text);
    
    if (avgSentenceLength > 20) {
      suggestions.add('Consider breaking long sentences into shorter ones');
    }
    
    if (complexWordPercentage > 15) {
      suggestions.add('Consider simplifying complex words or providing definitions');
    }
    
    return suggestions;
  }

  // Placeholder implementations for accessibility checks
  static List<AccessibilityIssue> _checkColorContrast(List<Map<String, dynamic>> content) {
    // In a real implementation, this would check actual color usage
    return [];
  }

  static List<AccessibilityIssue> _checkHeadingStructure(List<Map<String, dynamic>> content) {
    List<AccessibilityIssue> issues = [];
    
    // Check if concepts have proper structure
    final concepts = content.where((item) => item['type'] == 'concept').toList();
    for (final concept in concepts) {
      if (concept['key_points'] == null || (concept['key_points'] as List).isEmpty) {
        issues.add(AccessibilityIssue(
          type: AccessibilityIssueType.poorStructure,
          severity: AccessibilitySeverity.medium,
          description: 'Concept lacks structured key points',
          location: 'Concept: ${concept['title'] ?? 'Untitled'}',
          suggestion: 'Add key points to improve content structure',
        ));
      }
    }
    
    return issues;
  }

  static List<AccessibilityIssue> _checkTextComplexity(List<Map<String, dynamic>> content) {
    List<AccessibilityIssue> issues = [];
    
    for (final item in content) {
      final text = item['content']?.toString() ?? '';
      final grade = _calculateFleschKincaidGrade(text);
      
      if (grade > 16) {
        issues.add(AccessibilityIssue(
          type: AccessibilityIssueType.complexText,
          severity: AccessibilitySeverity.medium,
          description: 'Text complexity is very high (Graduate level)',
          location: '${item['type']}: ${item['title'] ?? 'Untitled'}',
          suggestion: 'Consider simplifying language or adding explanations',
        ));
      }
    }
    
    return issues;
  }

  static double _calculateAccessibilityRating(List<AccessibilityIssue> issues) {
    if (issues.isEmpty) return 100.0;
    
    double penalty = 0.0;
    for (final issue in issues) {
      switch (issue.severity) {
        case AccessibilitySeverity.high:
          penalty += 20;
          break;
        case AccessibilitySeverity.medium:
          penalty += 10;
          break;
        case AccessibilitySeverity.low:
          penalty += 5;
          break;
      }
    }
    
    return max(0.0, 100.0 - penalty);
  }

  static String _determineComplianceLevel(List<AccessibilityIssue> issues) {
    final highIssues = issues.where((issue) => issue.severity == AccessibilitySeverity.high).length;
    final mediumIssues = issues.where((issue) => issue.severity == AccessibilitySeverity.medium).length;
    
    if (highIssues == 0 && mediumIssues == 0) return 'AAA';
    if (highIssues == 0 && mediumIssues <= 2) return 'AA';
    if (highIssues <= 1) return 'A';
    return 'Non-compliant';
  }

  static List<String> _generateAccessibilityRecommendations(List<AccessibilityIssue> issues) {
    final recommendations = <String>[];
    
    if (issues.any((issue) => issue.type == AccessibilityIssueType.missingAltText)) {
      recommendations.add('Add alternative text descriptions for all visual content');
    }
    
    if (issues.any((issue) => issue.type == AccessibilityIssueType.complexText)) {
      recommendations.add('Simplify language or provide glossary definitions');
    }
    
    if (issues.any((issue) => issue.type == AccessibilityIssueType.poorStructure)) {
      recommendations.add('Improve content structure with clear headings and bullet points');
    }
    
    return recommendations;
  }

  // Additional helper methods
  static bool _checkBalancedStructure(Map<String, int> typeDistribution) {
    final values = typeDistribution.values.toList();
    if (values.isEmpty) return false;
    
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    
    return (max - min) <= 2; // Allow small imbalance
  }

  static List<String> _findMissingTypes(Map<String, int> typeDistribution) {
    final expectedTypes = ['term', 'concept', 'mcq'];
    return expectedTypes.where((type) => !typeDistribution.containsKey(type)).toList();
  }

  static double _calculateStructureScore(Map<String, int> typeDistribution) {
    double score = 0.0;
    
    // Points for having different types
    score += typeDistribution.length * 20.0;
    
    // Points for balance
    if (_checkBalancedStructure(typeDistribution)) {
      score += 20.0;
    }
    
    // Points for completeness
    final expectedTypes = ['term', 'concept', 'mcq'];
    final hasAllTypes = expectedTypes.every((type) => typeDistribution.containsKey(type));
    if (hasAllTypes) {
      score += 20.0;
    }
    
    return min(100.0, score);
  }

  static List<String> _generateStructureRecommendations(Map<String, int> typeDistribution) {
    final recommendations = <String>[];
    
    final missingTypes = _findMissingTypes(typeDistribution);
    if (missingTypes.isNotEmpty) {
      recommendations.add('Consider adding ${missingTypes.join(', ')} content types');
    }
    
    if (!_checkBalancedStructure(typeDistribution)) {
      recommendations.add('Balance the distribution of content types');
    }
    
    return recommendations;
  }

  static double _calculateConsistencyScore(List<TerminologyInconsistency> inconsistencies, int totalTerms) {
    if (totalTerms == 0) return 100.0;
    
    final inconsistentTerms = inconsistencies.length;
    return max(0.0, 100.0 - (inconsistentTerms / totalTerms) * 100);
  }

  static List<String> _generateTerminologyRecommendations(List<TerminologyInconsistency> inconsistencies) {
    if (inconsistencies.isEmpty) {
      return ['Terminology is consistent throughout the lesson'];
    }
    
    return [
      'Review and standardize definitions for ${inconsistencies.length} terms',
      'Consider creating a glossary for key terms',
      'Ensure consistent terminology usage across all content',
    ];
  }

  static int _estimateReadingTime(String text) {
    final words = _countWords(text);
    return (words / 200).ceil(); // Average reading speed: 200 words per minute
  }

  static List<String> _findDifficultyKeywords(String text) {
    final advancedKeywords = [
      'algorithm', 'optimization', 'complexity', 'architecture', 'paradigm',
      'implementation', 'methodology', 'framework', 'abstraction', 'polymorphism'
    ];
    
    final foundKeywords = <String>[];
    final lowerText = text.toLowerCase();
    
    for (final keyword in advancedKeywords) {
      if (lowerText.contains(keyword)) {
        foundKeywords.add(keyword);
      }
    }
    
    return foundKeywords;
  }

  static List<String> _findTechnicalTerms(List<Map<String, dynamic>> content) {
    return content
        .where((item) => item['type'] == 'term')
        .map((item) => item['title']?.toString() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();
  }

  // Suggestion helper methods
  static List<ContentSuggestion> _suggestMetadataImprovements(Map<String, dynamic> lesson) {
    List<ContentSuggestion> suggestions = [];
    
    if ((lesson['description']?.toString().length ?? 0) < 50) {
      suggestions.add(ContentSuggestion(
        type: SuggestionType.metadata,
        priority: SuggestionPriority.medium,
        title: 'Improve Lesson Description',
        description: 'Add a more detailed lesson description (at least 50 characters)',
        actionable: true,
        estimatedImpact: 'Helps learners understand lesson objectives',
      ));
    }
    
    if (lesson['tags']?.isEmpty ?? true) {
      suggestions.add(ContentSuggestion(
        type: SuggestionType.metadata,
        priority: SuggestionPriority.low,
        title: 'Add Tags',
        description: 'Add relevant tags to improve discoverability',
        actionable: true,
        estimatedImpact: 'Improves lesson organization and searchability',
      ));
    }
    
    return suggestions;
  }

  static List<ContentSuggestion> _suggestStructureImprovements(List<Map<String, dynamic>> content) {
    List<ContentSuggestion> suggestions = [];
    
    final typeDistribution = <String, int>{};
    for (final item in content) {
      final type = item['type']?.toString() ?? 'unknown';
      typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
    }
    
    if (!typeDistribution.containsKey('mcq') || typeDistribution['mcq']! < 2) {
      suggestions.add(ContentSuggestion(
        type: SuggestionType.structure,
        priority: SuggestionPriority.high,
        title: 'Add More Assessment Questions',
        description: 'Include at least 2-3 multiple choice questions for better assessment',
        actionable: true,
        estimatedImpact: 'Improves learning assessment and retention',
      ));
    }
    
    return suggestions;
  }

  static List<ContentSuggestion> _suggestContentImprovements(List<Map<String, dynamic>> content) {
    List<ContentSuggestion> suggestions = [];
    
    for (final item in content) {
      if (item['type'] == 'term' && (item['example']?.toString().isEmpty ?? true)) {
        suggestions.add(ContentSuggestion(
          type: SuggestionType.content,
          priority: SuggestionPriority.medium,
          title: 'Add Example to Term',
          description: 'Term "${item['title']}" would benefit from a practical example',
          actionable: true,
          estimatedImpact: 'Enhances understanding with concrete examples',
        ));
      }
    }
    
    return suggestions;
  }

  static List<ContentSuggestion> _suggestAccessibilityImprovements(List<Map<String, dynamic>> content) {
    List<ContentSuggestion> suggestions = [];
    
    for (final item in content) {
      final text = item['content']?.toString() ?? '';
      if (_calculateFleschKincaidGrade(text) > 14) {
        suggestions.add(ContentSuggestion(
          type: SuggestionType.accessibility,
          priority: SuggestionPriority.medium,
          title: 'Simplify Complex Text',
          description: 'Content in "${item['title']}" has high reading complexity',
          actionable: true,
          estimatedImpact: 'Improves accessibility for diverse learners',
        ));
      }
    }
    
    return suggestions;
  }
}

// Data models for content quality analysis
class ContentQualityReport {
  final double overallScore;
  final ReadabilityAnalysis readabilityAnalysis;
  final AccessibilityReport accessibilityChecks;
  final ContentStructureAnalysis contentStructure;
  final TerminologyReport terminologyConsistency;
  final List<ContentSuggestion> suggestions;
  final Map<String, dynamic> detailedMetrics;

  ContentQualityReport({
    required this.overallScore,
    required this.readabilityAnalysis,
    required this.accessibilityChecks,
    required this.contentStructure,
    required this.terminologyConsistency,
    required this.suggestions,
    required this.detailedMetrics,
  });
}

class ReadabilityAnalysis {
  final double fleschKincaidGrade;
  final double averageSentenceLength;
  final double averageWordLength;
  final double complexWordPercentage;
  final String readabilityLevel;
  final List<String> suggestions;

  ReadabilityAnalysis({
    required this.fleschKincaidGrade,
    required this.averageSentenceLength,
    required this.averageWordLength,
    required this.complexWordPercentage,
    required this.readabilityLevel,
    required this.suggestions,
  });
}

class AccessibilityReport {
  final double overallRating;
  final List<AccessibilityIssue> issues;
  final String complianceLevel;
  final List<String> recommendations;

  AccessibilityReport({
    required this.overallRating,
    required this.issues,
    required this.complianceLevel,
    required this.recommendations,
  });
}

class AccessibilityIssue {
  final AccessibilityIssueType type;
  final AccessibilitySeverity severity;
  final String description;
  final String location;
  final String suggestion;

  AccessibilityIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.location,
    required this.suggestion,
  });
}

enum AccessibilityIssueType {
  missingAltText,
  poorContrast,
  poorStructure,
  complexText,
}

enum AccessibilitySeverity {
  low,
  medium,
  high,
}

class ContentStructureAnalysis {
  final int totalItems;
  final Map<String, int> typeDistribution;
  final bool hasBalancedStructure;
  final List<String> missingTypes;
  final double structureScore;
  final List<String> recommendations;

  ContentStructureAnalysis({
    required this.totalItems,
    required this.typeDistribution,
    required this.hasBalancedStructure,
    required this.missingTypes,
    required this.structureScore,
    required this.recommendations,
  });
}

class TerminologyReport {
  final int totalTerms;
  final List<TerminologyInconsistency> inconsistencies;
  final double consistencyScore;
  final List<String> recommendations;

  TerminologyReport({
    required this.totalTerms,
    required this.inconsistencies,
    required this.consistencyScore,
    required this.recommendations,
  });
}

class TerminologyInconsistency {
  final String term;
  final List<String> definitions;
  final InconsistencySeverity severity;
  final String suggestion;

  TerminologyInconsistency({
    required this.term,
    required this.definitions,
    required this.severity,
    required this.suggestion,
  });
}

enum InconsistencySeverity {
  low,
  medium,
  high,
}

class ContentSuggestion {
  final SuggestionType type;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final bool actionable;
  final String estimatedImpact;

  ContentSuggestion({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionable,
    required this.estimatedImpact,
  });
}

enum SuggestionType {
  metadata,
  structure,
  content,
  accessibility,
  terminology,
}

enum SuggestionPriority {
  low(1),
  medium(2),
  high(3);

  const SuggestionPriority(this.value);
  final int value;
}
