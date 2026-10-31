import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/governance/usage_quota.dart';
import 'package:learning_pwa/screens/governance/cost_observability_screen.dart';
import 'package:learning_pwa/services/governance/cost_observability_service.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';

class FakeCostObservabilityService extends Fake implements CostObservabilityService {
  final bool hasAdminAccess;
  final ObservabilityHealthSnapshot snapshot;

  FakeCostObservabilityService({
    this.hasAdminAccess = true,
    required this.snapshot,
  });

  @override
  Future<bool> isAdmin() async => hasAdminAccess;

  @override
  Future<ObservabilityHealthSnapshot> measureHealthSnapshot({int hours = 24}) async {
    return snapshot;
  }
}

void main() {
  Widget createWidgetUnderTest(CostObservabilityService service) {
    return MaterialApp(
      home: CostObservabilityScreen(service: service),
    );
  }

  group('ECO-00C: CostObservabilityScreen Widget Tests', () {
    testWidgets('renders Access Denied when user is not an administrator', (tester) async {
      final fakeService = FakeCostObservabilityService(
        hasAdminAccess: false,
        snapshot: ObservabilityHealthSnapshot(
          supabaseStatus: SupabaseStatus.reachable,
          pingLatencyMs: 35,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Access Denied'), findsOneWidget);
      expect(
        find.text(
          'You must have the "admin" role to view platform cost metrics and observability telemetry.',
        ),
        findsOneWidget,
      );
      expect(find.text('Check Access Again'), findsOneWidget);
    });

    testWidgets('renders health and telemetry dashboard when user is administrator',
        (tester) async {
      final sampleTelemetry = SystemUsageTelemetry(
        windowHours: 24,
        since: DateTime.parse('2026-10-21T00:00:00Z'),
        totalAiTokens: 45000,
        totalTtsChars: 25000,
        totalSttSeconds: 180,
        totalStorageBytes: 15728640, // 15 MB
        activeUsers: 8,
        totalEvents: 34,
        estimatedCostUsd: 0.4068,
      );

      final fakeService = FakeCostObservabilityService(
        hasAdminAccess: true,
        snapshot: ObservabilityHealthSnapshot(
          telemetry: sampleTelemetry,
          supabaseStatus: SupabaseStatus.reachable,
          pingLatencyMs: 42,
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(fakeService));
      await tester.pumpAndSettle();

      expect(find.text('Cost & Observability Console'), findsOneWidget);
      expect(find.textContaining('ECO-00C Observability Mode'), findsOneWidget);
      expect(find.text('Operational / Reachable'), findsOneWidget);
      expect(find.text('Latency: 42ms'), findsOneWidget);
      expect(find.text('\$0.4068 USD'), findsOneWidget);
      expect(find.text('8 Active Users'), findsOneWidget);
      expect(find.text('34 Metered Events'), findsOneWidget);

      expect(find.text('AI Tokens Consumed'), findsOneWidget);
      expect(find.text('45000'), findsOneWidget);
      expect(find.text('TTS Characters'), findsOneWidget);
      expect(find.text('25000'), findsOneWidget);
      expect(find.text('STT Audio Processed'), findsOneWidget);
      expect(find.text('180s'), findsOneWidget);
      expect(find.text('Storage Stored'), findsOneWidget);
      expect(find.text('15.0 MB'), findsOneWidget);
      expect(find.text('Abuse Prevention'), findsOneWidget);
      expect(find.text('Hardened'), findsOneWidget);
    });
  });
}
