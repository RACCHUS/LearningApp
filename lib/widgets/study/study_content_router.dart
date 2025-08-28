import 'package:flutter/material.dart';
import 'package:learning_pwa/providers/study_provider.dart';
import 'flashcard_content.dart';
import 'mcq_content.dart';
import 'concept_content.dart';

/// Study content router widget
/// 
/// Routes to appropriate content widget based on study mode
/// and provides consistent content display interface.
class StudyContentRouter extends StatelessWidget {
  final dynamic content;
  final StudyMode mode;

  const StudyContentRouter({
    super.key,
    required this.content,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case StudyMode.flashcard:
        return FlashcardContent(term: content);
      case StudyMode.mcq:
        return McqContent(question: content);
      case StudyMode.concept:
        return ConceptContent(concept: content);
      case StudyMode.lesson:
        // Mixed mode - determine content type dynamically
        return _buildMixedModeContent(content);
    }
  }

  Widget _buildMixedModeContent(dynamic content) {
    // Determine content type based on content properties
    if (content.runtimeType.toString().contains('Term')) {
      return FlashcardContent(term: content);
    } else if (content.runtimeType.toString().contains('Question')) {
      return McqContent(question: content);
    } else if (content.runtimeType.toString().contains('Concept')) {
      return ConceptContent(concept: content);
    } else {
      // Fallback: try to infer from available properties
      if (_hasProperty(content, 'term') && _hasProperty(content, 'definition')) {
        return FlashcardContent(term: content);
      } else if (_hasProperty(content, 'questionText') && _hasProperty(content, 'options')) {
        return McqContent(question: content);
      } else if (_hasProperty(content, 'conceptText')) {
        return ConceptContent(concept: content);
      } else {
        return _buildUnsupportedMode();
      }
    }
  }

  Widget _buildUnsupportedMode() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Unsupported study mode',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Content type: ${mode.toString()}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  bool _hasProperty(dynamic obj, String property) {
    try {
      // Use reflection or try-catch to check if property exists
      final mirror = obj.runtimeType;
      return mirror.toString().contains(property);
    } catch (e) {
      return false;
    }
  }
}
