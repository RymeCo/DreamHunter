/// The "No-Nonsense" Player Model.
/// Focused strictly on Game Progress and ID-driven Inventory.
class PlayerModel {
  final String uid;
  final String name;
  final String createdAt;
  final List<String> banned;

  // Progression
  final int level;
  final int xp;

  /// Total seconds spent ACTIVELY playing in matches (not dashboard time).
  final int totalGameTime;

  // Economy
  final int coins;
  final int stones;

  /// Inventory is a clean Map of Item ID -> Amount.
  final Map<String, int> inventory;

  PlayerModel({
    required this.uid,
    required this.name,
    required this.createdAt,
    this.banned = const [],
    this.level = 1,
    this.xp = 0,
    this.totalGameTime = 0,
    this.coins = 100,
    this.stones = 0,
    this.inventory = const {},
  });

  factory PlayerModel.fromMap(Map<String, dynamic> data, String id) {
    return PlayerModel(
      uid: id,
      name: data['name'] ?? 'Dreamer',
      createdAt: data['createdAt'] ?? DateTime.now().toIso8601String(),
      banned: List<String>.from(data['banned'] ?? []),
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      totalGameTime: data['totalGameTime'] ?? 0,
      coins: data['coins'] ?? 100,
      stones: data['stones'] ?? 0,
      inventory: Map<String, int>.from(data['inventory'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt,
      'banned': banned,
      'level': level,
      'xp': xp,
      'totalGameTime': totalGameTime,
      'coins': coins,
      'stones': stones,
      'inventory': inventory,
    };
  }
}
