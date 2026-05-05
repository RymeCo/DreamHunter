import 'package:flutter/material.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

/// Minimalist Singleton controller to manage the app's economy.
class WalletManager extends ChangeNotifier {
  // Singleton Pattern
  static final WalletManager instance = WalletManager._internal();
  factory WalletManager() => instance;
  WalletManager._internal();

  int _dreamCoins = 0;
  int _hellStones = 0;
  bool _isLoading = false;

  int get dreamCoins => _dreamCoins;
  int get hellStones => _hellStones;
  bool get isLoading => _isLoading;

  /// Fetch initial values from cache.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await StorageEngine.instance.getCurrency();
      _dreamCoins = data['dreamCoins'] ?? 0;
      _hellStones = data['hellStones'] ?? 0;
    } catch (e) {
      debugPrint('Economy Init Error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Reloads state from cache (e.g. after a save override or login).
  Future<void> reloadFromCache() async => await initialize();

  /// Single source of truth for all currency updates.
  /// [delta] is the change (positive to add, negative to spend).
  /// Returns false if spending would result in a negative balance.
  Future<bool> updateBalance({int coinsDelta = 0, int stonesDelta = 0}) async {
    // Prevention of Negative Debt
    if (_dreamCoins + coinsDelta < 0 || _hellStones + stonesDelta < 0) {
      return false;
    }

    // Prevent redundant saving if nothing changed
    if (coinsDelta == 0 && stonesDelta == 0) return true;

    _dreamCoins += coinsDelta;
    _hellStones += stonesDelta;

    notifyListeners();

    // Persistent saving using the Singleton state
    await StorageEngine.instance.saveCurrency(_dreamCoins, _hellStones);
    return true;
  }

  /// Standardized exchange logic (1 Stone -> 100 Coins)
  Future<bool> exchangeHellStones(int stonesToExchange) async {
    if (stonesToExchange <= 0) return false;

    // Use the safe updateBalance method to handle logic/saving
    return await updateBalance(
      stonesDelta: -stonesToExchange,
      coinsDelta: stonesToExchange * 100,
    );
  }
}
