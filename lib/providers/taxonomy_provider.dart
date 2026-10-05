import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/taxonomy/taxonomy.dart';
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
