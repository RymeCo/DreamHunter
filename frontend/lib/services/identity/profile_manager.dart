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
      final lastSyncStr = cached['last_sync_timestamp'];
      if (lastSyncStr != null) {
        final lastSync = DateTime.parse(lastSyncStr);
        final difference = DateTime.now().difference(lastSync);

        // If cache is less than 24 hours old, return it instantly (0 backend cost)
        if (difference.inHours < 24) {
          return PlayerModel.fromMap(cached, uid);
        }
      } else if (uid == 'guest') {
        // Guests always use local cache
        return PlayerModel.fromMap(cached, uid);
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
    final player = await getPlayer();
    if (player == null || _auth.currentUser == null) return;

    // Security Check: Permanently banned players cannot sync to cloud
    if (player.isBannedPermanent) {
      debugPrint('Backup blocked: Account is permanently banned.');
      return;
    }

    final updatedData = {
      ...player.toMap(),
      'coins': WalletManager.instance.dreamCoins,
      'stones': WalletManager.instance.hellStones,
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
    
    final response = await _backend.post('/auth/sync');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      final isNewUser = (data['level'] ?? 1) == 1 && (data['coins'] ?? 100) == 100;
      if (isNewUser && StorageEngine.instance.hasGuestData()) {
         await StorageEngine.instance.promoteGuestToUser(user.uid);
         await backupPlayer();
         return; // backupPlayer already saves metadata
      }

      data['last_sync_timestamp'] = DateTime.now().toIso8601String();
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
