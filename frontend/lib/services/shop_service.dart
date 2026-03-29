import 'package:flutter/foundation.dart';
import '../models/shop_item.dart';

class ShopService extends ChangeNotifier {
  // Purely hardcoded items - EDIT THESE AS NEEDED
  final List<ShopItem> _items = [
    // --- ESSENTIAL GEAR ---
    const ShopItem(
      id: 'gear_01',
      name: 'Health Potion',
      description: 'Restore 50 HP',
      image: 'assets/images/dashboard/sandwich.png', // Fallback image
      price: 150,
      type: ShopItemType.boost,
      category: 'Essential Gear',
      isConsumable: true,
      maxLimit: 99,
    ),
    const ShopItem(
      id: 'gear_02',
      name: 'Energy Bar',
      description: 'Speed boost for 30s',
      image: 'assets/images/dashboard/sandwich.png',
      price: 200,
      type: ShopItemType.boost,
      category: 'Essential Gear',
      isConsumable: true,
      maxLimit: 99,
    ),
    const ShopItem(
      id: 'gear_03',
      name: 'Map Fragment',
      description: 'Reveal nearby ghosts',
      image: 'assets/images/dashboard/signage.png',
      price: 100,
      type: ShopItemType.gear,
      category: 'Essential Gear',
      maxLimit: 1,
    ),

    // --- ETHEREAL BOOSTS ---
    const ShopItem(
      id: 'boost_01',
      name: 'Ghost Veil',
      description: 'Invisibility for 10s',
      image: 'assets/images/dashboard/sandwich.png',
      price: 500,
      type: ShopItemType.boost,
      category: 'Ethereal Boosts',
      isConsumable: true,
      maxLimit: 10,
    ),
    const ShopItem(
      id: 'boost_02',
      name: 'Spirit Shield',
      description: 'Ignore next hit',
      image: 'assets/images/dashboard/signage.png',
      price: 750,
      type: ShopItemType.gear,
      category: 'Ethereal Boosts',
      maxLimit: 1,
    ),
    const ShopItem(
      id: 'boost_03',
      name: 'Gold Magnet',
      description: 'Auto-collect coins',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 600,
      type: ShopItemType.relic,
      category: 'Ethereal Boosts',
      maxLimit: 1,
    ),

    // --- ARCANE RELICS ---
    const ShopItem(
      id: 'relic_01',
      name: 'Night Vision',
      description: 'Permanent dark sight',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 5000,
      type: ShopItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
    const ShopItem(
      id: 'relic_02',
      name: 'Dream Walker',
      description: 'Walk through walls',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 10000,
      type: ShopItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
    const ShopItem(
      id: 'relic_03',
      name: 'Soul Tether',
      description: 'Half respawn time',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 3500,
      type: ShopItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
  ];

  List<ShopItem> get items => _items;

  /// Sync categories for the UI
  Map<String, List<ShopItem>> getItemsByCategory() {
    // Explicitly order the categories as they were before
    final List<String> order = [
      'Essential Gear',
      'Ethereal Boosts',
      'Arcane Relics',
    ];
    final Map<String, List<ShopItem>> grouped = {};

    for (var cat in order) {
      grouped[cat] = _items.where((i) => i.category == cat).toList();
    }

    return grouped;
  }

  // Local inventory for this session only (Hardcoded)
  final Map<String, int> _localInventory = {};

  int getOwnedCount(String itemId) {
    return _localInventory[itemId] ?? 0;
  }

  bool canPurchase(ShopItem item, int currentCurrency) {
    if (currentCurrency < item.price) return false;
    final ownedCount = getOwnedCount(item.id);
    return ownedCount < item.maxLimit;
  }

  void purchaseItemLocally(String itemId) {
    _localInventory[itemId] = (_localInventory[itemId] ?? 0) + 1;
    notifyListeners();
  }
}
