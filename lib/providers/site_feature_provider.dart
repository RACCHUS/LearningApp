import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/governance/site_feature_service.dart';

final siteFeatureServiceProvider =
    Provider<SiteFeatureService>((ref) => SiteFeatureService());

/// A single low-cost snapshot read when the owner enables the runtime source.
final siteFeatureSnapshotProvider =
    FutureProvider<Map<String, SiteFeatureSetting>>((ref) async {
  return ref.watch(siteFeatureServiceProvider).loadPublicSnapshot();
});

bool isSiteFeatureExperimental(
  Map<String, SiteFeatureSetting>? snapshot,
  String key,
) =>
    snapshot?[key]?.maturity != 'verified';
