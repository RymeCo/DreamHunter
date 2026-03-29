import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  // ValueNotifier so the UI can listen and rebuild
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  void initialize() {
    _checkInitialState();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  Future<void> _checkInitialState() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool online = !results.contains(ConnectivityResult.none);
    // If the list is empty, treat as offline or default to current state, but typically it contains at least one result.
    if (results.isEmpty) {
      online = false;
    }

    if (isOnline.value != online) {
      isOnline.value = online;
    }
  }

  void dispose() {
    _subscription.cancel();
    isOnline.dispose();
  }
}
