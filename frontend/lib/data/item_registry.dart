import 'package:dreamhunter/models/item_model.dart';

/// The Master Registry of all items in DreamHunter.
/// This acts as the "Source of Truth" for all items.
class ItemRegistry {
  static const Map<String, Item> items = {
    // --- HUNTERS ---
    'char_max': Item(
      id: 'char_max',
      name: 'Max (Default)',
      description: 'The standard dream hunter.',
      image: 'assets/images/game/characters/max_front-32x48.png',
      price: 0,
      type: ItemType.character,
      category: 'Hunters',
      maxLimit: 1,
    ),
    'char_nun': Item(
      id: 'char_nun',
      name: 'Nun',
      description: 'Faith is her only shield.',
      image: 'assets/images/game/characters/nun_front-32x48.png',
      price: 1000,
      type: ItemType.character,
      category: 'Hunters',
      maxLimit: 1,
    ),
    'char_jack': Item(
      id: 'char_jack',
      name: 'Jack',
      description: 'Fast but fragile.',
      image: 'assets/images/game/characters/jack_front-32x48.png',
      price: 2500,
      type: ItemType.character,
      category: 'Hunters',
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
