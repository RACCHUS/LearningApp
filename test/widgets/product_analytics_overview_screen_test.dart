import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/product_analytics_overview_screen.dart';
import 'package:learning_pwa/services/analytics/product_analytics_overview_service.dart';

class _OverviewStub extends ProductAnalyticsOverviewService {
  final bool allowed;
  final String status;
  int fetchCalls = 0;

  _OverviewStub({required this.allowed, required this.status});

  @override
  Future<bool> isAdmin() async => allowed;

  @override
  Future<ProductAnalyticsOverview> fetch({int days = 7}) async {
    fetchCalls++;
    return ProductAnalyticsOverview(
      status: status,
      days: days,
      asOf: DateTime.utc(2026, 11, 9, 20),
      coverage: 'opted_in_eligible_accounts_only',
      activeUsers: status == 'measured' ? 5 : null,
      eventCount: status == 'measured' ? 20 : null,
      sessionStarts: status == 'measured' ? 10 : null,
      resourceOpens: status == 'measured' ? 3 : null,
      externalClicks: status == 'measured' ? 1 : null,
    );
  }
}

void main() {
  Future<void> render(WidgetTester tester, _OverviewStub service) async {
    await tester.pumpWidget(MaterialApp(
      home: ProductAnalyticsOverviewScreen(service: service),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('non-admin does not trigger aggregate query', (tester) async {
    final service = _OverviewStub(allowed: false, status: 'measured');
    await render(tester, service);
    expect(find.textContaining('Access Denied'), findsOneWidget);
    expect(service.fetchCalls, 0);
    expect(find.text('20'), findsNothing);
  });

  testWidgets('no recorded eligible events show Not measured', (tester) async {
    final service = _OverviewStub(allowed: true, status: 'not_measured');
    await render(tester, service);
    expect(find.textContaining('Not measured'), findsWidgets);
    expect(find.text('20'), findsNothing);
  });

  testWidgets('small cohort is suppressed even for admin', (tester) async {
    final service =
        _OverviewStub(allowed: true, status: 'small_cohort_suppressed');
    await render(tester, service);
    expect(find.textContaining('Small cohort suppressed'), findsOneWidget);
    expect(find.text('20'), findsNothing);
  });

  testWidgets('verified eligible aggregates are labeled', (tester) async {
    final service = _OverviewStub(allowed: true, status: 'measured');
    await render(tester, service);
    expect(find.text('Opt-in active users'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
