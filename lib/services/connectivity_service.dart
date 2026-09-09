import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';

enum ConnectivityHealthStatus { healthy, degraded, unavailable }

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityService {
  final _logger = AppLogger('ConnectivityService');
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  final _healthController =
      StreamController<ConnectivityHealthStatus>.broadcast();

  int _consecutiveFailures = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  Stream<bool> get onConnectivityChanged => _controller.stream;
  Stream<ConnectivityHealthStatus> get healthStatus => _healthController.stream;
  ConnectivityHealthStatus _currentHealth = ConnectivityHealthStatus.healthy;

  ConnectivityHealthStatus get currentHealth => _currentHealth;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    // Initial check with retry
    await _checkConnectivityWithRetry();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      await _checkConnectivityWithRetry();
    });
  }

  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      final connected = _isConnected(result);

      if (connected) {
        _resetFailureCount();
      }

      return connected;
    } on Exception catch (e, stackTrace) {
      _logger.error(
        'Connectivity check failed',
        error: e,
        stackTrace: stackTrace,
      );

      _incrementFailureCount();

      // Distinguish between different error types
      if (e.toString().contains('permission')) {
        _updateHealth(ConnectivityHealthStatus.unavailable);
        throw NetworkException('Network permission denied', originalError: e);
      }

      _updateHealth(ConnectivityHealthStatus.degraded);
      return false;
    } catch (e, stackTrace) {
      _logger.error(
        'Unexpected connectivity error',
        error: e,
        stackTrace: stackTrace,
      );

      _incrementFailureCount();
      _updateHealth(ConnectivityHealthStatus.degraded);
      return false;
    }
  }

  /// Manual retry for connectivity check
  Future<bool> retryConnectivityCheck() async {
    _logger.info('Manual connectivity retry requested');
    return await _checkConnectivityWithRetry();
  }

  Future<bool> _checkConnectivityWithRetry() async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        final result = await _connectivity.checkConnectivity();
        final connected = _isConnected(result);
        _controller.add(connected);

        if (connected || attempt == _maxRetries - 1) {
          _resetFailureCount();
          _updateHealth(ConnectivityHealthStatus.healthy);
          return connected;
        }

        // Wait before retry
        attempt++;
        if (attempt < _maxRetries) {
          _logger
              .warn('Connectivity check attempt $attempt failed, retrying...');
          await Future.delayed(_retryDelay * attempt); // Exponential backoff
        }
      } on Exception catch (e, stackTrace) {
        _logger.error(
          'Connectivity check attempt $attempt failed',
          error: e,
          stackTrace: stackTrace,
          metadata: {'attempt': attempt, 'maxRetries': _maxRetries},
        );

        attempt++;
        if (attempt >= _maxRetries) {
          _controller.add(false);
          _updateHealth(ConnectivityHealthStatus.unavailable);
          _incrementFailureCount();
          return false;
        }

        await Future.delayed(_retryDelay * attempt);
      } catch (e, stackTrace) {
        _logger.error(
          'Unexpected error in connectivity retry',
          error: e,
          stackTrace: stackTrace,
        );

        attempt++;
        if (attempt >= _maxRetries) {
          _controller.add(false);
          _updateHealth(ConnectivityHealthStatus.unavailable);
          return false;
        }

        await Future.delayed(_retryDelay * attempt);
      }
    }

    return false;
  }

  void _incrementFailureCount() {
    _consecutiveFailures++;
    _logger.warn('Consecutive connectivity failures: $_consecutiveFailures');
  }

  void _resetFailureCount() {
    if (_consecutiveFailures > 0) {
      _logger
          .info('Connectivity restored after $_consecutiveFailures failures');
      _consecutiveFailures = 0;
    }
  }

  void _updateHealth(ConnectivityHealthStatus status) {
    if (_currentHealth != status) {
      _currentHealth = status;
      _healthController.add(status);
      _logger.info('Connectivity health changed to: ${status.name}');
    }
  }

  bool _isConnected(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.mobile:
      case ConnectivityResult.vpn:
        return true;
      case ConnectivityResult.none:
      default:
        return false;
    }
  }

  void dispose() {
    _controller.close();
    _healthController.close();
  }
}
