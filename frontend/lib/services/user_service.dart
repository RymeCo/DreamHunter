import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player_model.dart';
import 'offline_cache.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns a stream of the current player's model
  Stream<PlayerModel?> getPlayerStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    
    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PlayerModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Updates player data in Firestore
  Future<void> updatePlayer(PlayerModel player) async {
    try {
      await _db.collection('users').doc(player.uid).set(player.toMap(), SetOptions(merge: true));
      // Also cache locally for offline access
      await OfflineCache.saveMetadata('player_profile', player.toMap());
    } catch (e) {
      // If offline, just cache locally
      await OfflineCache.saveMetadata('player_profile', player.toMap());
    }
  }

  /// Fetches a list of shop items from Firestore
  Stream<QuerySnapshot> getShopItems() {
    return _db.collection('shop_items').snapshots();
  }

  /// Fetches shop items from local cache
  Future<List<Map<String, dynamic>>> getCachedShopItems() async {
    final cached = await OfflineCache.getMetadata('shop_items');
    if (cached != null && cached['items'] != null) {
      return List<Map<String, dynamic>>.from(cached['items']);
    }
    return [];
  }

  /// Updates the local shop cache from Firestore
  Future<void> updateShopCache() async {
    try {
      final snapshot = await _db.collection('shop_items').get().timeout(const Duration(seconds: 10));
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      await OfflineCache.saveMetadata('shop_items', {'items': items});
    } catch (e) {
      // Ignore if offline
    }
  }
}
