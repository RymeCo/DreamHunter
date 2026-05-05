enum ItemType { gear, boost, relic, character }

/// blueprint for all items inGame
/// is used for the registry shop and inventory
class Item {
  final String id;
  final String name;
  final String description;
  final String image;
  final int price;
  final ItemType type;
  final String category;
  final bool isConsumable;
  final int maxLimit;

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.type,
    required this.category,
    this.isConsumable = false,
    this.maxLimit = 1,
  });
}
