import 'dart:convert';

/// Service for managing lesson templates
class LessonTemplateService {
  
  /// Get all available templates organized by category
  static Map<String, List<LessonTemplate>> getAllTemplates() {
    return {
      'Programming': getProgrammingTemplates(),
      'IT & Technology': getITTemplates(),
      'Science': getScienceTemplates(),
      'Certification': getCertificationTemplates(),
      'General': getGeneralTemplates(),
    };
  }

  /// Get templates for programming subjects
  static List<LessonTemplate> getProgrammingTemplates() {
    return [
      LessonTemplate(
        id: 'prog_language_intro',
        title: 'Programming Language Introduction',
        description: 'Template for introducing a new programming language with syntax basics',
        category: 'Programming',
        difficulty: 'beginner',
        estimatedDuration: 45,
        contentStructure: {
          'terms': 5,
          'concepts': 3,
          'mcqs': 4,
        },
        template: _getProgrammingLanguageTemplate(),
        tags: ['programming', 'language', 'syntax', 'basics'],
      ),
      
      LessonTemplate(
        id: 'data_structures',
        title: 'Data Structure Deep Dive',
        description: 'Template for explaining data structures with examples and applications',
        category: 'Programming',
        difficulty: 'intermediate',
        estimatedDuration: 60,
        contentStructure: {
          'terms': 4,
          'concepts': 4,
          'mcqs': 5,
        },
        template: _getDataStructureTemplate(),
        tags: ['programming', 'data-structures', 'algorithms'],
      ),
      
      LessonTemplate(
        id: 'algorithm_analysis',
        title: 'Algorithm Analysis',
        description: 'Template for analyzing algorithms with complexity and optimization',
        category: 'Programming',
        difficulty: 'advanced',
        estimatedDuration: 75,
        contentStructure: {
          'terms': 6,
          'concepts': 5,
          'mcqs': 6,
        },
        template: _getAlgorithmTemplate(),
        tags: ['algorithms', 'complexity', 'optimization'],
      ),
    ];
  }

  /// Get templates for IT and technology subjects
  static List<LessonTemplate> getITTemplates() {
    return [
      LessonTemplate(
        id: 'network_concepts',
        title: 'Networking Fundamentals',
        description: 'Template for networking concepts with protocols and configurations',
        category: 'IT & Technology',
        difficulty: 'intermediate',
        estimatedDuration: 50,
        contentStructure: {
          'terms': 6,
          'concepts': 4,
          'mcqs': 5,
        },
        template: _getNetworkingTemplate(),
        tags: ['networking', 'protocols', 'infrastructure'],
      ),
      
      LessonTemplate(
        id: 'security_basics',
        title: 'Cybersecurity Fundamentals',
        description: 'Template for cybersecurity topics with threats and defenses',
        category: 'IT & Technology',
        difficulty: 'intermediate',
        estimatedDuration: 55,
        contentStructure: {
          'terms': 7,
          'concepts': 4,
          'mcqs': 6,
        },
        template: _getSecurityTemplate(),
        tags: ['security', 'cybersecurity', 'threats', 'defense'],
      ),
    ];
  }

  /// Get templates for science subjects
  static List<LessonTemplate> getScienceTemplates() {
    return [
      LessonTemplate(
        id: 'scientific_concept',
        title: 'Scientific Concept Exploration',
        description: 'Template for explaining scientific concepts with examples and applications',
        category: 'Science',
        difficulty: 'intermediate',
        estimatedDuration: 40,
        contentStructure: {
          'terms': 5,
          'concepts': 4,
          'mcqs': 4,
        },
        template: _getScientificConceptTemplate(),
        tags: ['science', 'concept', 'theory', 'application'],
      ),
    ];
  }

  /// Get templates for certification preparation
  static List<LessonTemplate> getCertificationTemplates() {
    return [
      LessonTemplate(
        id: 'comptia_topic',
        title: 'CompTIA Exam Topic',
        description: 'Template for CompTIA certification topics with exam-focused content',
        category: 'Certification',
        difficulty: 'intermediate',
        estimatedDuration: 60,
        contentStructure: {
          'terms': 8,
          'concepts': 3,
          'mcqs': 7,
        },
        template: _getCompTIATemplate(),
        tags: ['comptia', 'certification', 'exam-prep'],
      ),
      
      LessonTemplate(
        id: 'aws_service',
        title: 'AWS Service Deep Dive',
        description: 'Template for AWS services with features and use cases',
        category: 'Certification',
        difficulty: 'intermediate',
        estimatedDuration: 50,
        contentStructure: {
          'terms': 6,
          'concepts': 4,
          'mcqs': 5,
        },
        template: _getAWSTemplate(),
        tags: ['aws', 'cloud', 'certification'],
      ),
    ];
  }

