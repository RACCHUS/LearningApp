import 'dart:convert';
import 'dart:io';
import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';
import 'learning_data_source.dart';

dynamic _yamlToDart(dynamic node) {
  if (node is YamlMap) {
    return node.map((key, value) => MapEntry(key.toString(), _yamlToDart(value)));
  } else if (node is YamlList) {
    return node.map(_yamlToDart).toList();
  }
  return node;
}

class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> arguments) handler;

  McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }
}

class McpToolsRegistry {
  final LearningDataSource dataSource;
  final Map<String, McpToolDefinition> _tools = {};

  McpToolsRegistry({required this.dataSource}) {
    _registerAllTools();
  }

  List<Map<String, dynamic>> listTools() {
    return _tools.values.map((t) => t.toJson()).toList();
  }

  Future<Map<String, dynamic>> callTool(String name, Map<String, dynamic> arguments) async {
    final tool = _tools[name];
    if (tool == null) {
      return {
        'content': [
          {
            'type': 'text',
            'text': 'Error: Unknown tool "$name".',
          }
        ],
        'isError': true,
      };
    }

    try {
      final result = await tool.handler(arguments);
      return {
        'content': [
          {
            'type': 'text',
            'text': jsonEncode(result),
          }
        ],
        'isError': false,
      };
    } catch (e, st) {
      return {
        'content': [
          {
            'type': 'text',
            'text': 'Tool execution failed: $e\n$st',
          }
        ],
        'isError': true,
      };
    }
  }

  void _registerTool(McpToolDefinition tool) {
    _tools[tool.name] = tool;
  }

