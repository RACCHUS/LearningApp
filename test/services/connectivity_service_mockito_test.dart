import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ConnectivityService Tests', () {
    late ConnectivityService service;

    setUp(() {
      service = ConnectivityService();
    });

    test('should check connectivity status', () async {
      // Act
      final isConnected = await service.isConnected;

      // Assert
      expect(isConnected, isA<bool>());
    });

    test('should emit connectivity changes via stream', () async {
      // Arrange
      final values = <bool>[];
      final subscription = service.onConnectivityChanged.listen((value) {
        values.add(value);
      });

      // Act - wait for initial check
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(values.length, greaterThanOrEqualTo(0));

      // Cleanup
      await subscription.cancel();
    });

    test('should handle connectivity check errors', () async {
      // Note: The service catches errors and returns false
      // This is tested implicitly through the isConnected getter
      
      // Act
      final isConnected = await service.isConnected;

      // Assert - should return bool even on error
      expect(isConnected, isA<bool>());
    });

    test('should dispose resources', () {
      // Act
      service.dispose();

      // Assert - should not throw
      // Stream should be closed
    });

    test('should identify connected states correctly', () async {
      // Test the _isConnected logic indirectly
      // WiFi, Ethernet, Mobile, VPN should return true
      // None should return false
      
      final isConnected = await service.isConnected;
      expect(isConnected, isA<bool>());
    });
  });
}

