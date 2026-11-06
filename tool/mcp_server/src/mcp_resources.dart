import 'dart:convert';
import 'dart:io';
import 'learning_data_source.dart';

class McpResourceDefinition {
  final String uri;
  final String name;
  final String description;
  final String mimeType;

  McpResourceDefinition({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
      'description': description,
      'mimeType': mimeType,
    };
  }
}

class McpResourcesRegistry {
  final LearningDataSource dataSource;

  McpResourcesRegistry({required this.dataSource});

  List<Map<String, dynamic>> listResources() {
    return [
      McpResourceDefinition(
        uri: 'learningapp://schema/curriculum_manifest',
        name: 'Curriculum Manifest JSON Schema',
        description: 'Authoritative JSON Schema for LearningApp course, certification, and pathway manifests.',
        mimeType: 'application/json',
      ).toJson(),
      McpResourceDefinition(
        uri: 'learningapp://schema/lesson',
        name: 'Lesson Format JSON Schema',
        description: 'Schema definition for modular learning lessons, terms, flashcards, and MCQ items.',
        mimeType: 'application/json',
      ).toJson(),
      McpResourceDefinition(
        uri: 'learningapp://rubrics/item_writing',
        name: 'Evidence-Based Item Writing Rubric',
        description: 'Haladyna (2002) psychometric guidelines for exam-grade MCQ, distractor, and stem design.',
        mimeType: 'text/markdown',
      ).toJson(),
      McpResourceDefinition(
        uri: 'learningapp://catalog/targets',
        name: 'Learning Catalog Index',
        description: 'Index of available learning targets, certifications, and career pathways.',
        mimeType: 'application/json',
      ).toJson(),
    ];
  }

  Future<Map<String, dynamic>> readResource(String uriStr) async {
    final uri = Uri.parse(uriStr);

    if (uriStr == 'learningapp://schema/curriculum_manifest') {
      final file = File('content/schema/curriculum_manifest.schema.json');
      if (file.existsSync()) {
        return {
          'contents': [
            {
              'uri': uriStr,
              'mimeType': 'application/json',
              'text': file.readAsStringSync(),
            }
          ]
        };
      }
    }

    if (uriStr == 'learningapp://schema/lesson') {
      final sampleFile = File('data/samples/sample_lesson_valid.json');
      final text = sampleFile.existsSync()
          ? sampleFile.readAsStringSync()
          : jsonEncode({
              'type': 'object',
              'properties': {
                'lesson': {'type': 'object'},
                'content': {'type': 'array'}
              }
            });
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'application/json',
            'text': text,
          }
        ]
      };
    }

    if (uriStr == 'learningapp://rubrics/item_writing') {
      const rubricText = '''# Evidence-Based Item Writing Rubric (Haladyna et al., 2002)

## 1. Content and Cognitive Alignment
- **Target Bloom Level**: Emphasize Application and Analysis (scenarios, diagnosis) over simple recognition.
- **Unidimensionality**: Focus each question on a single clear concept or problem.
- **Source Grounding**: Every item must cite an authoritative reference with section locator and quote.

## 2. Question Stem Construction
- **Central Problem**: State the problem clearly in the stem; avoid vague stems that require reading options to understand the question.
- **Positive Framing**: Avoid negative words ("NOT", "EXCEPT", "LEAST"). If unavoidable, capitalize and bold (**NOT**).
- **No Window Dressing**: Avoid extraneous narrative that does not contribute to solving the problem.

## 3. Options and Distractor Quality
- **Plausible Misconceptions**: Every distractor must represent a genuine learner misunderstanding, not an absurd filler.
- **Homogeneity**: Options must be grammatically consistent and similar in length, style, and complexity.
- **No Cueing**: Avoid making the correct answer distinctly longer, more detailed, or qualified with "usually" / "typically".
- **Banned Options**: NEVER use "All of the above" or "None of the above".

## 4. Balanced Answer Positions
- Ensure correct answer keys are distributed evenly across choices (no position bias toward option B or C).
''';
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'text/markdown',
            'text': rubricText,
          }
        ]
      };
    }

    if (uriStr == 'learningapp://catalog/targets') {
      final catalog = await dataSource.searchCatalog(limit: 50);
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'application/json',
            'text': jsonEncode(catalog),
          }
        ]
      };
    }

    // Dynamic resource: learningapp://curriculum/{target_version_id}
    if (uri.scheme == 'learningapp' && uri.host == 'curriculum') {
      final targetSlug = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final outline = await dataSource.getTargetOutline(targetSlug);
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'application/json',
            'text': jsonEncode(outline ?? {'error': 'Target not found'}),
          }
        ]
      };
    }

    // Dynamic resource: learningapp://readiness/{user_id}/{target_version_id}
    if (uri.scheme == 'learningapp' && uri.host == 'readiness') {
      final userId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : '';
      final targetId = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
      final readiness = await dataSource.getLearnerState(userId: userId, targetVersionId: targetId);
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'application/json',
            'text': jsonEncode(readiness),
          }
        ]
      };
    }

    // Dynamic resource: learningapp://item_analytics/{item_id}
    if (uri.scheme == 'learningapp' && uri.host == 'item_analytics') {
      final itemId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      final analytics = await dataSource.getItemAnalytics(itemId);
      return {
        'contents': [
          {
            'uri': uriStr,
            'mimeType': 'application/json',
            'text': jsonEncode(analytics),
          }
        ]
      };
    }

    throw FormatException('Resource not found: $uriStr');
  }
}
