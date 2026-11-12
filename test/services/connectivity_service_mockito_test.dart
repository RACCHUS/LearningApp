// ConnectivityService against a faked connectivity_plus platform channel
// (plan PR-4a). The previous version left the plugin unmocked, so every test
// only exercised the MissingPluginException path, and every assertion was
// `isA<bool>()`, which cannot fail.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/services/connectivity_service.dart';

const _method = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _events = EventChannel('dev.fluttercommunity.plus/connectivity_status');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the platform answers to `check`: a list of states, or an error.
  late Object Function() platformCheck;

  setUp(() {
    platformCheck = () => <String>['wifi'];
    messenger.setMockMethodCallHandler(_method, (call) async {
      if (call.method != 'check') return null;
      final answer = platformCheck();
      if (answer is Exception) throw answer;
      return answer;
    });
    messenger.setMockStreamHandler(_events, MockStreamHandler.inline(onListen: (_, __) {}));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_method, null);
    messenger.setMockStreamHandler(_events, null);
  });

  /// A service whose startup check (wifi) has completed.
  Future<ConnectivityService> started() async {
    final service = ConnectivityService();
    addTearDown(service.dispose);
    await pumpEventQueue();
    return service;
  }

  group('connection types', () {
    for (final state in ['wifi', 'ethernet', 'mobile', 'vpn', 'other']) {
      test('$state counts as connected', () async {
        final service = await started();
        platformCheck = () => [state];
        expect(await service.isConnected, isTrue);
        expect(service.currentHealth, ConnectivityHealthStatus.healthy);
      });
    }

    for (final states in [
      ['none'],
      ['bluetooth'],
      <String>[],
    ]) {
      test('$states is not connected', () async {
        final service = await started();
        platformCheck = () => states;
        expect(await service.isConnected, isFalse);
      });
    }

    test('any connected transport wins over none', () async {
      final service = await started();
      platformCheck = () => ['none', 'mobile'];
      expect(await service.isConnected, isTrue);
    });
  });

  test('startup check publishes the current state on the stream', () async {
    final service = ConnectivityService();
    addTearDown(service.dispose);
    expect(await service.onConnectivityChanged.first, isTrue);
  });

  test('a platform error returns false and degrades health', () async {
    final service = await started();
    final health = <ConnectivityHealthStatus>[];
    final sub = service.healthStatus.listen(health.add);
    addTearDown(sub.cancel);

    platformCheck = () => PlatformException(code: 'ERROR', message: 'radio unavailable');
    expect(await service.isConnected, isFalse);
    await pumpEventQueue();

    expect(service.currentHealth, ConnectivityHealthStatus.degraded);
    expect(health, [ConnectivityHealthStatus.degraded]);
  });

  test('a permission error is raised as NetworkException and marks health unavailable', () async {
    final service = await started();
    platformCheck = () => PlatformException(code: 'DENIED', message: 'permission denied');

    await expectLater(
      service.isConnected,
      throwsA(isA<NetworkException>().having((e) => e.message, 'message', 'Network permission denied')),
    );
    expect(service.currentHealth, ConnectivityHealthStatus.unavailable);
  });

  test('a manual retry after an error restores healthy status', () async {
    final service = await started();
    platformCheck = () => PlatformException(code: 'ERROR', message: 'radio unavailable');
    await service.isConnected;
    expect(service.currentHealth, ConnectivityHealthStatus.degraded);

    platformCheck = () => ['wifi'];
    expect(await service.retryConnectivityCheck(), isTrue);
    expect(service.currentHealth, ConnectivityHealthStatus.healthy);
  });

  test('dispose closes both streams', () async {
    final service = ConnectivityService();
    await pumpEventQueue();
    final connectivityDone = expectLater(service.onConnectivityChanged, emitsDone);
    final healthDone = expectLater(service.healthStatus, emitsDone);
    service.dispose();
    await connectivityDone;
    await healthDone;
  });
}
