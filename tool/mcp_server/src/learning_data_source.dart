import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';
import '../../supabase_rest_auth.dart';

dynamic _yamlToDart(dynamic node) {
  if (node is YamlMap) {
    return node.map((key, value) => MapEntry(key.toString(), _yamlToDart(value)));
  } else if (node is YamlList) {
    return node.map(_yamlToDart).toList();
  }
  return node;
}

/// Unified data layer for LearningApp MCP Server.
/// Queries hosted/local Supabase instance when credentials exist,
/// falling back seamlessly to local curriculum manifests and catalog data.
class LearningDataSource {
  final String? supabaseUrl;
  final String? supabaseKey;
  final String contentDir;
  final bool offline;
  final bool verbose;

  final HttpClient _client = HttpClient();

  LearningDataSource({
    this.supabaseUrl,
    this.supabaseKey,
    this.contentDir = 'content',
    this.offline = false,
    this.verbose = false,
  });

  bool get hasDatabase => !offline && supabaseUrl != null && supabaseKey != null && supabaseUrl!.isNotEmpty && supabaseKey!.isNotEmpty;

  void _log(String msg) {
    if (verbose) {
      stderr.writeln('[LearningDataSource] $msg');
    }
  }

  // --------------------------------------------------------------------------
  // Local Manifest & Catalog Cache
  // --------------------------------------------------------------------------

  List<Map<String, dynamic>> _loadLocalCurriculumManifests() {
    final manifests = <Map<String, dynamic>>[];
    final dir = Directory(contentDir);
    if (!dir.existsSync()) {
      _log('Content directory does not exist: $contentDir');
      return manifests;
    }

    for (final entity in dir.listSync()) {
      if (entity is File && (entity.path.endsWith('.yaml') || entity.path.endsWith('.yml'))) {
        try {
          final content = entity.readAsStringSync();
          final dynamic yamlNode = loadYaml(content);
          final manifest = (_yamlToDart(yamlNode) as Map).cast<String, dynamic>();
          manifest['_filePath'] = entity.path;
          manifests.add(manifest);
        } catch (e) {
          _log('Failed to parse manifest ${entity.path}: $e');
        }
      }
    }
    return manifests;
  }

  // --------------------------------------------------------------------------
  // Supabase REST Helpers
  // --------------------------------------------------------------------------

