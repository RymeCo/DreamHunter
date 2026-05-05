import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dreamhunter/models/player_model.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:dreamhunter/services/core/api_gateway.dart';
import 'package:dreamhunter/services/economy/wallet_manager.dart';
import 'package:dreamhunter/services/economy/shop_manager.dart';
import 'package:dreamhunter/services/progression/daily_roulette.dart';
import 'package:dreamhunter/services/progression/progression_manager.dart';
import 'package:dreamhunter/services/progression/task_service.dart';

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
      'roulette': DailyRoulette.instance.state.toJson(),
      'level': ProgressionManager.instance.level,
      'xp': ProgressionManager.instance.xp,
      'last_sync_timestamp': DateTime.now().toIso8601String(),
    };

    final success = await _backend.performFullSync(updatedData);
    if (success) {
      await StorageEngine.instance.saveMetadata('player_profile', updatedData);
      await StorageEngine.instance.incrementDailyCount('cloud_backup');
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
      // OPTIMIZATION: Cache the token immediately after a successful sync
      final user = _auth.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          await StorageEngine.instance.saveCachedToken(token);
        }
      }

      final Map<String, dynamic> data = json.decode(response.body);

      final isNewUser =
          (data['level'] ?? 1) == 1 && (data['coins'] ?? 100) == 100;
      if (isNewUser && StorageEngine.instance.hasGuestData()) {
        await StorageEngine.instance.promoteGuestToUser(user!.uid);
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

      if (data['level'] != null || data['xp'] != null) {
        final cached = await StorageEngine.instance.getMetadata(
          'player_profile',
        );
        if (cached != null) {
          await StorageEngine.instance.saveMetadata('player_profile', {
            ...cached,
            'level': data['level'] ?? 1,
            'xp': data['xp'] ?? 0,
          });
        }
      }

      if (data['roulette'] != null) {
        await StorageEngine.instance.saveMetadata(
          'roulette_state_v1',
          data['roulette'] as Map<String, dynamic>,
        );
      }

      await reloadAllServices();
    }
  }

  /// Forces all core services to reload their data from the local cache.
  Future<void> reloadAllServices() async {
    await WalletManager.instance.reloadFromCache();
    await ShopManager.instance.reloadFromCache();
    await DailyRoulette.instance.reloadFromCache();
    await ProgressionManager.instance.reloadFromCache();
    await TaskService.instance.reloadFromCache();
  }

  Future<void> clearLocalSession() async {
    await StorageEngine.instance.clearAllUserData();
  }

  /// Coordinates a clean logout: Signs out of Firebase and restores guest data in services.
  Future<void> logout() async {
    await StorageEngine.instance.clearCachedToken();
    await _auth.signOut();
    await reloadAllServices();
  }

  /// Fetches the global leaderboard, prioritizing the local daily cache.
  Future<Map<String, dynamic>> getLeaderboard({
    bool forceRefresh = false,
  }) async {
    // 1. Check Local Global Cache
    final cached = await StorageEngine.instance.getGlobalMetadata(
      'leaderboard_cache',
    );
    if (cached != null && !forceRefresh) {
      final lastUpdatedStr = cached['lastUpdated'] as String?;
      if (lastUpdatedStr != null) {
        try {
          // Use tryParse for better compatibility with ISO strings from different sources
          final lastUpdated = DateTime.tryParse(lastUpdatedStr);
          if (lastUpdated != null) {
            // Convert to PHT (UTC+8) for daily comparison
            final updatedPHT = lastUpdated.toUtc().add(
              const Duration(hours: 8),
            );
            final nowPHT = DateTime.now().toUtc().add(const Duration(hours: 8));

            // If the cache was updated today (PHT), return it
            if (updatedPHT.year == nowPHT.year &&
                updatedPHT.month == nowPHT.month &&
                updatedPHT.day == nowPHT.day) {
              return cached;
            }
          }
        } catch (e) {
          debugPrint('Cache Date Parse Error: $e');
        }
      }
    }

    // 2. Fetch from Backend
    try {
      final response = await _backend.get('/leaderboard');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        await StorageEngine.instance.saveGlobalMetadata(
          'leaderboard_cache',
          data,
        );
        return data;
      }
    } catch (e) {
      debugPrint('Leaderboard API Error: $e');
    }

    return cached ?? {"lastUpdated": "", "topLevels": [], "topCoins": []};
  }

  /// Fetches the current leaderboard rank for the logged-in user.
  /// Returns a map with 'levelRank' and 'coinsRank' (e.g., "#5" or "??").
  Future<Map<String, String>> getLeaderboardRank() async {
    final user = _auth.currentUser;
    if (user == null) return {'levelRank': '??', 'coinsRank': '??'};

    final data = await getLeaderboard();
    final List<dynamic> topLevels = data['topLevels'] ?? [];
    final List<dynamic> topCoins = data['topCoins'] ?? [];

    String levelRank = '??';
    String coinsRank = '??';

    for (int i = 0; i < topLevels.length; i++) {
      if (topLevels[i]['uid'] == user.uid) {
        levelRank = '#${i + 1}';
        break;
      }
    }

    for (int i = 0; i < topCoins.length; i++) {
      if (topCoins[i]['uid'] == user.uid) {
        coinsRank = '#${i + 1}';
        break;
      }
    }

    return {'levelRank': levelRank, 'coinsRank': coinsRank};
  }
}
