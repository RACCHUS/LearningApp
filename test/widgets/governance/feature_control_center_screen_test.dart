import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/feature_control_center_screen.dart';
import 'package:learning_pwa/services/governance/site_feature_service.dart';

class _FakeFeatureService extends SiteFeatureService {
  bool allowed = true;
  int writes = 0;
  bool lastEnabled = true;
  List<AdminSiteFeature> rows = const [
    AdminSiteFeature(
      key: 'tel.fast',
      label: 'Fast learning approach',
      category: 'Learning',
      kind: 'release',
      description: 'Fast available, verification pending',
      enabled: true,
      releaseReady: true,
      maturity: 'experimental',
      revision: 0,
    ),
    AdminSiteFeature(
      key: 'ai.byok',
      label: 'Bring Your Own Key AI',
      category: 'AI',
      kind: 'release',
      description: 'BYOK remains unavailable',
      enabled: false,
      releaseReady: false,
      maturity: 'experimental',
      revision: 0,
    ),
  ];

  @override
  Future<bool> isAdmin() async => allowed;

  @override
  Future<List<AdminSiteFeature>> listAdminFeatures() async => rows;

  @override
  Future<void> updateFeature({
    required AdminSiteFeature current,
    required bool enabled,
    required String maturity,
    required String reason,
  }) async {
    writes++;
    lastEnabled = enabled;
    expect(current.key, 'tel.fast');
    expect(reason.length >= 8, isTrue);
  }
}

void main() {
  testWidgets('Non-admin cannot view feature controls', (tester) async {
    final fake = _FakeFeatureService()..allowed = false;
    await tester.pumpWidget(MaterialApp(
      home: FeatureControlCenterScreen(service: fake),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Administrator access required.'), findsOneWidget);
    expect(find.text('Fast learning approach'), findsNothing);
  });

  testWidgets('Unready BYOK is locked and Fast can be turned off with an audit reason',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fake = _FakeFeatureService();
    await tester.pumpWidget(MaterialApp(
      home: FeatureControlCenterScreen(service: fake),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Fast learning approach'), findsOneWidget);
    expect(find.text('Bring Your Own Key AI'), findsOneWidget);

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    ).toList();
    expect(switches.length, 2);
    expect(switches[0].value, true);
    expect(switches[0].onChanged, isNotNull);
    expect(switches[1].value, false);
    expect(switches[1].onChanged, isNull);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm change'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('feature-change-reason')),
      'Emergency shutdown after smoke test',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm change'));
    await tester.pumpAndSettle();
    expect(fake.writes, 1);
    expect(fake.lastEnabled, isFalse);
  });
}
