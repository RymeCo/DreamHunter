import 'package:dreamhunter/models/item_model.dart';

/// The Master Registry of all items in DreamHunter.
/// This acts as the "Source of Truth" for all items.
class ItemRegistry {
  static const Map<String, Item> items = {
    // --- ESSENTIAL GEAR ---
    'gear_01': Item(
      id: 'gear_01',
      name: 'Health Potion',
      description: 'Restore 50 HP',
      image: 'assets/images/dashboard/sandwich.png',
      price: 150,
      type: ItemType.boost,
      category: 'Essential Gear',
      isConsumable: true,
      maxLimit: 99,
    ),
    'gear_02': Item(
      id: 'gear_02',
      name: 'Energy Bar',
      description: 'Speed boost for 30s',
      image: 'assets/images/dashboard/sandwich.png',
      price: 200,
      type: ItemType.boost,
      category: 'Essential Gear',
      isConsumable: true,
      maxLimit: 99,
    ),
    'gear_03': Item(
      id: 'gear_03',
      name: 'Map Fragment',
      description: 'Reveal nearby ghosts',
      image: 'assets/images/dashboard/signage.png',
      price: 100,
      type: ItemType.gear,
      category: 'Essential Gear',
      maxLimit: 1,
    ),

    // --- ETHEREAL BOOSTS ---
    'boost_01': Item(
      id: 'boost_01',
      name: 'Ghost Veil',
      description: 'Invisibility for 10s',
      image: 'assets/images/dashboard/sandwich.png',
      price: 500,
      type: ItemType.boost,
      category: 'Ethereal Boosts',
      isConsumable: true,
      maxLimit: 10,
    ),
    'boost_02': Item(
      id: 'boost_02',
      name: 'Spirit Shield',
      description: 'Ignore next hit',
      image: 'assets/images/dashboard/signage.png',
      price: 750,
      type: ItemType.gear,
      category: 'Ethereal Boosts',
      maxLimit: 1,
    ),
    'boost_03': Item(
      id: 'boost_03',
      name: 'Gold Magnet',
      description: 'Auto-collect coins',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 600,
      type: ItemType.relic,
      category: 'Ethereal Boosts',
      maxLimit: 1,
    ),

    // --- ARCANE RELICS ---
    'relic_01': Item(
      id: 'relic_01',
      name: 'Night Vision',
      description: 'Permanent dark sight',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 5000,
      type: ItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
    'relic_02': Item(
      id: 'relic_02',
      name: 'Dream Walker',
      description: 'Walk through walls',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 10000,
      type: ItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
    'relic_03': Item(
      id: 'relic_03',
      name: 'Soul Tether',
      description: 'Half respawn time',
      image: 'assets/images/dashboard/profile_logo.png',
      price: 3500,
      type: ItemType.relic,
      category: 'Arcane Relics',
      maxLimit: 1,
    ),
  };

  /// Retrieves an item by its unique ID.
  static Item? get(String id) => items[id];

  /// Returns all items.
  static List<Item> get all => items.values.toList();

  /// Returns all items of a specific type.
  static List<Item> getByType(ItemType type) {
    return items.values.where((item) => item.type == type).toList();
  }

  /// Returns all items of a specific category.
  static List<Item> getByCategory(String category) {
    return items.values.where((item) => item.category == category).toList();
  }
}
