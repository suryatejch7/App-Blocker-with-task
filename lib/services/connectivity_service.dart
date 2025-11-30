import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _connectivityController = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial status
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);

      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateStatus,
        onError: (e) {
          debugPrint('❌ Connectivity error: $e');
        },
      );

      debugPrint('✅ ConnectivityService initialized, online: $_isOnline');
    } catch (e) {
      debugPrint('❌ ConnectivityService initialization error: $e');
      // Assume online if we can't check
      _isOnline = true;
    }
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final wasOnline = _isOnline;
    _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      debugPrint(
          '🌐 Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      _connectivityController.add(_isOnline);
    }
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      return _isOnline;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return _isOnline;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
