class PlayerModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final int level;
  final int xp;
  final int currency;
  final List<String> inventory;
  final DateTime? lastLogin;

  PlayerModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.level = 1,
    this.xp = 0,
    this.currency = 100,
    this.inventory = const [],
    this.lastLogin,
  });

  /// Create a PlayerModel from a Firestore Map
  factory PlayerModel.fromMap(Map<String, dynamic> data, String id) {
    return PlayerModel(
      uid: id,
      displayName: data['displayName'] ?? 'Dreamer',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      currency: data['currency'] ?? 100,
      inventory: List<String>.from(data['inventory'] ?? []),
      lastLogin: data['lastLogin'] != null
          ? DateTime.parse(data['lastLogin'])
          : null,
    );
  }

  /// Convert PlayerModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'level': level,
      'xp': xp,
      'currency': currency,
      'inventory': inventory,
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  /// Create a copy of this player with some fields replaced
  PlayerModel copyWith({
    String? displayName,
    String? photoUrl,
    int? level,
    int? xp,
    int? currency,
    List<String>? inventory,
    DateTime? lastLogin,
  }) {
    return PlayerModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      currency: currency ?? this.currency,
      inventory: inventory ?? this.inventory,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}
