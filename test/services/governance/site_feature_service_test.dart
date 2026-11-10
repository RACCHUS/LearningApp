import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

void main() {
  test('server snapshot is dormant before reviewed database deployment',
      () async {
    expect(SiteFeatureRuntime.snapshotEnabled, isFalse);
    final snapshot = await SiteFeatureService().loadPublicSnapshot();
    expect(snapshot, isEmpty);
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

  test('audit model retains reason, caller and separate verification maturity', () {
    final change = AdminFeatureChange.fromJson({
      'feature_key': 'tel.fast',
      'reason': 'Emergency shutdown after smoke test',
      'actor_id': 'synthetic-test-admin',
      'prior_enabled': true,
      'next_enabled': false,
      'prior_maturity': 'experimental',
      'next_maturity': 'experimental',
      'new_revision': 9,
    });
    expect(change.key, 'tel.fast');
    expect(change.reason, contains('Emergency shutdown'));
    expect(change.actorId, 'synthetic-test-admin');
    expect(change.nextEnabled, false);
    expect(change.newRevision, 9);
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
