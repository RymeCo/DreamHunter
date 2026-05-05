import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Minimalist singleton to monitor device connectivity.
class NetworkMonitor {
  static final NetworkMonitor instance = NetworkMonitor._internal();
  factory NetworkMonitor() => instance;
  NetworkMonitor._internal();

  /// ValueNotifier for UI-bound connectivity status.
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  /// Starts monitoring connectivity.
  Future<void> initialize() async {
    final connectivity = Connectivity();

    // Initial State Check
    final results = await connectivity.checkConnectivity();
    _update(results);

    // Real-time listener: detects when user toggles WiFi/Data
    connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    isOnline.value =
        !results.contains(ConnectivityResult.none) && results.isNotEmpty;
  }
}
