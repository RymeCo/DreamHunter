import 'dart:convert';
import 'package:flutter/material.dart';
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

  /// Fetches the active player model, prioritizing Local Cache for speed and cost-saving.
  /// Only goes to the backend if the cache is older than 24 hours or missing.
  Future<PlayerModel?> getPlayer({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    final String uid = user?.uid ?? 'guest';

    // 1. Check Local Cache
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null && !forceRefresh) {
      final player = PlayerModel.fromMap(cached, uid);

      // SECURITY & COST: If locally marked as permanently banned, never hit the backend again.
      if (player.isBannedPermanent) {
        return player;
      }

      final lastSyncStr = cached['last_sync_timestamp'];
      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        final difference = DateTime.now().difference(lastSync);

        // If cache is less than 24 hours old, return it instantly (0 backend cost)
        if (difference.inHours < 24) {
          return player;
        }
      } else if (uid == 'guest') {
        // Guests always use local cache
        return player;
      }
    }

    // 2. Fetch from Backend only if necessary or forced
    if (user != null) {
      try {
        final response = await _backend.get('/profile');
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          // Add local timestamp for expiration tracking
          data['last_sync_timestamp'] = DateTime.now().toIso8601String();
          
          await StorageEngine.instance.saveMetadata('player_profile', data);
          return PlayerModel.fromMap(data, uid);
        }
      } catch (e) {
        debugPrint('Failed to fetch from backend, falling back to cache: $e');
      }
    }

    // 3. Absolute Fallback
    if (cached != null) return PlayerModel.fromMap(cached, uid);
    
    return PlayerModel(
      uid: uid,
      name: user?.displayName ?? 'Dreamer',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Packages all local data into a PlayerModel and pushes to the backend.
  Future<void> backupPlayer() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check cache first to avoid getPlayer()'s internal logic
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null) {
      final localPlayer = PlayerModel.fromMap(cached, user.uid);
      if (localPlayer.isBannedPermanent) {
        debugPrint('Backup aborted: Account is permanently banned.');
        return;
      }
    }

    final player = await getPlayer();
    if (player == null) return;

    // Merge current dashboard/shop/wallet state into the model before backing up
    final Map<String, int> activeInventory = {};
    for (var item in ShopManager.instance.items) {
      final count = ShopManager.instance.getOwnedCount(item.id);
      if (count > 0) activeInventory[item.id] = count;
    }

    final updatedData = {
      ...player.toMap(),
      'coins': WalletManager.instance.dreamCoins,
      'stones': WalletManager.instance.hellStones,
      'inventory': activeInventory,
      'selectedCharacterId': ShopManager.instance.selectedCharacterId,
      'last_sync_timestamp': DateTime.now().toIso8601String(),
    };

    final success = await _backend.performFullSync(updatedData);
    if (success) {
      await StorageEngine.instance.saveMetadata('player_profile', updatedData);
    }
  }

  /// Ensures the player document exists and is cached (called after login/register).
  Future<void> syncWithBackend() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // SECURITY: If we already know they are banned, don't even try to sync
    final cached = await StorageEngine.instance.getMetadata('player_profile');
    if (cached != null && (cached['isBannedPermanent'] ?? false)) {
      debugPrint('Sync aborted: User is permanently banned.');
      return;
    }
    
    final response = await _backend.post('/auth/sync');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      final isNewUser = (data['level'] ?? 1) == 1 && (data['coins'] ?? 100) == 100;
      if (isNewUser && StorageEngine.instance.hasGuestData()) {
         await StorageEngine.instance.promoteGuestToUser(user.uid);
         await backupPlayer();
         return; 
      }

      data['last_sync_timestamp'] = DateTime.now().toIso8601String();
      await StorageEngine.instance.saveMetadata('player_profile', data);

      // 3. Update specialized local caches so other managers can see the cloud data
      if (data['inventory'] != null || data['selectedCharacterId'] != null) {
        await StorageEngine.instance.saveMetadata('local_inventory', {
          'inventory': data['inventory'] ?? {},
          'selectedCharacterId': data['selectedCharacterId'] ?? 'char_max',
        });
      }
      
      if (data['coins'] != null || data['stones'] != null) {
        await StorageEngine.instance.saveCurrency(
          data['coins'] ?? 100,
          data['stones'] ?? 0,
        );
      }

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
