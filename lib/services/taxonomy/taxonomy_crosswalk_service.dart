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
    if (client == null) {
      return _fallbackExternalClassificationNodes(
        system: system,
        version: version,
        parentId: parentId,
      );
    }
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
      final list = (response as List<dynamic>)
          .map((e) => ExternalClassificationNode.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.isNotEmpty
          ? list
          : _fallbackExternalClassificationNodes(
              system: system,
              version: version,
              parentId: parentId,
            );
    } catch (e) {
      debugPrint('⚠️ Remote external_classification_nodes fetch failed: $e');
      return _fallbackExternalClassificationNodes(
        system: system,
        version: version,
        parentId: parentId,
      );
    }
  }

  Future<ExternalClassificationNode?> getExternalClassificationByCode(
    String code, {
    String system = 'cip',
    String version = '2020',
  }) async {
    final client = _supabase;
    if (client == null) {
      try {
        return _fallbackExternalClassificationNodes(system: system, version: version)
            .firstWhere((n) => n.code == code);
      } catch (_) {
        return null;
      }
    }
    try {
      final res = await client
          .from('external_classification_nodes')
          .select()
          .eq('system', system)
          .eq('version', version)
          .eq('code', code)
          .maybeSingle();
      if (res != null) {
        return ExternalClassificationNode.fromJson(res);
      }
      return _fallbackExternalClassificationNodes(system: system, version: version)
          .cast<ExternalClassificationNode?>()
          .firstWhere((n) => n?.code == code, orElse: () => null);
    } catch (e) {
      debugPrint('⚠️ Remote getExternalClassificationByCode failed for $code: $e');
      return _fallbackExternalClassificationNodes(system: system, version: version)
          .cast<ExternalClassificationNode?>()
          .firstWhere((n) => n?.code == code, orElse: () => null);
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

  Future<List<CipProgramCrosswalk>> getCipCrosswalksForOccupation(String occupationCode) async {
    final client = _supabase;
    if (client == null) return _fallbackCipCrosswalks(occupationCode);
    try {
      final baseSoc = occupationCode.split('.').first;
      final res = await client
          .from('v_field_occupation_mappings')
          .select('classification_code, classification_title, mapping_kind')
          .or('occupation_code.eq.$occupationCode,occupation_code.eq.$baseSoc');

      final list = (res as List<dynamic>)
          .map((e) => CipProgramCrosswalk(
                code: e['classification_code'] as String? ?? '',
                title: e['classification_title'] as String? ?? '',
                mappingKind: e['mapping_kind'] as String? ?? 'official_qualitative',
              ))
          .where((c) => c.code.isNotEmpty)
          .fold<Map<String, CipProgramCrosswalk>>({}, (map, item) {
            map[item.code] = item;
            return map;
          })
          .values
          .toList();

      return list.isNotEmpty ? list : _fallbackCipCrosswalks(occupationCode);
    } catch (e) {
      debugPrint('⚠️ Remote getCipCrosswalksForOccupation failed for $occupationCode: $e');
      return _fallbackCipCrosswalks(occupationCode);
    }
  }

  Future<List<TargetCrosswalkOccupation>> getOccupationsForCip(String cipCode) async {
    final client = _supabase;
    if (client == null) return _fallbackOccupationsForCip(cipCode);
    try {
      final res = await client
          .from('v_field_occupation_mappings')
          .select('occupation_id, occupation_code, occupation_title, mapping_kind, classification_code, classification_title')
          .eq('classification_code', cipCode);

      final list = (res as List<dynamic>)
          .map((e) => TargetCrosswalkOccupation(
                occupationId: e['occupation_id'] as String? ?? '',
                occupationCode: e['occupation_code'] as String? ?? '',
                occupationTitle: e['occupation_title'] as String? ?? '',
                occupationLevel: 'detailed_occupation',
                fieldId: '',
                fieldName: '',
                fieldRole: 'primary',
                mappingKind: e['mapping_kind'] as String? ?? 'official_qualitative',
                classificationCode: e['classification_code'] as String?,
                classificationTitle: e['classification_title'] as String?,
              ))
          .toList();
      return list.isNotEmpty ? list : _fallbackOccupationsForCip(cipCode);
    } catch (e) {
      debugPrint('⚠️ Remote getOccupationsForCip failed for $cipCode: $e');
      return _fallbackOccupationsForCip(cipCode);
    }
  }

  Future<List<OccupationTargetLink>> getTargetsForOccupation(String occupationCode) async {
    final client = _supabase;
    if (client == null) return _fallbackTargetsForOccupation(occupationCode);
    try {
      final baseSoc = occupationCode.split('.').first;
      final res = await client
          .from('v_target_occupation_mappings')
          .select('target_id, target_title, target_slug, field_role')
          .or('occupation_code.eq.$occupationCode,occupation_code.eq.$baseSoc');

      final list = (res as List<dynamic>)
          .map((e) => OccupationTargetLink.fromJson(e as Map<String, dynamic>))
          .fold<Map<String, OccupationTargetLink>>({}, (map, item) {
            map[item.targetId] = item;
            return map;
          })
          .values
          .toList();

      return list.isNotEmpty ? list : _fallbackTargetsForOccupation(occupationCode);
    } catch (e) {
      debugPrint('⚠️ Remote getTargetsForOccupation failed for $occupationCode: $e');
      return _fallbackTargetsForOccupation(occupationCode);
    }
  }

  Future<List<TaxonomySearchMatch>> searchTaxonomy({required String query}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final results = <TaxonomySearchMatch>[];

    // 1. Occupations
    final occupations = await getOccupationNodes();
    for (final occ in occupations) {
      if (occ.code.toLowerCase().contains(q) ||
          occ.title.toLowerCase().contains(q) ||
          (occ.description?.toLowerCase().contains(q) ?? false)) {
        results.add(TaxonomySearchMatch(
          id: occ.id,
          code: occ.code,
          title: occ.title,
          description: occ.description,
          kind: TaxonomyItemKind.occupation,
          jobZone: occ.jobZone,
          level: occ.level,
          system: occ.taxonomySystem,
        ));
      }
    }

    // 2. CIP Programs
    final cips = await getExternalClassificationNodes();
    for (final cip in cips) {
      if (cip.code.toLowerCase().contains(q) ||
          cip.title.toLowerCase().contains(q) ||
          (cip.definition?.toLowerCase().contains(q) ?? false)) {
        results.add(TaxonomySearchMatch(
          id: cip.id,
          code: cip.code,
          title: cip.title,
          description: cip.definition,
          kind: TaxonomyItemKind.cipProgram,
          level: cip.levelCode,
          system: cip.system,
        ));
      }
    }

    // 3. Clusters
    final clusters = await getCatalogClusters();
    for (final cl in clusters) {
      if (cl.title.toLowerCase().contains(q) || cl.slug.toLowerCase().contains(q)) {
        results.add(TaxonomySearchMatch(
          id: cl.id,
          code: cl.slug,
          title: '${cl.emoji ?? "🎯"} ${cl.title}',
          kind: TaxonomyItemKind.catalogCluster,
        ));
      }
    }

    return results;
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

  List<ExternalClassificationNode> _fallbackExternalClassificationNodes({
    String system = 'cip',
    String version = '2020',
    String? parentId,
  }) {
    final all = <ExternalClassificationNode>[
      const ExternalClassificationNode(
        id: 'cip-11',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '11',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Computer and Information Sciences and Support Services',
        definition:
            'Instructional programs that focus on the computer and information sciences and preparing individuals for various occupations in technology.',
      ),
      const ExternalClassificationNode(
        id: 'cip-11-07',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11',
        system: 'cip',
        version: '2020',
        code: '11.07',
        sourceParentCode: '11',
        levelCode: 'group',
        levelDepth: 2,
        title: 'Computer Science',
        definition:
            'Instructional programs that focus on computer science and related scientific disciplines.',
      ),
      const ExternalClassificationNode(
        id: 'cip-11-0701',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11-07',
        system: 'cip',
        version: '2020',
        code: '11.0701',
        sourceParentCode: '11.07',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Computer Science',
        definition:
            'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
        illustrativeExamples: [
          'Computer Science',
          'Theoretical Computer Science',
          'Computational Theory'
        ],
      ),
      const ExternalClassificationNode(
        id: 'cip-11-1003',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11',
        system: 'cip',
        version: '2020',
        code: '11.1003',
        sourceParentCode: '11',
        levelCode: 'program',
        levelDepth: 3,
        title:
            'Computer and Information Systems Security/Auditing/Information Assurance',
        definition:
            'A program that prepares individuals to assess the security needs of computer and network systems and manage secure infrastructure.',
        illustrativeExamples: [
          'Cybersecurity',
          'Information Assurance',
          'Network Security'
        ],
      ),
      const ExternalClassificationNode(
        id: 'cip-14',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '14',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Engineering',
        definition:
            'Instructional programs that focus on the mathematical and scientific principles applied to the design, construction, and operation of systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-14-0901',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-14',
        system: 'cip',
        version: '2020',
        code: '14.0901',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Computer Engineering, General',
        definition:
            'A program that prepares individuals to apply mathematical and scientific principles to the design and development of computer hardware and integrated hardware-software systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-27',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '27',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Mathematics and Statistics',
        definition:
            'Instructional programs that focus on the systematic study of logical and mathematical quantities, structures, and systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-27-0101',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-27',
        system: 'cip',
        version: '2020',
        code: '27.0101',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Mathematics, General',
        definition:
            'A general program that focuses on the core principles of mathematics, calculus, and abstract algebra.',
      ),
      const ExternalClassificationNode(
        id: 'cip-51',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '51',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Health Professions and Related Programs',
        definition:
            'Instructional programs that prepare individuals for careers in medicine, nursing, health informatics, and allied health.',
      ),
      const ExternalClassificationNode(
        id: 'cip-52',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '52',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Business, Management, Marketing, and Related Support Services',
        definition:
            'Instructional programs that focus on business management, accounting, financial planning, and operational leadership.',
      ),
    ];

    if (parentId != null) {
      return all.where((n) => n.parentId == parentId).toList();
    }
    return all;
  }

  List<CipProgramCrosswalk> _fallbackCipCrosswalks(String occupationCode) {
    if (occupationCode.startsWith('15-1252')) {
      return const [
        CipProgramCrosswalk(
          code: '11.0701',
          title: 'Computer Science',
          definition:
              'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
          mappingKind: 'official_qualitative',
        ),
        CipProgramCrosswalk(
          code: '11.1003',
          title: 'Computer and Information Systems Security',
          definition:
              'A program that prepares individuals to assess security needs of computer and network systems.',
          mappingKind: 'official_qualitative',
        ),
      ];
    }
    if (occupationCode.startsWith('15-1211')) {
      return const [
        CipProgramCrosswalk(
          code: '11.1003',
          title: 'Computer and Information Systems Security',
          definition:
              'A program that prepares individuals to assess security needs of computer and network systems.',
          mappingKind: 'official_qualitative',
        ),
      ];
    }
    return const [
      CipProgramCrosswalk(
        code: '11.0701',
        title: 'Computer Science',
        definition:
            'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
        mappingKind: 'official_qualitative',
      ),
    ];
  }

  List<TargetCrosswalkOccupation> _fallbackOccupationsForCip(String cipCode) {
    if (cipCode.startsWith('11.1003')) {
      return const [
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
          classificationTitle: 'Computer and Information Systems Security',
        ),
      ];
    }
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
    ];
  }

  List<OccupationTargetLink> _fallbackTargetsForOccupation(
      String occupationCode) {
    if (occupationCode.startsWith('15-1211')) {
      return const [
        OccupationTargetLink(
          targetId: 'target-sec-plus',
          targetTitle: 'CompTIA Security+ (SY0-701)',
          targetSlug: 'security-plus-sy0-701',
          targetType: 'certification',
          fieldRole: 'primary',
          emoji: '🛡️',
        ),
      ];
    }
    return const [
      OccupationTargetLink(
        targetId: 'target-bs-cs',
        targetTitle: 'B.S. in Computer Science',
        targetSlug: 'bs-computer-science',
        targetType: 'academic_program',
        fieldRole: 'primary',
        emoji: '🎓',
      ),
      OccupationTargetLink(
        targetId: 'target-swe-career',
        targetTitle: 'Software Engineer Career Path',
        targetSlug: 'software-engineer-career',
        targetType: 'career',
        fieldRole: 'primary',
        emoji: '💻',
      ),
    ];
  }
}
