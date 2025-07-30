import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();
  
  Stream<bool> get onConnectivityChanged => _controller.stream;
  
  ConnectivityService() {
    _init();
  }
  
  Future<void> _init() async {
    // Initial check
    await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      await _checkConnectivity();
    });
  }
  
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _isConnected(result);
    } catch (e) {
      return false;
    }
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _controller.add(_isConnected(result));
    } catch (e) {
      _controller.add(false);
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
  }
}
