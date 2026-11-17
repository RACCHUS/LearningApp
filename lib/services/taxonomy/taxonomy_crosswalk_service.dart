import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/taxonomy/taxonomy.dart';
import 'taxonomy_crosswalk_fallbacks.dart';

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
    if (client == null) return TaxonomyCrosswalkFallbacks.catalogClusters();
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
      return TaxonomyCrosswalkFallbacks.catalogClusters();
    }
  }

  // --------------------------------------------------------------------------
  // 2. Canonical Fields
  // --------------------------------------------------------------------------

  Future<List<CanonicalField>> getFields({String? clusterSlug}) async {
    final client = _supabase;
    if (client == null) return TaxonomyCrosswalkFallbacks.fields(clusterSlug: clusterSlug);
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

      // Unscoped requests return only top-level roots. Nested CIP subfields and
      // program fields (thousands of rows) are loaded per parent instead.
      final response = await client
          .from('fields')
          .select()
          .eq('is_active', true)
          .isFilter('parent_id', null)
          .inFilter('field_kind', ['broad_field', 'native_field'])
          .order('sort_order', ascending: true)
          .limit(rootFieldLimit);

      return (response as List<dynamic>)
          .map((e) => CanonicalField.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ Remote fields fetch failed: $e');
      return TaxonomyCrosswalkFallbacks.fields(clusterSlug: clusterSlug);
    }
  }

  static const int rootFieldLimit = 500;
  static const int childFieldPageSize = 200;

  /// Direct children of [parentId], for lazy hierarchy browsing.
  ///
  /// Requests [childFieldPageSize] + 1 rows so callers can tell whether the
  /// result was truncated without loading an unbounded list.
  Future<FieldChildrenPage> getChildFields(String parentId) async {
    final client = _supabase;
    if (client == null) {
      return FieldChildrenPage.fromRows(
        TaxonomyCrosswalkFallbacks.childFields().where((f) => f.parentId == parentId).toList(),
        pageSize: childFieldPageSize,
      );
    }
    final response = await client
        .from('fields')
        .select(
            'id,name,slug,description,icon,field_kind,parent_id,sort_order,is_active')
        .eq('is_active', true)
        .eq('parent_id', parentId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true)
        .limit(childFieldPageSize + 1);
    return FieldChildrenPage.fromRows(
      (response as List<dynamic>)
          .map((e) => CanonicalField.fromJson(e as Map<String, dynamic>))
          .toList(),
      pageSize: childFieldPageSize,
    );
  }

  Future<CanonicalField?> getFieldBySlug(String slug) async {
    final client = _supabase;
    if (client == null) {
      final fallback = TaxonomyCrosswalkFallbacks.fields();
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
      return TaxonomyCrosswalkFallbacks.externalClassificationNodes(
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
          : TaxonomyCrosswalkFallbacks.externalClassificationNodes(
              system: system,
              version: version,
              parentId: parentId,
            );
    } catch (e) {
      debugPrint('⚠️ Remote external_classification_nodes fetch failed: $e');
      return TaxonomyCrosswalkFallbacks.externalClassificationNodes(
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
        return TaxonomyCrosswalkFallbacks.externalClassificationNodes(system: system, version: version)
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
      return TaxonomyCrosswalkFallbacks.externalClassificationNodes(system: system, version: version)
          .cast<ExternalClassificationNode?>()
          .firstWhere((n) => n?.code == code, orElse: () => null);
    } catch (e) {
      debugPrint('⚠️ Remote getExternalClassificationByCode failed for $code: $e');
      return TaxonomyCrosswalkFallbacks.externalClassificationNodes(system: system, version: version)
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
    if (client == null) return TaxonomyCrosswalkFallbacks.occupationNodes();
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
      return TaxonomyCrosswalkFallbacks.occupationNodes();
    }
  }

  Future<OccupationNode?> getOccupationByCode(String code) async {
    final client = _supabase;
    if (client == null) {
      try {
        return TaxonomyCrosswalkFallbacks.occupationNodes().firstWhere((o) => o.code == code);
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
    if (client == null) return TaxonomyCrosswalkFallbacks.targetOccupations(targetId);
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
      return TaxonomyCrosswalkFallbacks.targetOccupations(targetId);
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
    if (client == null) return TaxonomyCrosswalkFallbacks.cipCrosswalks(occupationCode);
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

      return list.isNotEmpty ? list : TaxonomyCrosswalkFallbacks.cipCrosswalks(occupationCode);
    } catch (e) {
      debugPrint('⚠️ Remote getCipCrosswalksForOccupation failed for $occupationCode: $e');
      return TaxonomyCrosswalkFallbacks.cipCrosswalks(occupationCode);
    }
  }

  Future<List<TargetCrosswalkOccupation>> getOccupationsForCip(String cipCode) async {
    final client = _supabase;
    if (client == null) return TaxonomyCrosswalkFallbacks.occupationsForCip(cipCode);
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
      return list.isNotEmpty ? list : TaxonomyCrosswalkFallbacks.occupationsForCip(cipCode);
    } catch (e) {
      debugPrint('⚠️ Remote getOccupationsForCip failed for $cipCode: $e');
      return TaxonomyCrosswalkFallbacks.occupationsForCip(cipCode);
    }
  }

  Future<List<OccupationTargetLink>> getTargetsForOccupation(String occupationCode) async {
    final client = _supabase;
    if (client == null) return TaxonomyCrosswalkFallbacks.targetsForOccupation(occupationCode);
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

      return list.isNotEmpty ? list : TaxonomyCrosswalkFallbacks.targetsForOccupation(occupationCode);
    } catch (e) {
      debugPrint('⚠️ Remote getTargetsForOccupation failed for $occupationCode: $e');
      return TaxonomyCrosswalkFallbacks.targetsForOccupation(occupationCode);
    }
  }

  /// Server-filtered suggestions for the personal learning-goal form.
  ///
  /// Unlike broad explorer search, this queries the *authoritative* SOC/CIP
  /// tables directly so API row limits do not hide alphabetical matches.
  /// Classification records are reference material, not official goals.
  Future<List<TaxonomySearchMatch>> suggestGoalTaxonomy({
    required String query,
    required String targetType,
  }) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    if (targetType != 'career' && targetType != 'academic_program') {
      return const [];
    }

    final client = _supabase;
    if (client == null) {
      if (targetType == 'career') {
        return TaxonomyCrosswalkFallbacks.occupationNodes()
            .where((o) => o.title.toLowerCase().contains(q.toLowerCase()) &&
                (o.level == 'detailed_occupation' ||
                    o.level == 'onet_extension'))
            .take(8)
            .map((o) => TaxonomySearchMatch(
                  id: o.id, code: o.code, title: o.title,
                  description: o.description,
                  kind: TaxonomyItemKind.occupation,
                  level: o.level, system: o.taxonomySystem,
                ))
            .toList();
      }
      return TaxonomyCrosswalkFallbacks.externalClassificationNodes(system: 'cip', version: '2020')
          .where((c) => c.levelCode == 'program' &&
              c.title.toLowerCase().contains(q.toLowerCase()))
          .take(8)
          .map((c) => TaxonomySearchMatch(
                id: c.id, code: c.code, title: c.title,
                description: c.definition,
                kind: TaxonomyItemKind.cipProgram,
                level: c.levelCode, system: c.system,
              ))
          .toList();
    }

    try {
      if (targetType == 'career') {
        final rows = await client.from('occupation_nodes')
            .select('id,code,title,description,level,taxonomy_system')
            .eq('is_active', true)
            .inFilter('level', ['detailed_occupation', 'onet_extension'])
            .ilike('title', '%$q%')
            .order('title')
            .limit(8);
        return (rows as List).map((row) {
          final m = row as Map<String, dynamic>;
          return TaxonomySearchMatch(
            id: m['id'] as String,
            code: m['code'] as String,
            title: m['title'] as String,
            description: m['description'] as String?,
            kind: TaxonomyItemKind.occupation,
            level: m['level'] as String?,
            system: m['taxonomy_system'] as String?,
          );
        }).toList();
      }

      final rows = await client.from('external_classification_nodes')
          .select('id,code,title,definition,level_code,system')
          .eq('is_active', true)
          .eq('system', 'cip')
          .eq('version', '2020')
          .eq('level_code', 'program')
          .ilike('title', '%$q%')
          .order('title')
          .limit(8);
      return (rows as List).map((row) {
        final m = row as Map<String, dynamic>;
        return TaxonomySearchMatch(
          id: m['id'] as String,
          code: m['code'] as String,
          title: m['title'] as String,
          description: m['definition'] as String?,
          kind: TaxonomyItemKind.cipProgram,
          level: m['level_code'] as String?,
          system: m['system'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Goal taxonomy suggestions unavailable: $e');
      return const [];
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
}
