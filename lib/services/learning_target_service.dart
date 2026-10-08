import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/curriculum_node.dart';
import '../models/knowledge_concept.dart';
import '../models/learning_target.dart';
import '../models/catalog_cluster.dart';
import '../models/canonical_field.dart';

class LearningTargetService {
  final SupabaseClient _supabase;

  LearningTargetService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get published learning targets
  Future<List<LearningTarget>> getTargets({
    TargetType? type,
    List<TargetType>? types,
    String? fieldId,
    String? search,
    int limit = 50,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      var query = _supabase.from('learning_targets').select('*');
      if (userId != null) {
        query = query.or('status.eq.published,created_by.eq.$userId');
      } else {
        query = query.eq('status', 'published');
      }

      if (types != null && types.isNotEmpty) {
        query = query.inFilter(
          'target_type',
          types.map((t) => t.toDbString()).toList(),
        );
      } else if (type != null) {
        query = query.eq('target_type', type.toDbString());
      }
      if (fieldId != null) {
        query = query.eq('field_id', fieldId);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.ilike('title', '%${search.trim()}%');
      }

      final response = await query.order('title').limit(limit);
      return (response as List).map((json) => LearningTarget.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching learning targets: $e');
      return [];
    }
  }

  /// Read-only suggestions: never use private drafts or unreviewed community
  /// entries as recommended examples, even when the requesting user owns them.
  Future<List<LearningTarget>> getSuggestionTargets({
    required TargetType type,
    int limit = 120,
  }) async {
    final visible = await getTargets(type: type, limit: limit);
    final suggestions = visible.where((t) => t.isTrustedPublic).toList();
    suggestions.sort((a, b) {
      if (a.isOfficial != b.isOfficial) return a.isOfficial ? -1 : 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return suggestions;
  }

  /// Sends an owned private draft into a moderation queue. The backend only
  /// allows a review request; the client cannot approve or publish the entry.
  Future<bool> requestCommunityReview(String targetId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final result = await _supabase
          .from('learning_targets')
          .update({'review_status': 'pending'})
          .eq('id', targetId)
          .eq('created_by', userId)
          .eq('status', 'draft')
          .select('id')
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Could not request learning target review: $e');
      return false;
    }
  }

  /// Get single learning target by id or slug
  Future<LearningTarget?> getTarget(String idOrSlug) async {
    try {
      final res = await _supabase
          .from('learning_targets')
          .select('*')
          .or('id.eq.$idOrSlug,slug.eq.$idOrSlug')
          .maybeSingle();

      if (res != null) {
        return LearningTarget.fromJson(res);
      }

      // Check v2_migration_map for legacy career_path mapping
      final mapRes = await _supabase
          .from('v2_migration_map')
          .select('v2_id')
          .eq('legacy_type', 'career_path')
          .eq('legacy_id', idOrSlug)
          .maybeSingle();

      if (mapRes != null && mapRes['v2_id'] != null) {
        final mappedTargetId = mapRes['v2_id'] as String;
        return getTarget(mappedTargetId);
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error fetching learning target $idOrSlug: $e');
      return null;
    }
  }

  /// Get latest published target version
  Future<TargetVersion?> getLatestVersion(String targetId) async {
    try {
      final res = await _supabase
          .from('target_versions')
          .select('*')
          .eq('target_id', targetId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return TargetVersion.fromJson(res);
    } catch (e) {
      debugPrint('❌ Error fetching target version for $targetId: $e');
      return null;
    }
  }

  /// Get all curriculum nodes for a target version
  Future<List<CurriculumNode>> getCurriculumNodes(String targetVersionId) async {
    try {
      final res = await _supabase
          .from('curriculum_nodes')
          .select('*')
          .eq('target_version_id', targetVersionId)
          .order('sort_order');

      return (res as List).map((json) => CurriculumNode.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching curriculum nodes for $targetVersionId: $e');
      return [];
    }
  }

  /// Get lessons attached to a curriculum node
  Future<List<CurriculumNodeLesson>> getNodeLessons(String curriculumNodeId) async {
    try {
      final res = await _supabase
          .from('curriculum_node_lessons')
          .select('*, lessons(title)')
          .eq('curriculum_node_id', curriculumNodeId)
          .order('sort_order');

      return (res as List).map((json) => CurriculumNodeLesson.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching node lessons: $e');
      return [];
    }
  }

  /// Get single concept by ID
  Future<KnowledgeConcept?> getConcept(String conceptId) async {
    try {
      final res = await _supabase
          .from('knowledge_concepts')
          .select('*')
          .eq('id', conceptId)
          .maybeSingle();

      if (res == null) return null;
      return KnowledgeConcept.fromJson(res);
    } catch (e) {
      debugPrint('❌ Error fetching concept $conceptId: $e');
      return null;
    }
  }

  /// Get relations for concept
  Future<List<ConceptRelation>> getConceptRelations(String conceptId) async {
    try {
      final res = await _supabase
          .from('concept_relations')
          .select('*')
          .or('from_concept_id.eq.$conceptId,to_concept_id.eq.$conceptId');

      return (res as List).map((json) => ConceptRelation.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching concept relations for $conceptId: $e');
      return [];
    }
  }

  /// Get candidate lessons teaching a concept
  Future<List<Map<String, dynamic>>> getTeachingLessonsForConcept(String conceptId) async {
    try {
      final res = await _supabase
          .from('lesson_concepts')
          .select('role, weight, sort_order, lessons(id, title, description, category)')
          .eq('concept_id', conceptId)
          .order('sort_order');

      return (res as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error fetching teaching lessons for concept $conceptId: $e');
      return [];
    }
  }

  /// Search concepts by name
  Future<List<KnowledgeConcept>> searchConcepts({String? query, int limit = 20}) async {
    try {
      var q = _supabase.from('knowledge_concepts').select('*');
      if (query != null && query.trim().isNotEmpty) {
        q = q.ilike('name', '%${query.trim()}%');
      }
      final res = await q.order('name').limit(limit);
      return (res as List).map((json) => KnowledgeConcept.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error searching concepts: $e');
      return [];
    }
  }

  /// Create a new learning target (career, certification, exam, academic program, curriculum standard).
  ///
  /// Defaults to private (`is_public = false`) and `status = 'draft'` to avoid polluting
  /// the canonical catalog and protect learner privacy per V2 architecture rules.
  Future<LearningTarget?> createTarget({
    required String title,
    required TargetType targetType,
    String? description,
    String? fieldId,
    String? providerName,
    String? institutionName,
    String? jurisdiction,
    String? emoji,
  }) async {
    try {
      final slug = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '') +
          '-${DateTime.now().millisecondsSinceEpoch % 10000}';
      final userId = _supabase.auth.currentUser?.id;

      final res = await _supabase
          .from('learning_targets')
          .insert({
            'title': title.trim(),
            'slug': slug,
            'target_type': targetType.toDbString(),
            'description': description?.trim(),
            'field_id': fieldId,
            'provider_name': providerName?.trim(),
            'institution_name': institutionName?.trim(),
            'jurisdiction': jurisdiction?.trim(),
            'emoji': emoji ??
                (targetType == TargetType.career
                    ? '💼'
                    : (targetType == TargetType.certification
                        ? '📜'
                        : (targetType == TargetType.standardizedExam
                            ? '📝'
                            : (targetType == TargetType.academicProgram
                                ? '🎓'
                                : '🎯')))),
            'is_public': false,
            'is_official': false,
            'review_status': 'unreviewed',
            'status': 'draft',
            'created_by': userId,
          })
          .select('*')
          .single();

      final target = LearningTarget.fromJson(res);

      // Auto-create initial TargetVersion so it can immediately receive curriculum nodes
      await _supabase.from('target_versions').insert({
        'target_id': target.id,
        'version_code': 'v1.0',
        'title': '${target.title} (v1.0)',
        'description': 'Initial curriculum version for ${target.title}',
        'status': 'draft',
      });

      return target;
    } catch (e) {
      debugPrint('❌ Error creating learning target: $e');
      return null;
    }
  }

  /// Add a curriculum node to a target version
  Future<CurriculumNode?> addCurriculumNode({
    required String targetVersionId,
    required String title,
    String? description,
    String? code,
    String nodeType = 'domain',
    int sortOrder = 0,
    String? parentId,
    double weight = 1.0,
  }) async {
    try {
      final res = await _supabase
          .from('curriculum_nodes')
          .insert({
            'target_version_id': targetVersionId,
            'title': title.trim(),
            'description': description?.trim(),
            'code': code?.trim(),
            'node_type': nodeType,
            'sort_order': sortOrder,
            'parent_id': parentId,
            'weight': weight,
          })
          .select('*')
          .single();
      return CurriculumNode.fromJson(res);
    } catch (e) {
      debugPrint('❌ Error adding curriculum node: $e');
      return null;
    }
  }

  /// Delete a curriculum node
  Future<bool> deleteCurriculumNode(String nodeId) async {
    try {
      await _supabase
          .from('curriculum_nodes')
          .delete()
          .eq('id', nodeId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting curriculum node: $e');
      return false;
    }
  }

  /// Reorder curriculum nodes by updating their sort orders
  Future<bool> reorderCurriculumNodes(List<String> nodeIds) async {
    try {
      for (int i = 0; i < nodeIds.length; i++) {
        await _supabase
            .from('curriculum_nodes')
            .update({'sort_order': i})
            .eq('id', nodeIds[i]);
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error reordering curriculum nodes: $e');
      return false;
    }
  }

  /// Bind a course to a curriculum node
  Future<bool> bindCourseToNode({
    required String curriculumNodeId,
    required String courseId,
    bool isRequired = true,
    int sortOrder = 0,
  }) async {
    try {
      await _supabase.from('curriculum_node_courses').upsert({
        'curriculum_node_id': curriculumNodeId,
        'course_id': courseId,
        'is_required': isRequired,
        'sort_order': sortOrder,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error binding course to curriculum node: $e');
      return false;
    }
  }

  /// Bind a module to a curriculum node
  Future<bool> bindModuleToNode({
    required String curriculumNodeId,
    required String moduleId,
    bool isRequired = true,
    int sortOrder = 0,
  }) async {
    try {
      await _supabase.from('curriculum_node_modules').upsert({
        'curriculum_node_id': curriculumNodeId,
        'module_id': moduleId,
        'is_required': isRequired,
        'sort_order': sortOrder,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error binding module to curriculum node: $e');
      return false;
    }
  }

  /// Bind a lesson to a curriculum node
  Future<bool> bindLessonToNode({
    required String curriculumNodeId,
    required String lessonId,
    bool isRequired = true,
    int sortOrder = 0,
  }) async {
    try {
      await _supabase.from('curriculum_node_lessons').upsert({
        'curriculum_node_id': curriculumNodeId,
        'lesson_id': lessonId,
        'is_required': isRequired,
        'sort_order': sortOrder,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error binding lesson to curriculum node: $e');
      return false;
    }
  }

  /// Bind a concept to a curriculum node
  Future<bool> bindConceptToNode({
    required String curriculumNodeId,
    required String conceptId,
    String relevance = 'core',
    double weight = 1.0,
  }) async {
    try {
      await _supabase.from('curriculum_node_concepts').upsert({
        'curriculum_node_id': curriculumNodeId,
        'concept_id': conceptId,
        'relevance': relevance,
        'weight': weight,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Error binding concept to curriculum node: $e');
      return false;
    }
  }

  /// Get the 12 presentation catalog clusters
  Future<List<CatalogCluster>> getCatalogClusters() async {
    try {
      final res = await _supabase
          .from('catalog_clusters')
          .select('*')
          .eq('is_active', true)
          .order('sort_order');
      return (res as List).map((json) => CatalogCluster.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching catalog clusters: $e');
      return [];
    }
  }

  /// Get canonical fields belonging to a catalog cluster
  Future<List<CanonicalField>> getClusterFields(String clusterId) async {
    try {
      final res = await _supabase
          .from('catalog_cluster_fields')
          .select('fields(*)')
          .eq('cluster_id', clusterId)
          .order('sort_order');
      final list = <CanonicalField>[];
      for (final row in (res as List)) {
        final f = row['fields'] as Map<String, dynamic>?;
        if (f != null) {
          list.add(CanonicalField.fromJson(f));
        }
      }
      return list;
    } catch (e) {
      debugPrint('❌ Error fetching cluster fields: $e');
      return [];
    }
  }

  /// Get canonical fields (all or by parentId)
  Future<List<CanonicalField>> getFields({String? parentId, int limit = 100}) async {
    try {
      var query = _supabase.from('fields').select('*').eq('is_active', true);
      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      }
      final res = await query.order('sort_order').limit(limit);
      return (res as List).map((json) => CanonicalField.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching fields: $e');
      return [];
    }
  }

  /// Get learning targets belonging to fields in a catalog cluster
  Future<List<LearningTarget>> getTargetsForCluster(String clusterId) async {
    try {
      final fields = await getClusterFields(clusterId);
      if (fields.isEmpty) return [];
      final fieldIds = fields.map((f) => f.id).toList();

      final targetsMap = <String, LearningTarget>{};

      // 1. Direct field_id
      final res = await _supabase
          .from('learning_targets')
          .select('*')
          .inFilter('field_id', fieldIds)
          .eq('status', 'published')
          .order('title');
      for (final json in (res as List)) {
        final t = LearningTarget.fromJson(json);
        targetsMap[t.id] = t;
      }

      // 2. Supporting/cross-referenced fields via learning_target_fields
      try {
        final ltfRes = await _supabase
            .from('learning_target_fields')
            .select('learning_targets(*)')
            .inFilter('field_id', fieldIds);
        for (final row in (ltfRes as List)) {
          final tJson = row['learning_targets'] as Map<String, dynamic>?;
          if (tJson != null && tJson['status'] == 'published') {
            final t = LearningTarget.fromJson(tJson);
            targetsMap[t.id] = t;
          }
        }
      } catch (_) {}

      return targetsMap.values.toList()..sort((a, b) => a.title.compareTo(b.title));
    } catch (e) {
      debugPrint('❌ Error fetching targets for cluster: $e');
      return [];
    }
  }
}
