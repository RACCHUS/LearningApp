import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/concept.dart';

/// Handles content processing for different lesson types and formats
class ContentProcessor {
  ContentProcessor();

  /// Extracts text from lesson content for TTS processing
  List<String> extractLessonTexts(Lesson lesson) {
    final texts = <String>[];
    
    // Add lesson title and intro
    if (lesson.title.isNotEmpty) {
      texts.add('Starting lesson: ${lesson.title}');
    }
    
    if (lesson.description?.isNotEmpty == true) {
      texts.add(lesson.description!);
    }

    // Process concepts - using the actual Concept model structure
    for (final concept in lesson.concepts) {
      texts.addAll(_extractConceptTexts(concept));
    }

    // Add lesson completion message
    texts.add('Lesson completed. Well done!');
    
    return texts.where((text) => text.trim().isNotEmpty).toList();
  }

  /// Extracts text from a single concept using the actual Concept model
  List<String> _extractConceptTexts(Concept concept) {
    final texts = <String>[];
    
    // Add concept text (the main content)
    if (concept.conceptText.isNotEmpty) {
      texts.add('Concept: ${concept.conceptText}');
    }

    // Add example text if available
    if (concept.exampleText?.isNotEmpty == true) {
      texts.add('Example: ${concept.exampleText}');
    }
    
    return texts;
  }

  /// Cleans and normalizes text for TTS
  String cleanTextForTTS(String text) {
    // Basic text cleaning for TTS
    return text
        .replaceAll(RegExp(r'[^\w\s\.\,\!\?\:\;]'), '') // Remove special chars except basic punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Estimates reading time for content
  Duration estimateReadingTime(List<String> texts) {
    final totalWords = texts
        .map((text) => text.split(' ').length)
        .fold(0, (sum, count) => sum + count);
    
    // Assume 150 words per minute for TTS
    const wordsPerMinute = 150;
    final minutes = totalWords / wordsPerMinute;
    
    return Duration(milliseconds: (minutes * 60 * 1000).round());
  }

  /// Validates lesson content before processing
  bool validateLesson(Lesson lesson) {
    if (lesson.title.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Lesson has empty title');
      }
      return false;
    }
    
    if (lesson.concepts.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Lesson has no concepts');
      }
      return false;
    }
    
    return true;
  }

  /// Validates concept content before processing
  bool validateConcept(Concept concept) {
    if (concept.conceptText.isEmpty) {
      if (kDebugMode) {
        print('⚠️ Concept has empty text');
      }
      return false;
    }
    
    return true;
  }

  /// Processes individual text for specific content types
  String processQuestionText(String questionText) {
    return 'Question: ${cleanTextForTTS(questionText)}';
  }

  String processAnswerText(String answerText) {
    return 'Answer: ${cleanTextForTTS(answerText)}';
  }

  String processExplanationText(String explanationText) {
    return 'Explanation: ${cleanTextForTTS(explanationText)}';
  }

  /// Formats options for MCQ or question content
  String formatOptions(List<String> options) {
    if (options.isEmpty) return '';
    
    final buffer = StringBuffer('Options: ');
    for (int i = 0; i < options.length; i++) {
      if (i > 0) buffer.write(', ');
      final letter = String.fromCharCode(65 + i); // A, B, C, D
      buffer.write('$letter: ${options[i]}');
    }
    
    return buffer.toString();
  }
}
