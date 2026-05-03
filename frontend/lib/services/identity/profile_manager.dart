import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/models/player_model.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/core/api_gateway.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';

/// Minimalist Singleton bridge between local cache and Backend (FastAPI).
class ProfileManager {
  static final ProfileManager instance = ProfileManager._internal();
  factory ProfileManager() => instance;
  ProfileManager._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiGateway _backend = ApiGateway();

  /// Fetches the active player model, prioritizing Local Cache for speed.
  Future<PlayerModel?> getPlayer() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Return a guest model from cache if no one is logged in
      final cached = await StorageEngine.instance.getMetadata('player_profile');
      return PlayerModel.fromMap(cached ?? {}, 'guest');
    }

    // 1. Try Cache First
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null) {
      return PlayerModel.fromMap(cached, user.uid);
    }

    // 2. Default if nothing in cache
    return PlayerModel(
      uid: user.uid,
      name: user.displayName ?? 'Dreamer',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Packages all local data into a PlayerModel and pushes to the backend.
  Future<void> backupPlayer() async {
    final player = await getPlayer();
    if (player == null || _auth.currentUser == null) return;

    // Merge current dashboard/shop state into the model before backing up
    final updatedPlayer = PlayerModel(
      uid: player.uid,
      name: player.name,
      createdAt: player.createdAt,
      level: player.level,
      xp: player.xp,
      coins: WalletManager.instance.dreamCoins,
      stones: WalletManager.instance.hellStones,
    );

    await _backend.performFullSync(updatedPlayer.toMap());
    await StorageEngine.instance.saveMetadata(
      'player_profile',
      updatedPlayer.toMap(),
    );
  }

  /// Ensures the player document exists in Firestore (called after login/register).
  Future<void> syncWithBackend() async {
    if (_auth.currentUser == null) return;
    
    final response = await _backend.post('/auth/sync');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await StorageEngine.instance.saveMetadata('player_profile', data);
      await reloadAllServices();
    }
  }

  /// Forces all core services to reload their data from the local cache.
  Future<void> reloadAllServices() async {
    await WalletManager.instance.reloadFromCache();
    await ShopManager.instance.reloadFromCache();
  }

  Future<void> clearLocalSession() async {
    await StorageEngine.instance.clearAllUserData();
  }
}
