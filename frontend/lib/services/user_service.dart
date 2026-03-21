import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'offline_cache.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns a stream of the current user's document for real-time UI updates (e.g. currency)
  Stream<DocumentSnapshot> getUserStats() {
    final user = _auth.currentUser;
    if (user == null) {
      // Return an empty stream if not logged in
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
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
