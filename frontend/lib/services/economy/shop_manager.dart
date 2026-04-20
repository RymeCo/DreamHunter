import 'package:flutter/foundation.dart';
import 'package:dreamhunter/models/item_model.dart';
import 'package:dreamhunter/data/item_registry.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';

/// Minimalist Singleton to handle Shop Logic and Local Inventory.
class ShopManager extends ChangeNotifier {
  static final ShopManager instance = ShopManager._internal();
  factory ShopManager() => instance;
  ShopManager._internal();

  /// Pull items directly from the Registry (Source of Truth)
  List<Item> get items => ItemRegistry.all;

  /// Local inventory for this session (Future: Sync with PlayerModel)
  final Map<String, int> _localInventory = {};

  int getOwnedCount(String itemId) {
    return _localInventory[itemId] ?? 0;
  }

  bool canPurchase(Item item, int currentCurrency) {
    if (currentCurrency < item.price) return false;
    final ownedCount = getOwnedCount(item.id);
    return ownedCount < item.maxLimit;
  }

  void purchaseItemLocally(String itemId) {
    _localInventory[itemId] = (_localInventory[itemId] ?? 0) + 1;
    notifyListeners();
    // Cache the purchase immediately
    _saveInventoryToCache();
  }

  /// Reloads state from cache (e.g. after a save override or login).
  Future<void> reloadFromCache() async => await loadInventoryFromCache();

  /// Categorization helper for UI layout
  Map<String, List<Item>> getItemsByCategory() {
    final List<String> order = [
      'Essential Gear',
      'Ethereal Boosts',
      'Arcane Relics',
    ];
    final Map<String, List<Item>> grouped = {};
    for (var cat in order) {
      grouped[cat] = ItemRegistry.getByCategory(cat);
    }
    return grouped;
  }

  // --- Caching Logic (Migrated from ProfileManager) ---
  Future<void> _saveInventoryToCache() async {
    await StorageEngine.instance.saveMetadata(
      'local_inventory',
      _localInventory,
    );
  }

  Future<void> loadInventoryFromCache() async {
    final cached = await StorageEngine.instance.getMetadata('local_inventory');
    if (cached != null) {
      _localInventory.clear();
      cached.forEach((key, value) {
        _localInventory[key] = value as int;
      });
      notifyListeners();
    }
  }
}
