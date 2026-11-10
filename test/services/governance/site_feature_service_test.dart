import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

void main() {
  test('server snapshot is dormant before reviewed database deployment', () {
    expect(SiteFeatureRuntime.snapshotEnabled, isFalse);
  });

  test('untrusted or missing metadata cannot enable a feature', () {
    final missing = SiteFeatureSetting.fromJson({});
    expect(missing.enabled, isFalse);
    expect(missing.maturity, 'experimental');
    expect(missing.revision, 0);

    final ready = SiteFeatureSetting.fromJson({
      'enabled': true,
      'maturity': 'verified',
      'revision': 3,
    });
    expect(ready.enabled, isTrue);
    expect(ready.maturity, 'verified');
    expect(ready.revision, 3);
  });

  test('admin model keeps release readiness distinct from availability', () {
    final result = AdminSiteFeature.fromJson({
      'feature_key': 'ai.byok',
      'enabled': false,
      'release_ready': false,
      'maturity': 'experimental',
      'revision': 0,
    });
    expect(result.key, 'ai.byok');
    expect(result.enabled, isFalse);
    expect(result.releaseReady, isFalse);
  });
}