  /// Get general-purpose templates
  static List<LessonTemplate> getGeneralTemplates() {
    return [
      LessonTemplate(
        id: 'basic_introduction',
        title: 'Basic Topic Introduction',
        description: 'Simple template for introducing any new topic',
        category: 'General',
        difficulty: 'beginner',
        estimatedDuration: 30,
        contentStructure: {
          'terms': 4,
          'concepts': 3,
          'mcqs': 3,
        },
        template: _getBasicTemplate(),
        tags: ['general', 'introduction', 'basic'],
      ),
      
      LessonTemplate(
        id: 'comprehensive_study',
        title: 'Comprehensive Topic Study',
        description: 'Detailed template for in-depth topic coverage',
        category: 'General',
        difficulty: 'intermediate',
        estimatedDuration: 75,
        contentStructure: {
          'terms': 8,
          'concepts': 6,
          'mcqs': 8,
        },
        template: _getComprehensiveTemplate(),
        tags: ['general', 'comprehensive', 'detailed'],
      ),
    ];
  }

  // Template JSON generators
  static Map<String, dynamic> _getProgrammingLanguageTemplate() {
    return {
      'lesson': {
        'title': '[LANGUAGE_NAME] Programming Basics',
        'description': 'Learn the fundamental syntax and concepts of [LANGUAGE_NAME] programming language.',
        'estimated_duration_minutes': 45,
        'difficulty_level': 'beginner',
        'tags': ['[LANGUAGE_NAME]', 'programming', 'syntax', 'basics']
      },
      'content': [
        {
          'type': 'term',
          'title': '[LANGUAGE_NAME]',
          'content': 'A [TYPE] programming language designed for [PURPOSE].',
          'example': '[SIMPLE_EXAMPLE]'
        },
        {
          'type': 'term',
          'title': 'Variable',
          'content': 'A named storage location that holds a value in [LANGUAGE_NAME].',
          'example': '[VARIABLE_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Basic Syntax',
          'content': 'The fundamental rules and structure for writing [LANGUAGE_NAME] code.',
          'key_points': [
            '[SYNTAX_RULE_1]',
            '[SYNTAX_RULE_2]',
            '[SYNTAX_RULE_3]'
          ]
        },
        {
          'type': 'mcq',
          'question': 'Which of the following is the correct way to [BASIC_OPERATION] in [LANGUAGE_NAME]?',
          'options': ['[OPTION_1]', '[OPTION_2]', '[OPTION_3]', '[OPTION_4]'],
          'correct_answer': '[CORRECT_OPTION]',
          'explanation': '[EXPLANATION]'
        }
      ]
    };
  }

