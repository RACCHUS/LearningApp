import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_pwa/providers/connectivity_provider.dart';
import 'package:learning_pwa/providers/supabase_health_provider.dart';
import 'package:learning_pwa/services/supabase_health_service.dart';

import '../test_helpers/fake_supabase_client.dart';

/// Health service whose probe result is controllable and observable.
class _FakeHealthService extends SupabaseHealthService {
  _FakeHealthService(this._result) : super(client: FakeSupabaseClient());

  SupabaseStatus _result;
  int callCount = 0;

  @override
  Future<SupabaseStatus> check() async {
    callCount++;
    return _result;
  }
}

/// Minimal StateNotifier<bool> to stand in for the device connectivity state.
class _FakeConnectivityNotifier extends StateNotifier<bool>
    implements ConnectivityNotifier {
  _FakeConnectivityNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container({
  required bool deviceOnline,
  required _FakeHealthService service,
}) {
  return ProviderContainer(
    overrides: [
      connectivityProvider
          .overrideWith((ref) => _FakeConnectivityNotifier(deviceOnline)),
      supabaseHealthServiceProvider.overrideWithValue(service),
    ],
  );
}

void main() {
  group('SupabaseHealthNotifier', () {
    test('skips the probe and stays unknown while the device is offline',
        () async {
      final service = _FakeHealthService(SupabaseStatus.reachable);
      final container =
          _container(deviceOnline: false, service: service);
      addTearDown(container.dispose);

      // Trigger construction (which runs the initial probe).
      final status = container.read(supabaseHealthProvider);
      await Future<void>.delayed(Duration.zero);

      expect(status, SupabaseStatus.unknown);
      expect(service.callCount, 0);
    });

    test('reports reachable when online and the backend answers', () async {
      final service = _FakeHealthService(SupabaseStatus.reachable);
      final container = _container(deviceOnline: true, service: service);
      addTearDown(container.dispose);

      container.read(supabaseHealthProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(supabaseHealthProvider), SupabaseStatus.reachable);
      expect(service.callCount, greaterThanOrEqualTo(1));
    });

    test('reports unreachable when online but the backend does not answer',
        () async {
      final service = _FakeHealthService(SupabaseStatus.unreachable);
      final container = _container(deviceOnline: true, service: service);
      addTearDown(container.dispose);

      container.read(supabaseHealthProvider);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(supabaseHealthProvider),
        SupabaseStatus.unreachable,
      );
    });
  });
}
