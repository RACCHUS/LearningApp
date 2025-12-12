import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/connectivity_service.dart';

void main() {
  test('connectivity stream is broadcast (skipped: relies on platform plugin)', () {
    final service = ConnectivityService();
    expect(service.onConnectivityChanged.isBroadcast, isTrue);
    service.dispose();
  }, skip: 'Relies on connectivity_plus platform channels in unit test environment');
}

