import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/content_quality_service.dart';

void main() {
  group('ContentQualityService Tests', () {
    test('should analyze lesson with complete data', () {
      final lessonData = {
        'lesson': {
          'title': 'Introduction to Flutter',
          'description': 'A comprehensive guide to Flutter development',
          'tags': ['flutter', 'mobile', 'beginner'],
        },
        'content': [
          {
            'type': 'concept',
            'title': 'What is Flutter?',
            'content': 'Flutter is an open-source UI software development kit created by Google.',
            'example': 'Used to build cross-platform applications',
          },
          {
            'type': 'term',
            'title': 'Widget',
            'content': 'The basic building blocks of a Flutter app.',
            'example': 'Text, Container, Row are all widgets',
          },
          {
            'type': 'mcq',
            'question': 'What is Flutter?',
            'options': ['A language', 'A UI toolkit', 'A database'],
            'correctIndex': 1,
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.overallScore, greaterThan(0));
      expect(report.readabilityAnalysis, isNotNull);
      expect(report.accessibilityChecks, isNotNull);
      expect(report.contentStructure, isNotNull);
      expect(report.detailedMetrics, isNotEmpty);
    });

    test('should analyze lesson with minimal data', () {
      final lessonData = {
        'lesson': {
          'title': 'Test Lesson',
        },
        'content': [
          {
            'type': 'term',
            'title': 'Test Term',
            'content': 'Test definition',
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.overallScore, greaterThan(0));
      expect(report.contentStructure.totalItems, 1);
    });

    test('should analyze empty lesson', () {
      final lessonData = <String, dynamic>{
        'lesson': <String, dynamic>{},
        'content': <Map<String, dynamic>>[],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.overallScore, greaterThanOrEqualTo(0));
      expect(report.contentStructure.totalItems, 0);
    });

    test('should detect content structure', () {
      final lessonData = {
        'lesson': {'title': 'Test'},
        'content': [
          {'type': 'concept', 'title': 'Concept 1', 'content': 'Content'},
          {'type': 'term', 'title': 'Term 1', 'content': 'Definition'},
          {'type': 'mcq', 'question': 'Question 1'},
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.contentStructure.totalItems, 3);
      expect(report.contentStructure.typeDistribution.length, 3);
      expect(report.contentStructure.typeDistribution['concept'], 1);
      expect(report.contentStructure.typeDistribution['term'], 1);
      expect(report.contentStructure.typeDistribution['mcq'], 1);
    });

    test('should provide readability analysis', () {
      final lessonData = {
        'lesson': {
          'title': 'Test Lesson',
          'description': 'This is a test lesson with some sentences. It has multiple sentences for testing.',
        },
        'content': [
          {
            'type': 'concept',
            'content': 'This is a concept with multiple sentences. Each sentence adds information. The content is readable.',
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.readabilityAnalysis, isNotNull);
      expect(report.readabilityAnalysis.fleschKincaidGrade, greaterThanOrEqualTo(0));
      expect(report.readabilityAnalysis.averageSentenceLength, greaterThan(0));
      expect(report.readabilityAnalysis.readabilityLevel, isNotEmpty);
    });

    test('should generate suggestions for incomplete lesson', () {
      final lessonData = {
        'lesson': {
          'title': 'Test',
          // Missing description and tags
        },
        'content': [
          {
            'type': 'term',
            'title': 'Term',
            // Missing content and example
          },
        ],
      };

      final suggestions = ContentQualityService.generateSuggestions(lessonData);

      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.priority == SuggestionPriority.high), isTrue);
    });

    test('should prioritize suggestions correctly', () {
      final lessonData = {
        'lesson': {'title': 'Test'},
        'content': [],
      };

      final suggestions = ContentQualityService.generateSuggestions(lessonData);

      // Suggestions should be sorted by priority (high to low)
      if (suggestions.length > 1) {
        for (int i = 0; i < suggestions.length - 1; i++) {
          expect(
            suggestions[i].priority.value,
            greaterThanOrEqualTo(suggestions[i + 1].priority.value),
          );
        }
      }
    });

    test('should check accessibility issues', () {
      final lessonData = {
        'lesson': {'title': 'Test'},
        'content': [
          {
            'type': 'concept',
            'content': 'Here is an image without alt text',
            'title': 'Image Concept',
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.accessibilityChecks, isNotNull);
      expect(report.accessibilityChecks.overallRating, greaterThanOrEqualTo(0));
      expect(report.accessibilityChecks.complianceLevel, isNotEmpty);
    });

    test('should detect terminology inconsistencies', () {
      final lessonData = {
        'lesson': {'title': 'Test'},
        'content': [
          {
            'type': 'term',
            'title': 'Widget',
            'content': 'A UI component',
          },
          {
            'type': 'term',
            'title': 'widget',
            'content': 'A building block of UI',
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.terminologyConsistency, isNotNull);
      expect(report.terminologyConsistency.totalTerms, greaterThan(0));
    });

    test('should calculate detailed metrics', () {
      final lessonData = {
        'lesson': {
          'title': 'Test Lesson Title',
          'description': 'A test description with several words in it.',
        },
        'content': [
          {
            'type': 'concept',
            'content': 'This is concept content. It has sentences.',
          },
          {
            'type': 'term',
            'content': 'Term definition here.',
          },
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.detailedMetrics, isNotEmpty);
      expect(report.detailedMetrics.containsKey('wordCount'), isTrue);
      expect(report.detailedMetrics['wordCount'], greaterThan(0));
    });

    test('should handle missing fields gracefully', () {
      final lessonData = <String, dynamic>{
        'lesson': <String, dynamic>{},
        'content': <Map<String, dynamic>>[],
      };

      expect(
        () => ContentQualityService.analyzeLesson(lessonData),
        returnsNormally,
      );
    });

    test('should validate content types', () {
      final lessonData = {
        'lesson': {'title': 'Test'},
        'content': [
          {'type': 'concept', 'content': 'Content'},
          {'type': 'term', 'content': 'Content'},
          {'type': 'mcq', 'question': 'Q'},
          {'type': 'unknown', 'content': 'Content'},
        ],
      };

      final report = ContentQualityService.analyzeLesson(lessonData);

      expect(report.contentStructure.typeDistribution.containsKey('unknown'), isTrue);
    });
  });
}
