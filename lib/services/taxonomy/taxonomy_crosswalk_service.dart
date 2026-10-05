import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/taxonomy/taxonomy.dart';

/// Taxonomy Crosswalk Service
///
/// Provides access to the Dual-Layer Learning Ontology:
///   1. Catalog Clusters (Presentation layer)
///   2. Canonical Fields (Internal plane)
///   3. External Classification Nodes (CIP 2020/2030, ISCED-F 2013)
///   4. 5-Tier Hierarchical Labor Taxonomy (BLS SOC 2018 + O*NET 2019/31.0)
///   5. Educational-to-Labor Market Crosswalks (CIP-SOC mappings)
///   6. Lateral & Interdisciplinary Field Relations (bidirectional)
///   7. Labor Market Analytics Metrics (with fail-closed privacy)
///   8. Decennial Taxonomy Lineage Resolution
class TaxonomyCrosswalkService {
  final SupabaseClient? _supabase;

  TaxonomyCrosswalkService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? _resolveDefaultClient();

  static SupabaseClient? _resolveDefaultClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 1. Catalog Clusters
  // --------------------------------------------------------------------------

  Future<List<CatalogCluster>> getCatalogClusters() async {
    final client = _supabase;
    if (client == null) return _fallbackCatalogClusters();
    try {
      final response = await client
          .from('catalog_clusters')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (response as List<dynamic>)
          .map((e) => CatalogCluster.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote catalog_clusters fetch failed: $e');
      return _fallbackCatalogClusters();
    }
  }

  // --------------------------------------------------------------------------
  // 2. Canonical Fields
  // --------------------------------------------------------------------------

  Future<List<CanonicalField>> getFields({String? clusterSlug}) async {
    final client = _supabase;
    if (client == null) return _fallbackFields();
    try {
      if (clusterSlug != null) {
        final clusterRes = await client
            .from('catalog_clusters')
            .select('id')
            .eq('slug', clusterSlug)
            .maybeSingle();

        if (clusterRes != null) {
          final clusterId = clusterRes['id'] as String;
          final response = await client
              .from('catalog_cluster_fields')
              .select('field_id, fields(*)')
              .eq('cluster_id', clusterId)
              .order('sort_order', ascending: true);

          return (response as List<dynamic>)
              .map((e) => CanonicalField.fromJson(e['fields'] as Map<String, dynamic>))
              .toList();
        }
      }

      final response = await client
          .from('fields')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List<dynamic>)
          .map((e) => CanonicalField.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote fields fetch failed: $e');
      return _fallbackFields();
    }
  }

  Future<CanonicalField?> getFieldBySlug(String slug) async {
    final client = _supabase;
    if (client == null) {
      final fallback = _fallbackFields();
      try {
        return fallback.firstWhere((f) => f.slug == slug);
      } catch (_) {
        return null;
      }
    }
    try {
      final res = await client
          .from('fields')
          .select()
          .eq('slug', slug)
          .maybeSingle();
      if (res == null) return null;
      return CanonicalField.fromJson(res);
    } catch (e) {
      debugPrint('⚠️ Remote field fetch failed for $slug: $e');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 3. External Classification Nodes (CIP / ISCED)
  // --------------------------------------------------------------------------

  Future<List<ExternalClassificationNode>> getExternalClassificationNodes({
    String system = 'cip',
    String version = '2020',
    String? parentId,
  }) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      var query = client
          .from('external_classification_nodes')
          .select()
          .eq('system', system)
          .eq('version', version)
          .eq('is_active', true);

      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      }

      final response = await query.order('code', ascending: true);
      return (response as List<dynamic>)
          .map((e) => ExternalClassificationNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote external_classification_nodes fetch failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // 4. 5-Tier Occupation Hierarchy (BLS SOC + O*NET)
  // --------------------------------------------------------------------------

  Future<List<OccupationNode>> getOccupationNodes({
    String? level,
    String? parentId,
  }) async {
    final client = _supabase;
    if (client == null) return _fallbackOccupationNodes();
    try {
      var query = client
          .from('occupation_nodes')
          .select()
          .eq('is_active', true);

      if (level != null) {
        query = query.eq('level', level);
      }
      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      }

      final response = await query.order('code', ascending: true);
      return (response as List<dynamic>)
          .map((e) => OccupationNode.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote occupation_nodes fetch failed: $e');
      return _fallbackOccupationNodes();
    }
  }

  Future<OccupationNode?> getOccupationByCode(String code) async {
    final client = _supabase;
    if (client == null) {
      try {
        return _fallbackOccupationNodes().firstWhere((o) => o.code == code);
      } catch (_) {
        return null;
      }
    }
    try {
      final res = await client
          .from('occupation_nodes')
          .select()
          .eq('code', code)
          .maybeSingle();
      if (res == null) return null;
      return OccupationNode.fromJson(res);
    } catch (e) {
      debugPrint('⚠️ Remote occupation by code failed for $code: $e');
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 5. Educational-to-Labor Crosswalks (Target & Field to Occupations)
  // --------------------------------------------------------------------------

  Future<List<TargetCrosswalkOccupation>> getTargetOccupations(String targetId) async {
    final client = _supabase;
    if (client == null) return _fallbackTargetOccupations(targetId);
    try {
      // 1. Try dedicated RPC get_target_crosswalk_occupations
      final rpcRes = await client.rpc(
        'get_target_crosswalk_occupations',
        params: {'p_target_id': targetId},
      );
      if (rpcRes is List && rpcRes.isNotEmpty) {
        return rpcRes
            .map((e) => TargetCrosswalkOccupation.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 2. Fallback to querying v_target_occupation_mappings view directly
      final viewRes = await client
          .from('v_target_occupation_mappings')
          .select()
          .eq('target_id', targetId);

      return (viewRes as List<dynamic>)
          .map((e) => TargetCrosswalkOccupation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote getTargetOccupations failed for $targetId: $e');
      return _fallbackTargetOccupations(targetId);
    }
  }

  Future<List<TargetCrosswalkOccupation>> getFieldOccupations(String fieldId) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final res = await client
          .from('v_field_occupation_mappings')
          .select()
          .eq('field_id', fieldId);

      return (res as List<dynamic>)
          .map((e) => TargetCrosswalkOccupation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote getFieldOccupations failed for $fieldId: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // 6. Lateral Field Relations (Bidirectional)
  // --------------------------------------------------------------------------

  Future<List<FieldRelation>> getLateralFieldRelations(String fieldId) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final res = await client
          .from('v_field_relations_bidirectional')
          .select()
          .eq('from_field_id', fieldId);

      return (res as List<dynamic>)
          .map((e) => FieldRelation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote getLateralFieldRelations failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // 7. Labor Market Metrics (With Fail-Closed Privacy Filter)
  // --------------------------------------------------------------------------

  Future<List<FieldOccupationMetric>> getFieldOccupationMetrics({
    required String fieldId,
    required String occupationId,
  }) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final res = await client
          .from('field_occupation_metrics')
          .select()
          .eq('field_id', fieldId)
          .eq('occupation_id', occupationId)
          .eq('is_published', true);

      return (res as List<dynamic>)
          .map((e) => FieldOccupationMetric.fromJson(e as Map<String, dynamic>))
          .where((m) => m.isUserDisplayable)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote getFieldOccupationMetrics failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // 8. Decennial Taxonomy Lineage Resolution
  // --------------------------------------------------------------------------

  Future<List<TaxonomyNodeLineage>> resolveLineage({
    required String sourceSystem,
    required String fromVersion,
    String? fromCode,
  }) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final res = await client.rpc(
        'resolve_taxonomy_lineage',
        params: {
          'p_source_system': sourceSystem,
          'p_from_version': fromVersion,
          'p_from_code': fromCode,
        },
      );
      return (res as List<dynamic>)
          .map((e) => TaxonomyNodeLineage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote resolve_taxonomy_lineage RPC failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // 9. Cross-Target Shared Concepts
  // --------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getSharedConcepts({
    required String targetAId,
    required String targetBId,
  }) async {
    final client = _supabase;
    if (client == null) return const [];
    try {
      final res = await client.rpc(
        'get_cross_target_shared_concepts',
        params: {
          'p_target_a_id': targetAId,
          'p_target_b_id': targetBId,
        },
      );
      if (res is List) {
        return res.cast<Map<String, dynamic>>();
      }
      return const [];
    } catch (e) {
      debugPrint('⚠️ Remote get_cross_target_shared_concepts RPC failed: $e');
      return const [];
    }
  }

  // --------------------------------------------------------------------------
  // In-Memory Fallbacks for Testing & Offline Grace
  // --------------------------------------------------------------------------

  List<CatalogCluster> _fallbackCatalogClusters() {
    return const [
      CatalogCluster(id: 'c1', slug: 'computing-tech', title: 'Computing & Information Technology', emoji: '💻', accentColor: '#2563EB', sortOrder: 1),
      CatalogCluster(id: 'c2', slug: 'health-medicine', title: 'Health Professions & Medicine', emoji: '🏥', accentColor: '#DC2626', sortOrder: 2),
      CatalogCluster(id: 'c3', slug: 'engineering-tech', title: 'Engineering & Applied Technology', emoji: '⚙️', accentColor: '#D97706', sortOrder: 3),
      CatalogCluster(id: 'c4', slug: 'business-finance', title: 'Business, Finance & Management', emoji: '📈', accentColor: '#059669', sortOrder: 4),
      CatalogCluster(id: 'c5', slug: 'physical-bio-sciences', title: 'Physical & Biological Sciences', emoji: '🔬', accentColor: '#7C3AED', sortOrder: 5),
      CatalogCluster(id: 'c6', slug: 'math-stats-data', title: 'Mathematics, Statistics & Data', emoji: '📐', accentColor: '#0891B2', sortOrder: 6),
      CatalogCluster(id: 'c7', slug: 'law-policy-security', title: 'Law, Public Policy & Security', emoji: '⚖️', accentColor: '#4B5563', sortOrder: 7),
      CatalogCluster(id: 'c8', slug: 'arts-design', title: 'Visual Arts, Performing Arts & Design', emoji: '🎨', accentColor: '#DB2777', sortOrder: 8),
      CatalogCluster(id: 'c9', slug: 'social-sciences-education', title: 'Social Sciences, Psychology & Education', emoji: '🌍', accentColor: '#4F46E5', sortOrder: 9),
      CatalogCluster(id: 'c10', slug: 'humanities-languages', title: 'Humanities, Languages & Literature', emoji: '📚', accentColor: '#B45309', sortOrder: 10),
      CatalogCluster(id: 'c11', slug: 'skilled-trades', title: 'Skilled Construction & Mechanical Trades', emoji: '🔨', accentColor: '#EA580C', sortOrder: 11),
      CatalogCluster(id: 'c12', slug: 'agriculture-environment', title: 'Agriculture, Natural Resources & Environment', emoji: '🌾', accentColor: '#16A34A', sortOrder: 12),
    ];
  }

  List<CanonicalField> _fallbackFields() {
    return const [
      CanonicalField(id: 'f-cs', name: 'Computer and Information Sciences and Support Services', slug: 'computer-sciences', fieldKind: 'broad_field', sortOrder: 11),
      CanonicalField(id: 'f-math', name: 'Mathematics and Statistics', slug: 'mathematics-statistics-series', fieldKind: 'broad_field', sortOrder: 27),
      CanonicalField(id: 'f-eng', name: 'Engineering', slug: 'engineering-disciplines', fieldKind: 'broad_field', sortOrder: 14),
      CanonicalField(id: 'f-health', name: 'Health Professions and Related Programs', slug: 'health-professions-series', fieldKind: 'broad_field', sortOrder: 51),
    ];
  }

  List<OccupationNode> _fallbackOccupationNodes() {
    return const [
      OccupationNode(
        id: 'occ-15-0000',
        code: '15-0000',
        title: 'Computer and Mathematical Occupations',
        level: 'major_group',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
      ),
      OccupationNode(
        id: 'occ-15-1252',
        parentId: 'occ-15-0000',
        code: '15-1252',
        title: 'Software Developers',
        level: 'detailed_occupation',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
        jobZone: 4,
      ),
      OccupationNode(
        id: 'occ-15-1252-00',
        parentId: 'occ-15-1252',
        code: '15-1252.00',
        title: 'Software Developers (O*NET)',
        level: 'onet_extension',
        taxonomySystem: 'onet_soc',
        taxonomyVersion: '2019',
        dataReleaseVersion: 'onet_31_0',
        jobZone: 4,
      ),
      OccupationNode(
        id: 'occ-15-1211',
        parentId: 'occ-15-0000',
        code: '15-1211',
        title: 'Information Security Analysts',
        level: 'detailed_occupation',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
        jobZone: 4,
      ),
    ];
  }

  List<TargetCrosswalkOccupation> _fallbackTargetOccupations(String targetId) {
    return const [
      TargetCrosswalkOccupation(
        occupationId: 'occ-15-1252',
        occupationCode: '15-1252',
        occupationTitle: 'Software Developers',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer and Information Sciences',
        fieldRole: 'primary',
        classificationCode: '11.0701',
        classificationTitle: 'Computer Science',
      ),
      TargetCrosswalkOccupation(
        occupationId: 'occ-15-1211',
        occupationCode: '15-1211',
        occupationTitle: 'Information Security Analysts',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer and Information Sciences',
        fieldRole: 'primary',
        classificationCode: '11.1003',
        classificationTitle: 'Computer and Information Systems Security/Auditing/Information Assurance',
      ),
    ];
  }
}
