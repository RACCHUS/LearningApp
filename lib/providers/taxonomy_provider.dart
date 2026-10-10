import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/taxonomy/taxonomy.dart';
import '../models/learning_target.dart';
import '../services/taxonomy/taxonomy_crosswalk_service.dart';

/// Taxonomy Crosswalk Service Provider
final taxonomyServiceProvider = Provider<TaxonomyCrosswalkService>((ref) {
  return TaxonomyCrosswalkService();
});

/// Catalog Clusters Provider
final catalogClustersProvider = FutureProvider<List<CatalogCluster>>((ref) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getCatalogClusters();
});

/// Canonical Fields Provider (Optionally filtered by cluster slug)
final canonicalFieldsProvider =
    FutureProvider.family<List<CanonicalField>, String?>((ref, clusterSlug) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getFields(clusterSlug: clusterSlug);
});

/// Canonical Field by Slug Provider
final canonicalFieldBySlugProvider =
    FutureProvider.family<CanonicalField?, String>((ref, slug) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getFieldBySlug(slug);
});

/// 5-Tier Occupation Hierarchy Provider
final occupationNodesProvider =
    FutureProvider.family<List<OccupationNode>, String?>((ref, level) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getOccupationNodes(level: level);
});

/// Target Crosswalk Occupations Provider
final targetCrosswalkOccupationsProvider =
    FutureProvider.family<List<TargetCrosswalkOccupation>, String>((ref, targetId) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getTargetOccupations(targetId);
});

/// Field Crosswalk Occupations Provider
final fieldCrosswalkOccupationsProvider =
    FutureProvider.family<List<TargetCrosswalkOccupation>, String>((ref, fieldId) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getFieldOccupations(fieldId);
});

/// Lateral Field Relations Provider (Bidirectional)
final lateralFieldRelationsProvider =
    FutureProvider.family<List<FieldRelation>, String>((ref, fieldId) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getLateralFieldRelations(fieldId);
});

/// External Classification Nodes Provider (CIP / ISCED)
final externalClassificationNodesProvider =
    FutureProvider.family<List<ExternalClassificationNode>, String?>(
        (ref, parentId) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getExternalClassificationNodes(parentId: parentId);
});

/// External Classification Node By Code Provider
final externalClassificationByCodeProvider =
    FutureProvider.family<ExternalClassificationNode?, String>(
        (ref, code) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getExternalClassificationByCode(code);
});

/// Occupation Node by Code Provider
final occupationByCodeProvider =
    FutureProvider.family<OccupationNode?, String>((ref, code) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getOccupationByCode(code);
});

/// CIP Crosswalks for an Occupation Provider
final cipCrosswalksForOccupationProvider =
    FutureProvider.family<List<CipProgramCrosswalk>, String>(
        (ref, occupationCode) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getCipCrosswalksForOccupation(occupationCode);
});

/// Occupations for a CIP Program Provider
final occupationsForCipProvider =
    FutureProvider.family<List<TargetCrosswalkOccupation>, String>(
        (ref, cipCode) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getOccupationsForCip(cipCode);
});

/// Targets for an Occupation Provider
final targetsForOccupationProvider =
    FutureProvider.family<List<OccupationTargetLink>, String>(
        (ref, occupationCode) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.getTargetsForOccupation(occupationCode);
});

/// Unified Taxonomy Search Provider
final taxonomySearchProvider =
    FutureProvider.family<List<TaxonomySearchMatch>, String>(
        (ref, query) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.searchTaxonomy(query: query);
});

/// Bounded server-side SOC/CIP reference suggestions for learner-created goals.
final goalTaxonomySuggestionsProvider = FutureProvider.family<
    List<TaxonomySearchMatch>, ({TargetType type, String query})>(
  (ref, args) => ref.watch(taxonomyServiceProvider).suggestGoalTaxonomy(
        query: args.query,
        targetType: args.type.toDbString(),
      ),
);

/// Taxonomy Lineage Transition Provider
final taxonomyLineageProvider =
    FutureProvider.family<List<TaxonomyNodeLineage>, ({String system, String fromVersion, String? code})>(
        (ref, params) async {
  final service = ref.watch(taxonomyServiceProvider);
  return service.resolveLineage(
    sourceSystem: params.system,
    fromVersion: params.fromVersion,
    fromCode: params.code,
  );
});
