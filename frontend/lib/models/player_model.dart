/// The "No-Nonsense" Player Model.
/// Focused strictly on Game Progress and ID-driven Inventory.
class PlayerModel {
  final String uid;
  final String name;
  final String createdAt;
  final List<String> banned;

  // State Flags
  final bool isBannedPermanent;
  final bool isBannedFromLeaderboard;
  final bool isBannedFromChat;
  final String? muteUntil; // ISO timestamp
  final String role; // 'admin', 'mod', 'player'

  // Progression
  final int level;
  final int xp;

  /// Total seconds spent ACTIVELY playing in matches (not dashboard time).
  final int totalGameTime;

  // Economy
  final int coins;
  final int stones;
  final String selectedCharacterId;

  /// Inventory is a clean Map of Item ID -> Amount.
  final Map<String, int> inventory;

  PlayerModel({
    required this.uid,
    required this.name,
    required this.createdAt,
    this.banned = const [],
    this.isBannedPermanent = false,
    this.isBannedFromLeaderboard = false,
    this.isBannedFromChat = false,
    this.muteUntil,
    this.role = 'player',
    this.level = 1,
    this.xp = 0,
    this.totalGameTime = 0,
    this.coins = 100,
    this.stones = 0,
    this.selectedCharacterId = 'char_max',
    this.inventory = const {},
  });

  factory PlayerModel.fromMap(Map<String, dynamic> data, String id) {
    return PlayerModel(
      uid: id,
      name: data['name'] ?? 'Dreamer',
      createdAt: data['createdAt'] ?? DateTime.now().toIso8601String(),
      banned: List<String>.from(data['banned'] ?? []),
      isBannedPermanent: data['isBannedPermanent'] ?? false,
      isBannedFromLeaderboard: data['isBannedFromLeaderboard'] ?? false,
      isBannedFromChat: data['isBannedFromChat'] ?? false,
      muteUntil: data['muteUntil'],
      role: data['role'] ?? 'player',
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      totalGameTime: data['totalGameTime'] ?? 0,
      coins: data['coins'] ?? 100,
      stones: data['stones'] ?? 0,
      selectedCharacterId: data['selectedCharacterId'] ?? 'char_max',
      inventory: Map<String, int>.from(data['inventory'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt,
      'banned': banned,
      'isBannedPermanent': isBannedPermanent,
      'isBannedFromLeaderboard': isBannedFromLeaderboard,
      'isBannedFromChat': isBannedFromChat,
      'muteUntil': muteUntil,
      'role': role,
      'level': level,
      'xp': xp,
      'totalGameTime': totalGameTime,
      'coins': coins,
      'stones': stones,
      'selectedCharacterId': selectedCharacterId,
      'inventory': inventory,
    };
  }

  /// Helper to check if user is currently muted.
  bool get isMuted {
    if (muteUntil == null) return false;
    final until = DateTime.tryParse(muteUntil!);
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }
}