  static Map<String, dynamic> _getDataStructureTemplate() {
    return {
      'lesson': {
        'title': '[DATA_STRUCTURE] Data Structure',
        'description': 'Understand the [DATA_STRUCTURE] data structure, its operations, and practical applications.',
        'estimated_duration_minutes': 60,
        'difficulty_level': 'intermediate',
        'tags': ['data-structures', '[DATA_STRUCTURE]', 'algorithms']
      },
      'content': [
        {
          'type': 'term',
          'title': '[DATA_STRUCTURE]',
          'content': 'A [DESCRIPTION] data structure that [MAIN_CHARACTERISTIC].',
          'example': '[VISUAL_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Operations',
          'content': 'Common operations performed on [DATA_STRUCTURE] data structures.',
          'key_points': [
            '[OPERATION_1]: [DESCRIPTION_1]',
            '[OPERATION_2]: [DESCRIPTION_2]',
            '[OPERATION_3]: [DESCRIPTION_3]'
          ]
        },
        {
          'type': 'concept',
          'title': 'Time Complexity',
          'content': 'Analysis of the efficiency of [DATA_STRUCTURE] operations.',
          'key_points': [
            'Insertion: [TIME_COMPLEXITY]',
            'Deletion: [TIME_COMPLEXITY]',
            'Search: [TIME_COMPLEXITY]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getAlgorithmTemplate() {
    return {
      'lesson': {
        'title': '[ALGORITHM_NAME] Algorithm',
        'description': 'Deep dive into the [ALGORITHM_NAME] algorithm, its implementation, and complexity analysis.',
        'estimated_duration_minutes': 75,
        'difficulty_level': 'advanced',
        'tags': ['algorithms', '[ALGORITHM_NAME]', 'complexity', 'optimization']
      },
      'content': [
        {
          'type': 'term',
          'title': '[ALGORITHM_NAME]',
          'content': 'An algorithm that [PURPOSE] by [METHOD].',
          'example': '[SIMPLE_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Algorithm Steps',
          'content': 'Step-by-step breakdown of the [ALGORITHM_NAME] algorithm.',
          'key_points': [
            'Step 1: [STEP_DESCRIPTION]',
            'Step 2: [STEP_DESCRIPTION]',
            'Step 3: [STEP_DESCRIPTION]'
          ]
        },
        {
          'type': 'concept',
          'title': 'Complexity Analysis',
          'content': 'Time and space complexity analysis of [ALGORITHM_NAME].',
          'key_points': [
            'Time Complexity: [BIG_O_TIME]',
            'Space Complexity: [BIG_O_SPACE]',
            'Best Case: [BEST_CASE]',
            'Worst Case: [WORST_CASE]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getNetworkingTemplate() {
    return {
      'lesson': {
        'title': '[NETWORK_TOPIC] Fundamentals',
        'description': 'Comprehensive overview of [NETWORK_TOPIC] in computer networking.',
        'estimated_duration_minutes': 50,
        'difficulty_level': 'intermediate',
        'tags': ['networking', '[NETWORK_TOPIC]', 'protocols', 'infrastructure']
      },
      'content': [
        {
          'type': 'term',
          'title': '[PROTOCOL_NAME]',
          'content': 'A [LAYER] layer protocol that [PURPOSE].',
          'example': '[PROTOCOL_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'How [NETWORK_TOPIC] Works',
          'content': 'Detailed explanation of [NETWORK_TOPIC] operation and mechanisms.',
          'key_points': [
            '[MECHANISM_1]',
            '[MECHANISM_2]',
            '[MECHANISM_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getSecurityTemplate() {
    return {
      'lesson': {
        'title': '[SECURITY_TOPIC] Security',
        'description': 'Understanding [SECURITY_TOPIC] threats, vulnerabilities, and protection measures.',
        'estimated_duration_minutes': 55,
        'difficulty_level': 'intermediate',
        'tags': ['security', 'cybersecurity', '[SECURITY_TOPIC]', 'threats']
      },
      'content': [
        {
          'type': 'term',
          'title': '[THREAT_TYPE]',
          'content': 'A type of security threat that [THREAT_DESCRIPTION].',
          'example': '[THREAT_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Protection Strategies',
          'content': 'Methods and techniques to protect against [SECURITY_TOPIC] threats.',
          'key_points': [
            '[PROTECTION_1]',
            '[PROTECTION_2]',
            '[PROTECTION_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getScientificConceptTemplate() {
    return {
      'lesson': {
        'title': '[SCIENTIFIC_CONCEPT]',
        'description': 'Explore the scientific concept of [SCIENTIFIC_CONCEPT] and its real-world applications.',
        'estimated_duration_minutes': 40,
        'difficulty_level': 'intermediate',
        'tags': ['science', '[FIELD]', '[SCIENTIFIC_CONCEPT]']
      },
      'content': [
        {
          'type': 'term',
          'title': '[SCIENTIFIC_CONCEPT]',
          'content': '[DEFINITION] that explains [PHENOMENON].',
          'example': '[REAL_WORLD_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Applications',
          'content': 'Practical applications of [SCIENTIFIC_CONCEPT] in various fields.',
          'key_points': [
            '[APPLICATION_1]',
            '[APPLICATION_2]',
            '[APPLICATION_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getCompTIATemplate() {
    return {
      'lesson': {
        'title': '[COMPTIA_TOPIC]',
        'description': 'CompTIA exam preparation covering [COMPTIA_TOPIC] concepts and practical applications.',
        'estimated_duration_minutes': 60,
        'difficulty_level': 'intermediate',
        'tags': ['comptia', 'certification', '[EXAM_CODE]', '[DOMAIN]']
      },
      'content': [
        {
          'type': 'term',
          'title': '[TECHNICAL_TERM]',
          'content': '[DEFINITION] used in [CONTEXT].',
          'example': '[PRACTICAL_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Best Practices',
          'content': 'Industry best practices for [COMPTIA_TOPIC] implementation.',
          'key_points': [
            '[BEST_PRACTICE_1]',
            '[BEST_PRACTICE_2]',
            '[BEST_PRACTICE_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getAWSTemplate() {
    return {
      'lesson': {
        'title': '[AWS_SERVICE]',
        'description': 'Comprehensive guide to [AWS_SERVICE] features, use cases, and best practices.',
        'estimated_duration_minutes': 50,
        'difficulty_level': 'intermediate',
        'tags': ['aws', 'cloud', '[SERVICE_CATEGORY]', '[AWS_SERVICE]']
      },
      'content': [
        {
          'type': 'term',
          'title': '[AWS_SERVICE]',
          'content': 'An AWS service that provides [SERVICE_DESCRIPTION].',
          'example': '[USE_CASE_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Key Features',
          'content': 'Important features and capabilities of [AWS_SERVICE].',
          'key_points': [
            '[FEATURE_1]',
            '[FEATURE_2]',
            '[FEATURE_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getBasicTemplate() {
    return {
      'lesson': {
        'title': '[TOPIC_NAME] Introduction',
        'description': 'Basic introduction to [TOPIC_NAME] covering fundamental concepts.',
        'estimated_duration_minutes': 30,
        'difficulty_level': 'beginner',
        'tags': ['[CATEGORY]', '[TOPIC_NAME]', 'introduction']
      },
      'content': [
        {
          'type': 'term',
          'title': '[KEY_TERM]',
          'content': '[SIMPLE_DEFINITION].',
          'example': '[BASIC_EXAMPLE]'
        },
        {
          'type': 'concept',
          'title': 'Overview',
          'content': 'Basic overview of [TOPIC_NAME] and its importance.',
          'key_points': [
            '[KEY_POINT_1]',
            '[KEY_POINT_2]',
            '[KEY_POINT_3]'
          ]
        }
      ]
    };
  }

  static Map<String, dynamic> _getComprehensiveTemplate() {
    return {
      'lesson': {
        'title': '[TOPIC_NAME] Comprehensive Study',
        'description': 'In-depth exploration of [TOPIC_NAME] with detailed analysis and examples.',
        'estimated_duration_minutes': 75,
        'difficulty_level': 'intermediate',
        'tags': ['[CATEGORY]', '[TOPIC_NAME]', 'comprehensive', 'detailed']
      },
      'content': [
        {
          'type': 'term',
          'title': '[TERM_1]',
          'content': '[DETAILED_DEFINITION_1].',
          'example': '[EXAMPLE_1]'
        },
        {
          'type': 'term',
          'title': '[TERM_2]',
          'content': '[DETAILED_DEFINITION_2].',
          'example': '[EXAMPLE_2]'
        },
        {
          'type': 'concept',
          'title': 'Core Concepts',
          'content': 'Fundamental concepts underlying [TOPIC_NAME].',
          'key_points': [
            '[CONCEPT_1]',
            '[CONCEPT_2]',
            '[CONCEPT_3]'
          ]
        },
        {
          'type': 'concept',
          'title': 'Advanced Applications',
          'content': 'Advanced applications and use cases of [TOPIC_NAME].',
          'key_points': [
            '[APPLICATION_1]',
            '[APPLICATION_2]',
            '[APPLICATION_3]'
          ]
        }
      ]
    };
  }
}

/// Data model for lesson templates
class LessonTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final int estimatedDuration;
  final Map<String, int> contentStructure;
  final Map<String, dynamic> template;
  final List<String> tags;

  LessonTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.estimatedDuration,
    required this.contentStructure,
    required this.template,
    required this.tags,
  });

  /// Generate a customized template with placeholders filled
  Map<String, dynamic> generateCustomTemplate(Map<String, String> placeholders) {
    String templateJson = jsonEncode(template);
    
    // Replace all placeholders in the template
    placeholders.forEach((placeholder, value) {
      templateJson = templateJson.replaceAll('[$placeholder]', value);
    });
    
    return jsonDecode(templateJson);
  }

  /// Get all placeholders in this template
  List<String> getPlaceholders() {
    final templateJson = jsonEncode(template);
    final regex = RegExp(r'\[([A-Z_]+)\]');
    final matches = regex.allMatches(templateJson);
    
    return matches.map((match) => match.group(1)!).toSet().toList();
  }

  /// Get suggested values for placeholders based on template type
  Map<String, List<String>> getPlaceholderSuggestions() {
    Map<String, List<String>> suggestions = {};
    
    if (category == 'Programming') {
      suggestions['LANGUAGE_NAME'] = ['Python', 'JavaScript', 'Java', 'C++', 'Go', 'Rust'];
      suggestions['TYPE'] = ['interpreted', 'compiled', 'hybrid'];
      suggestions['PURPOSE'] = ['web development', 'data science', 'system programming'];
    }
    
    if (category == 'IT & Technology') {
      suggestions['PROTOCOL_NAME'] = ['HTTP', 'TCP', 'UDP', 'DNS', 'DHCP'];
      suggestions['LAYER'] = ['application', 'transport', 'network', 'data link'];
    }
    
    // Add more category-specific suggestions
    return suggestions;
  }
}