  void _registerAllTools() {
    // 1. search_catalog
    _registerTool(McpToolDefinition(
      name: 'search_catalog',
      description: 'Find learning targets, certifications, degrees, and career pathways in the LearningApp catalog.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Search keyword or title phrase (e.g. "security", "nursing", "computer science").',
          },
          'category': {
            'type': 'string',
            'description': 'Filter by category (certification, degree, career_pathway, licensure).',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum number of items to return (default 10).',
          },
        },
      },
      handler: (args) async {
        final query = args['query'] as String?;
        final category = args['category'] as String?;
        final limit = (args['limit'] as num?)?.toInt() ?? 10;
        final items = await dataSource.searchCatalog(query: query, category: category, limit: limit);
        return {
          'count': items.length,
          'results': items,
        };
      },
    ));

    // 2. get_target_outline
    _registerTool(McpToolDefinition(
      name: 'get_target_outline',
      description: 'Retrieve the curriculum outline and competency hierarchy for a learning target (domains, nodes, concepts, and weights).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target_slug': {
            'type': 'string',
            'description': 'The target slug or ID (e.g. "cert-comptia-security-plus", "bs-computer-science").',
          },
          'version': {
            'type': 'string',
            'description': 'Optional target version code (e.g. "SY0-701").',
          },
        },
        'required': ['target_slug'],
      },
      handler: (args) async {
        final slug = args['target_slug'] as String;
        final version = args['version'] as String?;
        final outline = await dataSource.getTargetOutline(slug, version: version);
        if (outline == null) {
          return {
            'error': 'Learning target not found: $slug',
          };
        }
        return outline;
      },
    ));

    // 3. get_exam_blueprint
    _registerTool(McpToolDefinition(
      name: 'get_exam_blueprint',
      description: 'Retrieve the authoritative examination blueprint, domain weights, passing score, and question constraints for a target.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'target_version_id': {
            'type': 'string',
            'description': 'Target version UUID or target slug (e.g. "cert-comptia-security-plus").',
          },
        },
        'required': ['target_version_id'],
      },
      handler: (args) async {
        final targetId = args['target_version_id'] as String;
        final blueprint = await dataSource.getExamBlueprint(targetId);
        if (blueprint == null) {
          return {
            'error': 'Blueprint not found for target: $targetId',
          };
        }
        return blueprint;
      },
    ));

    // 4. get_learner_state
    _registerTool(McpToolDefinition(
      name: 'get_learner_state',
      description: 'Evaluate learner readiness using server-calibrated FSRS retrievability, due counts, and weakest concept analysis.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'user_id': {
            'type': 'string',
            'description': 'Learner user UUID.',
          },
          'target_version_id': {
            'type': 'string',
            'description': 'Target version UUID or target slug.',
          },
          'exam_date': {
            'type': 'string',
            'description': 'Optional ISO-8601 target examination date for FSRS retrievability projection.',
          },
        },
        'required': ['user_id', 'target_version_id'],
      },
      handler: (args) async {
        final userId = args['user_id'] as String;
        final targetId = args['target_version_id'] as String;
        DateTime? examDate;
        if (args['exam_date'] != null) {
          examDate = DateTime.tryParse(args['exam_date'] as String);
        }
        return await dataSource.getLearnerState(
          userId: userId,
          targetVersionId: targetId,
          examDate: examDate,
        );
      },
    ));

    // 5. get_due_items
    _registerTool(McpToolDefinition(
      name: 'get_due_items',
      description: 'Retrieve items currently due for spaced repetition review based on FSRS memory scheduling.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'user_id': {
            'type': 'string',
            'description': 'Learner user UUID.',
          },
          'target_id': {
            'type': 'string',
            'description': 'Optional target identifier to filter review items.',
          },
          'limit': {
            'type': 'integer',
            'description': 'Maximum review items to retrieve (default 10).',
          },
        },
        'required': ['user_id'],
      },
      handler: (args) async {
        final userId = args['user_id'] as String;
        final targetId = args['target_id'] as String?;
        final limit = (args['limit'] as num?)?.toInt() ?? 10;
        final items = await dataSource.getDueItems(
          userId: userId,
          targetId: targetId,
          limit: limit,
        );
        return {
          'user_id': userId,
          'due_count': items.length,
          'items': items,
        };
      },
    ));

    // 6. explain_item
    _registerTool(McpToolDefinition(
      name: 'explain_item',
      description: 'Retrieve question prompt, options, correct answer, explanation, and official source citations for grounded AI tutoring.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'item_id': {
            'type': 'string',
            'description': 'The assessment item or question identifier.',
          },
        },
        'required': ['item_id'],
      },
      handler: (args) async {
        final itemId = args['item_id'] as String;
        final explanation = await dataSource.explainItem(itemId);
        return explanation ?? {'error': 'Item not found: $itemId'};
      },
    ));

    // 7. compute_item_analytics
    _registerTool(McpToolDefinition(
      name: 'compute_item_analytics',
      description: 'Inspect Classical Test Theory facility p-value, point-biserial discrimination r_pbis, distractor rates, and defect flags.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'item_id': {
            'type': 'string',
            'description': 'Assessment item UUID.',
          },
        },
        'required': ['item_id'],
      },
      handler: (args) async {
        final itemId = args['item_id'] as String;
        return await dataSource.getItemAnalytics(itemId);
      },
    ));

    // 8. submit_review
    _registerTool(McpToolDefinition(
      name: 'submit_review',
      description: 'Record a learning review event into the evidence pipeline with strict provenance auditing (origin: ai_generated or user_import).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'user_id': {
            'type': 'string',
            'description': 'Learner user UUID.',
          },
          'item_id': {
            'type': 'string',
            'description': 'Reviewed item UUID.',
          },
          'rating': {
            'type': 'integer',
            'description': 'FSRS review rating (1 = Again, 2 = Hard, 3 = Good, 4 = Easy).',
          },
          'response_option_id': {
            'type': 'string',
            'description': 'Selected option ID or submitted response string.',
          },
          'latency_ms': {
            'type': 'integer',
            'description': 'Learner response time in milliseconds.',
          },
          'client_id': {
            'type': 'string',
            'description': 'Origin client identifier (e.g. "mcp:claude", "mcp:cursor").',
          },
        },
        'required': ['user_id', 'item_id', 'rating'],
      },
      handler: (args) async {
        final userId = args['user_id'] as String;
        final itemId = args['item_id'] as String;
        final rating = (args['rating'] as num).toInt();
        final responseOptionId = args['response_option_id'] as String?;
        final latencyMs = (args['latency_ms'] as num?)?.toInt();
        final clientId = (args['client_id'] as String?) ?? 'mcp:agent';

        return await dataSource.submitReview(
          userId: userId,
          itemId: itemId,
          rating: rating,
          responseOptionId: responseOptionId,
          latencyMs: latencyMs,
          clientId: clientId,
        );
      },
    ));

    // 9. validate_lesson
    _registerTool(McpToolDefinition(
      name: 'validate_lesson',
      description: 'Validate lesson or curriculum manifest against formal JSON Schema and Haladyna (2002) psychometric quality rules.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'content': {
            'description': 'Lesson content as JSON string, YAML string, or JSON object.',
          },
        },
        'required': ['content'],
      },
      handler: (args) async {
        final dynamic rawContent = args['content'];
        Map<String, dynamic> manifest;
        if (rawContent is Map) {
          manifest = rawContent.cast<String, dynamic>();
        } else if (rawContent is String) {
          try {
            final decoded = jsonDecode(rawContent);
            manifest = (decoded as Map).cast<String, dynamic>();
          } catch (_) {
            final dynamic yamlNode = loadYaml(rawContent);
            manifest = (_yamlToDart(yamlNode) as Map).cast<String, dynamic>();
          }
        } else {
          return {'is_valid': false, 'error': 'Invalid content format; expected string or object'};
        }

        return _validateManifest(manifest);
      },
    ));

    // 10. propose_item_fix
    _registerTool(McpToolDefinition(
      name: 'propose_item_fix',
      description: 'Submit an item defect report or suggested question correction to the LearningApp moderation queue.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'item_id': {
            'type': 'string',
            'description': 'The assessment item UUID.',
          },
          'reason': {
            'type': 'string',
            'description': 'Reason for modification (e.g. "outdated_statute", "factual_error", "ambiguous_stem", "poor_distractor").',
          },
          'suggested_stem': {
            'type': 'string',
            'description': 'Optional replacement question stem.',
          },
          'suggested_options': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional replacement options.',
          },
          'suggested_explanation': {
            'type': 'string',
            'description': 'Optional updated rationale / explanation.',
          },
        },
        'required': ['item_id', 'reason'],
      },
      handler: (args) async {
        final itemId = args['item_id'] as String;
        final reason = args['reason'] as String;
        final stem = args['suggested_stem'] as String?;
        final options = (args['suggested_options'] as List?)?.cast<String>();
        final explanation = args['suggested_explanation'] as String?;

        return await dataSource.proposeItemFix(
          itemId: itemId,
          reason: reason,
          suggestedStem: stem,
          suggestedOptions: options,
          suggestedExplanation: explanation,
        );
      },
    ));
  }

  Map<String, dynamic> _validateManifest(Map<String, dynamic> manifest) {
    final issues = <Map<String, dynamic>>[];

    // 1. Schema check if schema file exists
    final schemaFile = File('content/schema/curriculum_manifest.schema.json');
    if (schemaFile.existsSync()) {
      try {
        final schemaJson = jsonDecode(schemaFile.readAsStringSync());
        final schema = JsonSchema.create(schemaJson);
        final valRes = schema.validate(manifest);
        if (!valRes.isValid) {
          for (final err in valRes.errors) {
            issues.add({
              'rule': 'JSON_SCHEMA',
              'severity': 'ERROR',
              'message': err.message,
              'path': err.instancePath.toString(),
            });
          }
        }
      } catch (e) {
        issues.add({
          'rule': 'SCHEMA_VALIDATOR',
          'severity': 'WARNING',
          'message': 'Failed to execute JSON schema validator: $e',
        });
      }
    }

    // 2. Haladyna (2002) Item Writing Checks
    final negativeStemRegex = RegExp(r'\b(NOT|EXCEPT|LEAST)\b');
    final allNoneRegex = RegExp(r'\b(all of the above|none of the above)\b', caseSensitive: false);

    void checkQuestion(String prompt, List<dynamic> options, dynamic correctChoice, String location) {
      // Check negative stem
      if (negativeStemRegex.hasMatch(prompt)) {
        issues.add({
          'rule': 'HALADYNA_NEGATIVE_STEM',
          'severity': 'WARNING',
          'location': location,
          'message': 'Negative stem detected ("NOT", "EXCEPT", "LEAST"). Best practice recommends positive framing.',
        });
      }

      // Check all/none of the above
      for (final opt in options) {
        final optStr = opt is Map ? (opt['text'] ?? '').toString() : opt.toString();
        if (allNoneRegex.hasMatch(optStr)) {
          issues.add({
            'rule': 'HALADYNA_ALL_NONE_ABOVE',
            'severity': 'ERROR',
            'location': location,
            'message': 'Avoid "All of the above" or "None of the above" as distractors.',
          });
        }
      }

      // Check length cues (if 3+ options)
      if (options.length >= 3) {
        final lengths = options.map((o) {
          final s = o is Map ? (o['text'] ?? '').toString() : o.toString();
          return s.length;
        }).toList();

        final avgLen = lengths.reduce((a, b) => a + b) / lengths.length;
        int? correctIdx;
        if (correctChoice is int) {
          correctIdx = correctChoice;
        } else if (correctChoice is String) {
          correctIdx = int.tryParse(correctChoice);
        }

        if (correctIdx != null && correctIdx >= 0 && correctIdx < lengths.length) {
          final correctLen = lengths[correctIdx];
          if (avgLen > 15 && correctLen > avgLen * 2.0) {
            issues.add({
              'rule': 'HALADYNA_LENGTH_CUE',
              'severity': 'WARNING',
              'location': location,
              'message': 'Correct answer is more than double the average distractor length (possible visual cue).',
            });
          }
        }
      }
    }

    // Inspect content items if simple format or curriculum manifest
    if (manifest.containsKey('content') && manifest['content'] is List) {
      final contentList = manifest['content'] as List;
      for (int i = 0; i < contentList.length; i++) {
        final item = contentList[i];
        if (item is Map && (item['type'] == 'mcq' || item['type'] == 'question')) {
          final prompt = (item['question'] ?? item['prompt'] ?? '').toString();
          final options = (item['options'] as List?) ?? [];
          final correctChoice = item['correctIndex'] ?? item['correct_answer'];
          checkQuestion(prompt, options, correctChoice, 'content[$i]');
        }
      }
    }

    if (manifest.containsKey('domains') && manifest['domains'] is List) {
      final domains = manifest['domains'] as List;
      for (int d = 0; d < domains.length; d++) {
        final domain = domains[d];
        if (domain is! Map) continue;
        final nodes = domain['nodes'] as List? ?? [];
        for (int n = 0; n < nodes.length; n++) {
          final node = nodes[n];
          if (node is! Map) continue;
          final items = node['assessment_items'] as List? ?? [];
          for (int it = 0; it < items.length; it++) {
            final item = items[it];
            if (item is! Map) continue;
            final prompt = (item['prompt'] ?? '').toString();
            final options = (item['response_spec']?['options'] as List?) ?? [];
            final correct = item['scoring_spec']?['correct_answer'];
            checkQuestion(prompt, options, correct, 'domains[$d].nodes[$n].assessment_items[$it]');
          }
        }
      }
    }

    final hasErrors = issues.any((i) => i['severity'] == 'ERROR');
    return {
      'is_valid': !hasErrors,
      'status': hasErrors ? 'FAILED' : (issues.isEmpty ? 'PASSED_CLEAN' : 'PASSED_WITH_WARNINGS'),
      'issue_count': issues.length,
      'issues': issues,
    };
  }
}