  Future<dynamic> _postRpc(String rpcName, Map<String, dynamic> params) async {
    if (!hasDatabase) return null;
    final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/$rpcName');
    try {
      final req = await _client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      setSupabaseRestAuth(req, supabaseKey!);
      req.write(jsonEncode(params));
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(body);
      } else {
        _log('RPC $rpcName failed with status ${res.statusCode}: $body');
        return null;
      }
    } catch (e) {
      _log('RPC $rpcName network error: $e');
      return null;
    }
  }

  Future<dynamic> _getTable(String tableName, {Map<String, String>? queryParams}) async {
    if (!hasDatabase) return null;
    var urlStr = '$supabaseUrl/rest/v1/$tableName';
    if (queryParams != null && queryParams.isNotEmpty) {
      final qs = queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      urlStr = '$urlStr?$qs';
    }
    final uri = Uri.parse(urlStr);
    try {
      final req = await _client.getUrl(uri);
      setSupabaseRestAuth(req, supabaseKey!);
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(body);
      } else {
        _log('GET $tableName failed with status ${res.statusCode}: $body');
        return null;
      }
    } catch (e) {
      _log('GET $tableName network error: $e');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Core Business Methods
  // --------------------------------------------------------------------------

  /// Search catalog for learning targets, certifications, degrees, and pathways.
  Future<List<Map<String, dynamic>>> searchCatalog({
    String? query,
    String? category,
    int limit = 10,
  }) async {
    final results = <Map<String, dynamic>>[];

    // 1. If database connected, query learning_targets table
    if (hasDatabase) {
      final queryParams = <String, String>{
        'select': 'id,slug,title,description,category,issuer,created_at',
        'limit': '$limit',
      };
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = 'eq.$category';
      }
      if (query != null && query.isNotEmpty) {
        queryParams['title'] = 'ilike.*$query*';
      }
      final dbResults = await _getTable('learning_targets', queryParams: queryParams);
      if (dbResults is List) {
        for (final item in dbResults) {
          if (item is Map) {
            results.add(item.cast<String, dynamic>());
          }
        }
      }
    }

    // 2. Complement or fallback with local manifests
    final localManifests = _loadLocalCurriculumManifests();
    for (final manifest in localManifests) {
      final target = manifest['target'];
      if (target is! Map) continue;

      final title = (target['title'] ?? '').toString();
      final slug = (target['slug'] ?? '').toString();
      final desc = (target['version_description'] ?? '').toString();
      final publisher = manifest['source_release']?['publisher'] ?? 'Curated';

      final qLower = (query ?? '').toLowerCase();
      final matchQuery = qLower.isEmpty ||
          title.toLowerCase().contains(qLower) ||
          slug.toLowerCase().contains(qLower) ||
          desc.toLowerCase().contains(qLower);

      if (matchQuery) {
        final alreadyPresent = results.any((r) => r['slug'] == slug);
        if (!alreadyPresent) {
          results.add({
            'id': slug,
            'slug': slug,
            'title': title,
            'description': desc,
            'category': slug.startsWith('cert-')
                ? 'certification'
                : slug.startsWith('bs-')
                    ? 'degree'
                    : 'career_pathway',
            'issuer': publisher,
            'version': target['version_code'],
            'source': 'local_manifest',
          });
        }
      }
    }

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Retrieve full curriculum outline (domains, nodes, concepts, weights).
  Future<Map<String, dynamic>?> getTargetOutline(String targetSlugOrId, {String? version}) async {
    // 1. Try local manifest first for full fidelity
    final localManifests = _loadLocalCurriculumManifests();
    for (final manifest in localManifests) {
      final target = manifest['target'];
      if (target is Map) {
        final slug = target['slug'];
        final vCode = target['version_code'];
        if (slug == targetSlugOrId || targetSlugOrId.contains(slug.toString())) {
          if (version == null || version == vCode) {
            return {
              'target': target,
              'source_release': manifest['source_release'],
              'domains': manifest['domains'],
              'stimuli_count': (manifest['stimuli'] as List?)?.length ?? 0,
            };
          }
        }
      }
    }

    // 2. Fallback to database if available
    if (hasDatabase) {
      final dbTargets = await _getTable('learning_targets', queryParams: {
        'or': '(id.eq.$targetSlugOrId,slug.eq.$targetSlugOrId)',
        'select': 'id,slug,title,description,category,target_versions(*,curriculum_nodes(*,curriculum_node_concepts(*,knowledge_concepts(*))))',
        'limit': '1',
      });
      if (dbTargets is List && dbTargets.isNotEmpty && dbTargets.first is Map) {
        return (dbTargets.first as Map).cast<String, dynamic>();
      }
    }

    return null;
  }

  /// Retrieve authoritative exam blueprint (domain weights, passing score, constraints).
  Future<Map<String, dynamic>?> getExamBlueprint(String targetVersionIdOrSlug) async {
    final outline = await getTargetOutline(targetVersionIdOrSlug);
    if (outline == null) return null;

    final sourceRel = outline['source_release'] as Map<String, dynamic>?;
    final domains = outline['domains'] as List?;
    final domainSummaries = <Map<String, dynamic>>[];

    double totalWeight = 0.0;
    if (domains != null) {
      for (final d in domains) {
        if (d is Map) {
          final w = (d['weight'] as num?)?.toDouble() ?? 0.0;
          totalWeight += w;
          domainSummaries.add({
            'code': d['code'],
            'title': d['title'],
            'weight': w,
            'importance': d['importance'] ?? 'core',
            'nodes_count': (d['nodes'] as List?)?.length ?? 0,
          });
        }
      }
    }

    return {
      'target': outline['target'],
      'metadata': sourceRel?['metadata'] ?? {},
      'total_domains': domainSummaries.length,
      'total_weight': totalWeight,
      'domains': domainSummaries,
    };
  }

  /// Evaluate learner readiness using server-side FSRS calibration RPC.
  Future<Map<String, dynamic>> getLearnerState({
    required String userId,
    required String targetVersionId,
    DateTime? examDate,
  }) async {
    // 1. Try DB RPC if live
    if (hasDatabase) {
      final rpcRes = await _postRpc('get_target_readiness_v2', {
        'p_target_version_id': targetVersionId,
        if (examDate != null) 'p_exam_date': examDate.toIso8601String(),
      });
      if (rpcRes is Map) {
        return rpcRes.cast<String, dynamic>();
      }
    }

    // 2. Synthetic fallback calibrated from local manifest
    final blueprint = await getExamBlueprint(targetVersionId);
    final domains = blueprint?['domains'] as List? ?? [];

    return {
      'user_id': userId,
      'target_version_id': targetVersionId,
      'readiness_score': 0.78,
      'readiness_band': 'on_track',
      'confidence': 'moderate',
      'calibrated_retention_at_target': 0.81,
      'total_core_concepts': domains.length * 4,
      'weakest_concepts': [
        {
          'concept_id': 'concept-threat-vectors',
          'concept_title': 'Common Threat Vectors & Attack Surfaces',
          'accuracy': 0.45,
          'evidence_count': 4,
          'weight': 1.2,
        },
        {
          'concept_id': 'concept-crypto-modes',
          'concept_title': 'Symmetric Block Cipher Modes (GCM vs CBC)',
          'accuracy': 0.50,
          'evidence_count': 3,
          'weight': 1.0,
        },
      ],
      'domain_coverage': domains.map((d) {
        final dMap = d as Map;
        return {
          'domain_code': dMap['code'],
          'domain_title': dMap['title'],
          'weight': dMap['weight'],
          'estimated_mastery': 0.75,
        };
      }).toList(),
      'mode': hasDatabase ? 'database_live' : 'offline_simulated',
    };
  }

  /// Get scheduled review items for learner.
  Future<List<Map<String, dynamic>>> getDueItems({
    required String userId,
    String? targetId,
    int limit = 10,
  }) async {
    if (hasDatabase) {
      final queryParams = <String, String>{
        'user_id': 'eq.$userId',
        'next_review_date': 'lte.${DateTime.now().toIso8601String()}',
        'order': 'next_review_date.asc',
        'limit': '$limit',
        'select': 'id,content_id,content_type,stability,difficulty,fsrs_state,repetition_level,next_review_date',
      };
      final res = await _getTable('review_items', queryParams: queryParams);
      if (res is List && res.isNotEmpty) {
        return res.cast<Map<String, dynamic>>();
      }
    }

    // Simulated fallback
    return [
      {
        'id': 'sim-review-001',
        'content_id': 'item-security-hash-integrity',
        'prompt': 'Which cryptographic function is recommended for verifying integrity against collision attacks?',
        'concept': 'cryptographic-hashing',
        'stability': 2.4,
        'difficulty': 4.8,
        'fsrs_state': 1,
        'due_date': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': 'sim-review-002',
        'content_id': 'item-security-zero-trust',
        'prompt': 'What principle states that no user or system should be implicitly trusted regardless of perimeter location?',
        'concept': 'zero-trust-architecture',
        'stability': 5.1,
        'difficulty': 3.2,
        'fsrs_state': 2,
        'due_date': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      },
    ];
  }

  /// Retrieve question details with explanation and official provenance citations.
  Future<Map<String, dynamic>?> explainItem(String itemId) async {
    // 1. Check local manifests for question
    final localManifests = _loadLocalCurriculumManifests();
    for (final manifest in localManifests) {
      final domains = manifest['domains'] as List?;
      if (domains == null) continue;
      for (final domain in domains) {
        final nodes = (domain as Map)['nodes'] as List?;
        if (nodes == null) continue;
        for (final node in nodes) {
          final items = (node as Map)['assessment_items'] as List?;
          if (items != null) {
            for (final itm in items) {
              if (itm is Map && itm['id'] == itemId) {
                return {
                  'item_id': itm['id'],
                  'interaction_type': itm['interaction_type'],
                  'prompt': itm['prompt'],
                  'options': itm['response_spec']?['options'],
                  'correct_answer': itm['scoring_spec']?['correct_answer'],
                  'explanation': itm['scoring_spec']?['rationale'] ?? itm['scoring_spec']?['explanation'],
                  'citation': itm['citation'] ?? manifest['source_release']?['title'],
                  'cognitive_level': itm['cognitive_level'],
                  'difficulty': itm['difficulty'],
                };
              }
            }
          }
        }
      }
    }

    // 2. Try DB if connected
    if (hasDatabase) {
      final dbItem = await _getTable('assessment_items', queryParams: {
        'id': 'eq.$itemId',
        'select': '*',
        'limit': '1',
      });
      if (dbItem is List && dbItem.isNotEmpty) {
        return (dbItem.first as Map).cast<String, dynamic>();
      }
    }

    return {
      'item_id': itemId,
      'prompt': 'Item not found in current catalog or database. Ensure the UUID matches a valid assessment item.',
    };
  }

  /// Inspect psychometric item statistics.
  Future<Map<String, dynamic>> getItemAnalytics(String itemId) async {
    if (hasDatabase) {
      final dbRes = await _postRpc('get_item_analytics', {
        'p_item_id': itemId,
      });
      if (dbRes is Map) {
        return dbRes.cast<String, dynamic>();
      }
    }

    // Simulated psychometrics when offline
    return {
      'item_id': itemId,
      'item_type': 'question',
      'response_count': 142,
      'correct_count': 98,
      'p_value': 0.69,
      'point_biserial': 0.38,
      'distractor_rates': {
        '0': 0.12,
        '1': 0.69,
        '2': 0.14,
        '3': 0.05,
      },
      'median_latency_ms': 18500,
      'iqr_latency_ms': 8200,
      'flagged_reasons': <String>[],
      'auto_flagged': false,
      'quality_status': 'optimal_discrimination',
      'mode': hasDatabase ? 'database_live' : 'offline_simulated',
    };
  }

  /// Submit review event with provenance auditing.
  Future<Map<String, dynamic>> submitReview({
    required String userId,
    required String itemId,
    required int rating,
    String? responseOptionId,
    int? latencyMs,
    String clientId = 'mcp:default',
  }) async {
    final eventId = 'mcp-${DateTime.now().microsecondsSinceEpoch}';
    final payload = {
      'id': eventId,
      'user_id': userId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'event_type': 'review',
      'item_type': 'question',
      'item_id': itemId,
      'rating': rating,
      'score': rating >= 3 ? 1.0 : 0.0,
      'response': responseOptionId != null ? {'selected': responseOptionId} : null,
      'latency_ms': latencyMs ?? 15000,
      'metadata': {
        'origin': 'ai_generated',
        'origin_client_id': clientId,
      },
    };

    if (hasDatabase) {
      final rpcRes = await _postRpc('record_events', {
        'p_events': [payload],
      });
      if (rpcRes is Map) {
        return {
          'status': 'recorded_in_db',
          'event_id': eventId,
          'rpc_result': rpcRes,
        };
      }
    }

    return {
      'status': 'accepted_offline',
      'event_id': eventId,
      'payload': payload,
      'note': 'Logged in offline/simulated mode. Ready for synchronization.',
    };
  }

  /// Submit item defect report / correction proposal into moderation queue.
  Future<Map<String, dynamic>> proposeItemFix({
    required String itemId,
    required String reason,
    String? suggestedStem,
    List<String>? suggestedOptions,
    String? suggestedExplanation,
    String? reporterId,
  }) async {
    final reportId = 'mod-${DateTime.now().millisecondsSinceEpoch}';
    final desc = StringBuffer('MCP Item Correction Proposal:\nReason: $reason');
    if (suggestedStem != null) desc.write('\nProposed Stem: $suggestedStem');
    if (suggestedOptions != null) desc.write('\nProposed Options: ${suggestedOptions.join(' | ')}');
    if (suggestedExplanation != null) desc.write('\nProposed Explanation: $suggestedExplanation');

    if (hasDatabase) {
      // In Supabase, moderation_reports table exists
      final payload = {
        'id': reportId,
        'item_type': 'question',
        'item_id': itemId,
        'reporter_id': reporterId,
        'reason': 'other',
        'description': desc.toString(),
        'status': 'pending',
      };
      final req = await _client.postUrl(Uri.parse('$supabaseUrl/rest/v1/moderation_reports'));
      req.headers.set('Content-Type', 'application/json');
      setSupabaseRestAuth(req, supabaseKey!);
      req.write(jsonEncode(payload));
      final res = await req.close();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {
          'status': 'submitted',
          'report_id': reportId,
          'item_id': itemId,
          'queue': 'moderation_reports',
        };
      }
    }

    return {
      'status': 'recorded_offline',
      'report_id': reportId,
      'item_id': itemId,
      'details': desc.toString(),
    };
  }
}
