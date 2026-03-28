enum ShopItemType {
  gear,
  boost,
  relic,
}

class ShopItem {
  final String id;
  final String name;
  final String description;
  final String image;
  final int price;
  final ShopItemType type;
  final String category;
  final bool isConsumable;
  final int maxLimit;

  const ShopItem({
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

  /// Create a ShopItem from a Firestore Map
  factory ShopItem.fromMap(Map<String, dynamic> data, String id) {
    final type = _parseType(data['type']);
    return ShopItem(
      id: id,
      name: data['name'] ?? 'Unknown Item',
      description: data['description'] ?? '',
      image: data['image'] ?? 'assets/images/dashboard/signage.png',
      price: data['price'] ?? 0,
      type: type,
      category: data['category'] ?? 'General',
      isConsumable: data['isConsumable'] ?? (type != ShopItemType.gear && type != ShopItemType.relic),
      maxLimit: data['maxLimit'] ?? (type == ShopItemType.gear || type == ShopItemType.relic ? 1 : 99),
    );
  }

  /// Convert ShopItem to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'type': type.name,
      'category': category,
      'isConsumable': isConsumable,
      'maxLimit': maxLimit,
    };
  }

  static ShopItemType _parseType(String? typeStr) {
    switch (typeStr?.toLowerCase()) {
      case 'gear':
        return ShopItemType.gear;
      case 'boost':
        return ShopItemType.boost;
      case 'relic':
        return ShopItemType.relic;
      default:
        return ShopItemType.gear;
    }
  }

  /// Create a copy of this item with some fields replaced
  ShopItem copyWith({
    String? name,
    String? description,
    String? image,
    int? price,
    ShopItemType? type,
    String? category,
    bool? isConsumable,
    int? maxLimit,
  }) {
    return ShopItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      price: price ?? this.price,
      type: type ?? this.type,
      category: category ?? this.category,
      isConsumable: isConsumable ?? this.isConsumable,
      maxLimit: maxLimit ?? this.maxLimit,
    );
  }
}
