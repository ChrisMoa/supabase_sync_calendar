import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<List<ConnectivityResult>> _controller = StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get connectivityStream => _controller.stream;
  bool _isInitialized = false;
  List<ConnectivityResult> _lastResult = [ConnectivityResult.none];

  NetworkService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Get initial connection status (now returns a List)
    try {
      _lastResult = await _connectivity.checkConnectivity();
      _controller.add(_lastResult);
    } catch (e) {
      debugPrint('Error getting initial connectivity: $e');
      _lastResult = [ConnectivityResult.none]; // Default to none on error
      _controller.add(_lastResult);
    }

    // Listen for connection changes (now emits a List)
    _connectivity.onConnectivityChanged.listen((result) {
      // Check if the list content has actually changed
      if (!listEquals(_lastResult, result)) {
        _lastResult = result;
        _controller.add(result);
      }
    });

    _isInitialized = true;
  }

  bool get isConnected {
    return _lastResult.isNotEmpty && !_lastResult.every((result) => result == ConnectivityResult.none || result == ConnectivityResult.bluetooth);
  }

  Future<bool> get isOnline async {
    try {
      final result = await _connectivity.checkConnectivity();

      // Log detailed connectivity results for debugging
      for (var res in result) {
        debugPrint('🌐 NETWORK: Detected connectivity type: $res');
      }

      return result.isNotEmpty && !result.every((res) => res == ConnectivityResult.none || res == ConnectivityResult.bluetooth);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  void dispose() {
    _controller.close();
  }
}
