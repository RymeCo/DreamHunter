import 'package:flutter/material.dart';
import 'offline_cache.dart';

class DashboardController extends ChangeNotifier {
  int _dreamCoins = 0;
  int _hellStones = 0;
  bool _isLoading = false;

  int get dreamCoins => _dreamCoins;
  int get hellStones => _hellStones;
  bool get isLoading => _isLoading;

  /// Initializes the controller by fetching currency from cache.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    final data = await OfflineCache.getCurrency();
    _dreamCoins = data['dreamCoins'] ?? 0;
    _hellStones = data['hellStones'] ?? 0;

    _isLoading = false;
    notifyListeners();
  }

  /// Updates currency with absolute values. Returns true if successful.
  Future<bool> updateCurrency({int? newCoins, int? newStones}) async {
    if (newCoins != null) _dreamCoins = newCoins;
    if (newStones != null) _hellStones = newStones;
    
    notifyListeners();
    await OfflineCache.saveCurrency(_dreamCoins, _hellStones);
    return true;
  }

  /// Updates the dream coins balance locally and in cache.
  Future<void> updateDreamCoins(int delta) async {
    _dreamCoins += delta;
    notifyListeners();
    await OfflineCache.saveCurrency(_dreamCoins, _hellStones);
  }

  /// Updates the hell stones balance locally and in cache.
  Future<void> updateHellStones(int delta) async {
    _hellStones += delta;
    notifyListeners();
    await OfflineCache.saveCurrency(_dreamCoins, _hellStones);
  }

  /// Refreshes the currency from cache (useful after a dialog closes that might have changed state).
  Future<void> refreshCurrency() async {
    final data = await OfflineCache.getCurrency();
    _dreamCoins = data['dreamCoins'] ?? 0;
    _hellStones = data['hellStones'] ?? 0;
    notifyListeners();
  }

  /// Exchanges hell stones for dream coins at a fixed rate (1:100).
  /// Returns true if the exchange was successful.
  Future<bool> exchangeHellStones(int amount) async {
    if (amount <= 0 || _hellStones < amount) return false;

    _isLoading = true;
    notifyListeners();

    // Fixed rate: 1 Hell Stone = 100 Dream Coins
    _hellStones -= amount;
    _dreamCoins += amount * 100;

    await OfflineCache.saveCurrency(_dreamCoins, _hellStones);

    _isLoading = false;
    notifyListeners();
    return true;
  }
}
