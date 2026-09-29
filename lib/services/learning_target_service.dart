import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/curriculum_node.dart';
import '../models/knowledge_concept.dart';
import '../models/learning_target.dart';

class LearningTargetService {
  final SupabaseClient _supabase;

  LearningTargetService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get published learning targets
  Future<List<LearningTarget>> getTargets({
    TargetType? type,
    String? fieldId,
    String? search,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from('learning_targets').select('*').eq('status', 'published');

      if (type != null) {
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
          .eq('status', 'published')
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
          .select('*')
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

  /// Create a new learning target (career, certification, exam, academic program, curriculum standard)
  Future<LearningTarget?> createTarget({
    required String title,
    required TargetType targetType,
    String? description,
    String? fieldId,
    String? providerName,
    String? institutionName,
    String? jurisdiction,
    String? emoji,
    bool isPublic = true,
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
            'is_public': isPublic,
            'status': 'published',
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
        'status': 'published',
      });

      return target;
    } catch (e) {
      debugPrint('❌ Error creating learning target: $e');
      return null;
    }
  }
}
